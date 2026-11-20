#!/system/bin/sh
# Runs before Magisk mounts the module. If the real /vendor lib is no longer the
# one this module was built from (e.g. after a firmware update), don't mount.

MODDIR=${0%/*}
STOCK_SHA256=@STOCK_SHA256@
LIB=$MODDIR/system/vendor/lib/libthal_audio.so

cur=$(sha256sum /vendor/lib/libthal_audio.so | cut -d' ' -f1)
if [ "$cur" = "$STOCK_SHA256" ]; then
  rm -f "$MODDIR/skip_mount"
  chcon u:object_r:vendor_file:s0 "$LIB"
  # service.sh replaces this once it has checked the mount.
  echo "mount pending: stock lib matches, waiting for Magisk to mount the patched one" > "$MODDIR/status.txt"
else
  touch "$MODDIR/skip_mount"
  echo "skipped: /vendor/lib/libthal_audio.so is $cur, not the lib this module was built from" > "$MODDIR/status.txt"
fi
