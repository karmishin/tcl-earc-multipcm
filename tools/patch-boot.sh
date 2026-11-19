#!/bin/sh
# Patch a boot image with Magisk on the TV, without the app's file picker
# (Google TV has none). Runs Magisk's own boot_patch.sh as the adb shell user.
#
#   tools/patch-boot.sh Magisk-v27.0.apk boot.img boot-magisk.img
#
# boot.img must be the exact boot image the TV is running (check the kernel
# build string against /proc/version).
set -eu

APK=$1 IN=$2 OUT=$3
ADB="adb ${ADB_SERIAL:+-s $ADB_SERIAL}"
DIR=/data/local/tmp/magisk
STAGE=$(mktemp -d)
trap 'rm -r "$STAGE"' EXIT

unzip -p "$APK" assets/boot_patch.sh > "$STAGE/boot_patch.sh"
unzip -p "$APK" assets/util_functions.sh > "$STAGE/util_functions.sh"
unzip -p "$APK" assets/stub.apk > "$STAGE/stub.apk"
# The TV's userspace is 32-bit ARM.
for b in magiskboot magiskinit magisk32 busybox; do
  unzip -p "$APK" "lib/armeabi-v7a/lib$b.so" > "$STAGE/$b"
done
cp "$IN" "$STAGE/boot.img"

$ADB shell "rm -rf $DIR && mkdir -p $DIR"
$ADB push "$STAGE/." "$DIR/" >/dev/null
# Same flags the Magisk app picks here: system-as-root (keep verity),
# FBE (keep forceencrypt), vbmeta partition exists (don't patch vbmeta flag).
$ADB shell "cd $DIR && chmod 755 * && KEEPVERITY=true KEEPFORCEENCRYPT=true PATCHVBMETAFLAG=false RECOVERYMODE=false LEGACYSAR=false ./busybox sh ./boot_patch.sh boot.img"
$ADB pull "$DIR/new-boot.img" "$OUT" >/dev/null
shasum -a 256 "$OUT"
