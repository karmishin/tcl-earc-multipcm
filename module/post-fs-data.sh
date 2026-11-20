#!/system/bin/sh
# Runs before Magisk mounts the module. If the real /vendor lib is no longer the
# one this module was built from (e.g. after a firmware update), don't mount.

MODDIR=${0%/*}
STOCK_SHA256=@STOCK_SHA256@
LIB=$MODDIR/system/vendor/lib/libthal_audio.so

cur=$(sha256sum /vendor/lib/libthal_audio.so | cut -d' ' -f1)
# status.sh reports the outcome; nothing is recorded here, since a recorded
# status goes stale on boots where Magisk doesn't run this script.
if [ "$cur" = "$STOCK_SHA256" ]; then
  rm -f "$MODDIR/skip_mount"
  chcon u:object_r:vendor_file:s0 "$LIB"
else
  touch "$MODDIR/skip_mount"
fi
