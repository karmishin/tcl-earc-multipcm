#!/system/bin/sh
# Reports whether /vendor serves the patched lib right now. Checked live rather
# than recorded at boot, so it can't go stale when Magisk skips this module's
# scripts (module disabled, safe mode).
#
#   adb shell su -c sh /data/adb/modules/tcl_earc_multipcm/status.sh

MODDIR=${0%/*}
STOCK_SHA256=@STOCK_SHA256@
PATCHED_SHA256=@PATCHED_SHA256@

cur=$(sha256sum /vendor/lib/libthal_audio.so | cut -d' ' -f1)
case $cur in
  "$PATCHED_SHA256")
    echo "active: /vendor/lib/libthal_audio.so is the patched lib" ;;
  "$STOCK_SHA256")
    if [ -f "$MODDIR/disable" ]; then
      echo "not active: module is disabled in Magisk"
    else
      echo "not active: stock lib still in place (Magisk safe mode, or the mount failed)"
    fi ;;
  *)
    echo "not active: /vendor/lib/libthal_audio.so is $cur, not the lib this module was built from; rebuild" ;;
esac
