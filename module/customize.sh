#!/system/bin/sh
# Install-time checks. Magisk sources this with MODPATH set.
# The hashes are filled in by build.sh from the library the module was built from.

STOCK_SHA256=@STOCK_SHA256@
PATCHED_SHA256=@PATCHED_SHA256@
LIB=system/vendor/lib/libthal_audio.so

ui_print "- TCL eARC multichannel PCM fix (@FIRMWARE@)"

# Stock on first install; patched if this module is already active (reinstall).
cur=$(sha256sum /vendor/lib/libthal_audio.so | cut -d' ' -f1)
[ "$cur" = "$STOCK_SHA256" ] || [ "$cur" = "$PATCHED_SHA256" ] \
  || abort "! This module was built from a different libthal_audio.so. Rebuild it from this TV."

got=$(sha256sum "$MODPATH/$LIB" | cut -d' ' -f1)
[ "$got" = "$PATCHED_SHA256" ] || abort "! Patched library in the zip is corrupted"

set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/$LIB" 0 0 0644 u:object_r:vendor_file:s0
ui_print "- OK. Reboot to apply."
