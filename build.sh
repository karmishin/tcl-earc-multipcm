#!/bin/sh
# Build the Magisk module from your TV's own libthal_audio.so.
#
#   ./build.sh --pull                  read the lib from the TV over adb (no root needed)
#   ./build.sh path/to/libthal_audio.so [firmware-id]
#
# Output: dist/tcl-earc-multipcm-<firmware>.zip
set -eu
cd "$(dirname "$0")"

ADB="adb ${ADB_SERIAL:+-s $ADB_SERIAL}"
WORK=$(mktemp -d)
trap 'rm -r "$WORK"' EXIT

if [ "${1:-}" = "--pull" ]; then
  STOCK=$WORK/libthal_audio.stock.so
  # `adb pull` is refused for this file, but the shell user can read it.
  $ADB exec-out cat /vendor/lib/libthal_audio.so > "$STOCK"
  FIRMWARE=$($ADB shell getprop ro.software.version_id | tr -d '\r')
else
  STOCK=${1:?usage: build.sh --pull | build.sh <libthal_audio.so> [firmware-id]}
  FIRMWARE=${2:-unknown}
fi

STAGE=$WORK/module
cp -R module "$STAGE"
mkdir -p "$STAGE/system/vendor/lib"
python3 patch_libthal_audio.py "$STOCK" "$STAGE/system/vendor/lib/libthal_audio.so"

STOCK_SHA256=$(shasum -a 256 "$STOCK" | cut -d' ' -f1)
PATCHED_SHA256=$(shasum -a 256 "$STAGE/system/vendor/lib/libthal_audio.so" | cut -d' ' -f1)
for f in module.prop customize.sh post-fs-data.sh; do
  sed -e "s/@STOCK_SHA256@/$STOCK_SHA256/g" -e "s/@PATCHED_SHA256@/$PATCHED_SHA256/g" \
      -e "s/@FIRMWARE@/$FIRMWARE/g" "module/$f" > "$STAGE/$f"
done

mkdir -p dist
OUT=dist/tcl-earc-multipcm-$FIRMWARE.zip
rm -f "$OUT"
(cd "$STAGE" && zip -qrX - META-INF module.prop customize.sh post-fs-data.sh system) > "$OUT"
echo "built $OUT"
