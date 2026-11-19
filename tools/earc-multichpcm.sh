#!/system/bin/sh
# Flip the Realtek audio firmware's eARC multichannel-PCM flag by hand (root).
# Same 32-byte write as RHAL_AUDIO_EARC_MultiPCMOut(n). Not persistent: TCL
# resets it on the next input/format change unless the Magisk module is active.
#
#   adb push tools/earc-multichpcm.sh /data/local/tmp/
#   adb shell su -c sh /data/local/tmp/earc-multichpcm.sh      # on
#   adb shell su -c sh /data/local/tmp/earc-multichpcm.sh 0    # off

v=${1:-1}
case "$v" in 0|1) ;; *) echo "usage: $0 [0|1]"; exit 1 ;; esac
[ "$(id -u)" = 0 ] || { echo "needs root (su -c)"; exit 1; }

printf 'fw@ earc_multichpcm %s' "$v" | dd of=/dev/rtkaudio bs=32 count=1 conv=sync 2>/dev/null \
  && echo "sent: fw@ earc_multichpcm $v" || echo "write to /dev/rtkaudio failed"
