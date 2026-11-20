#!/bin/sh
# Build the Magisk module from your TV's own libthal_audio.so.
#
#   ./build.sh --pull                  read the lib from the TV over adb (no root needed)
#   ./build.sh path/to/libthal_audio.so [firmware-id]
#
# Output: dist/tcl-earc-multipcm-<firmware>.zip
set -eu

ADB="adb ${ADB_SERIAL:+-s $ADB_SERIAL}"
WORK=$(mktemp -d)
trap 'rm -r "$WORK"' EXIT

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1"; else shasum -a 256 "$1"; fi | cut -d' ' -f1
}

if [ "${1:-}" = "--pull" ]; then
  STOCK=$WORK/libthal_audio.stock.so
  # `adb pull` is refused for this file, but the shell user can read it.
  $ADB exec-out cat /vendor/lib/libthal_audio.so > "$STOCK"
  # exec-out doesn't pass on the remote exit status, so check what came back.
  if [ "$(head -c 4 "$STOCK" | tail -c 3)" != ELF ]; then
    echo "could not read /vendor/lib/libthal_audio.so from the TV (got: $(head -c 80 "$STOCK"))" >&2
    exit 1
  fi
  FIRMWARE=$($ADB shell getprop ro.software.version_id | tr -d '\r')
else
  STOCK=${1:?usage: build.sh --pull | build.sh <libthal_audio.so> [firmware-id]}
  # Resolve before the cd below, so paths relative to the caller's directory work.
  case $STOCK in /*) ;; *) STOCK=$PWD/$STOCK ;; esac
  FIRMWARE=${2:-}
fi
# Used in a file name and as a sed replacement: keep it to safe characters.
FIRMWARE=$(printf '%s' "${FIRMWARE:-unknown}" | tr -c 'A-Za-z0-9._-' '_')

cd "$(dirname "$0")"

STAGE=$WORK/module
cp -R module "$STAGE"
mkdir -p "$STAGE/system/vendor/lib"
python3 patch_libthal_audio.py "$STOCK" "$STAGE/system/vendor/lib/libthal_audio.so"

STOCK_SHA256=$(sha256 "$STOCK")
PATCHED_SHA256=$(sha256 "$STAGE/system/vendor/lib/libthal_audio.so")
for f in module.prop customize.sh post-fs-data.sh service.sh; do
  sed -e "s/@STOCK_SHA256@/$STOCK_SHA256/g" -e "s/@PATCHED_SHA256@/$PATCHED_SHA256/g" \
      -e "s/@FIRMWARE@/$FIRMWARE/g" "module/$f" > "$STAGE/$f"
done

mkdir -p dist
OUT=dist/tcl-earc-multipcm-$FIRMWARE.zip
rm -f "$OUT"
# Fixed timestamps so the same input lib always gives the same zip.
find "$STAGE" -exec touch -h -t 200901010000 {} +
(cd "$STAGE" && zip -qrX - META-INF module.prop customize.sh post-fs-data.sh service.sh system) > "$OUT"
echo "built $OUT"
