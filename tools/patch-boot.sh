#!/bin/sh
# Patch a boot image with Magisk on the TV, without the app's file picker
# (Google TV has none). Runs Magisk's own boot_patch.sh as the adb shell user.
#
#   tools/patch-boot.sh Magisk-v27.0.apk boot.img boot-magisk.img
#
# boot.img must be the exact boot image the TV is running (check the kernel
# build string against /proc/version).
#
# Only tested with Magisk v27.0, so other versions are refused; set
# MAGISK_ANY_VERSION=1 to try one anyway. v28 and later still fail at the unzip
# step: they renamed the native libs (libmagisk32.so is gone).
set -eu

if [ $# -ne 3 ]; then
  echo "usage: $0 <Magisk-v27.0.apk> <stock boot.img> <output boot.img>" >&2
  exit 1
fi
APK=$1 IN=$2 OUT=$3
ADB="adb ${ADB_SERIAL:+-s $ADB_SERIAL}"
DIR=/data/local/tmp/magisk

ver=$(unzip -p "$APK" assets/util_functions.sh | sed -n 's/^MAGISK_VER_CODE=//p')
if [ "$ver" != 27000 ] && [ -z "${MAGISK_ANY_VERSION:-}" ]; then
  echo "$APK is Magisk version code ${ver:-unknown}; only 27000 (v27.0) is tested." >&2
  echo "Set MAGISK_ANY_VERSION=1 to try it anyway." >&2
  exit 1
fi

STAGE=$(mktemp -d)
ON_TV=
cleanup() {
  rm -r "$STAGE"
  # Also on failure: don't leave the stock boot image and Magisk binaries on the TV.
  if [ -n "$ON_TV" ]; then $ADB shell "rm -rf $DIR" >/dev/null 2>&1 || true; fi
}
trap cleanup EXIT

unzip -p "$APK" assets/boot_patch.sh > "$STAGE/boot_patch.sh"
unzip -p "$APK" assets/util_functions.sh > "$STAGE/util_functions.sh"
unzip -p "$APK" assets/stub.apk > "$STAGE/stub.apk"
# The TV's userspace is 32-bit ARM.
for b in magiskboot magiskinit magisk32 busybox; do
  unzip -p "$APK" "lib/armeabi-v7a/lib$b.so" > "$STAGE/$b"
done
cp "$IN" "$STAGE/boot.img"

ON_TV=1
$ADB shell "rm -rf $DIR && mkdir -p $DIR"
$ADB push "$STAGE/." "$DIR/" >/dev/null
# Same flags the Magisk app picks here: system-as-root (keep verity),
# FBE (keep forceencrypt), vbmeta partition exists (don't patch vbmeta flag).
$ADB shell "cd $DIR && chmod 755 * && KEEPVERITY=true KEEPFORCEENCRYPT=true PATCHVBMETAFLAG=false RECOVERYMODE=false LEGACYSAR=false ./busybox sh ./boot_patch.sh boot.img"
$ADB pull "$DIR/new-boot.img" "$OUT" >/dev/null
if command -v sha256sum >/dev/null 2>&1; then sha256sum "$OUT"; else shasum -a 256 "$OUT"; fi
