#!/system/bin/sh
# Runs after Magisk has mounted modules. Checks that /vendor really serves the
# patched lib now, and records the result in status.txt.

MODDIR=${0%/*}
PATCHED_SHA256=@PATCHED_SHA256@

# post-fs-data.sh already explained why the module was skipped.
[ -f "$MODDIR/skip_mount" ] && exit 0

cur=$(sha256sum /vendor/lib/libthal_audio.so | cut -d' ' -f1)
if [ "$cur" = "$PATCHED_SHA256" ]; then
  echo "active: /vendor/lib/libthal_audio.so is the patched lib" > "$MODDIR/status.txt"
else
  echo "not active: /vendor/lib/libthal_audio.so is $cur, expected the patched lib $PATCHED_SHA256" > "$MODDIR/status.txt"
fi
