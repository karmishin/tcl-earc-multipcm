# tcl-earc-multipcm

A Magisk module that lets TCL TVs on the Realtek **R75P** platform send multichannel PCM (5.1/7.1) over eARC to soundbars that stop at 48 kHz, such as the Sonos Beam Gen 2.

Without it, multichannel LPCM from HDMI inputs (gaming consoles, laptops) reaches the soundbar as Stereo PCM, even though the source offers 5.1. Dolby bitstream (DD+, Atmos) is unaffected.

## Compatibility

Tested with `V8-R75PT01-LF1V500` (TCL 55P7K) and Sonos Beam Gen 2.

Other R75P models (C655, C655 Pro, P755, T7B, P7K, …) are untested. The patcher refuses any library where it doesn't find exactly 10 checks per function. The `V8-T800T02` platform hasn't been looked at.

## Requirements

- Unlocked bootloader and Magisk 27.0. There's a rooting guide (in Russian) in the [4PDA TCL thread](https://4pda.to/forum/index.php?showtopic=1095712).
- On your computer: `adb`, `python3`, `zip`.

## Build and install

```sh
# pulls libthal_audio.so from your TV
./build.sh --pull

adb push dist/tcl-earc-multipcm-*.zip /data/local/tmp/m.zip
adb shell su -c magisk --install-module /data/local/tmp/m.zip
adb reboot
```

After the reboot, this should print `active: /vendor/lib/libthal_audio.so is the patched lib`:

```sh
adb shell su -c cat /data/adb/modules/tcl_earc_multipcm/status.txt
```

The module is tied to the exact library it was built from. After a firmware update you have to run `build.sh` again.

## Uninstall

Remove it in the Magisk app, or:

```sh
adb shell su -c touch /data/adb/modules/tcl_earc_multipcm/remove
adb reboot
```

## What's wrong with stock firmware

In `libthal_audio.so`, `thal_audio_set_digital_output_mode` and `thal_set_audio_spdif_parameter_internel` send `1` only if the soundbar lists exactly `0F 7F 07`, meaning it must support every sample rate up to 192 kHz. Most soundbars stop at 48 kHz, so the TV sends `0` and you get stereo.

The module changes 20 instructions: in each of the 10 per-format checks of both functions, `cmp r0, #0x7f` becomes `cmp r0, r0`. The TV still requires the soundbar to advertise 8-channel 16/20/24-bit LPCM; it just stops requiring 192 kHz. Magisk overlays the patched library on `/vendor` without modifying the partition.

Some details:

- The bit-depth byte still has to be exactly `07`. A soundbar that advertises 8-channel LPCM at 16 and 24 bit only (`05`) still gets stereo.
- `thal_is_amp_support_format` has a third copy of the `0F 7F 07` check. It isn't patched because it doesn't affect PCM: every caller asks about DTS-HD, never LPCM.
