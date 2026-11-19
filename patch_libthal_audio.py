#!/usr/bin/env python3
"""Relax the eARC multichannel-PCM check in TCL's libthal_audio.so (32-bit ARM).

TCL turns on multichannel PCM over eARC only if the soundbar advertises an LPCM
Short Audio Descriptor of exactly 0F 7F 07: 8 channels, every sample rate up to
192 kHz, 16/20/24-bit. Soundbars that stop at 48 kHz (Sonos Beam Gen 2 sends
0F 07 07) fail the check and get stereo.

In thal_audio_set_digital_output_mode and thal_set_audio_spdif_parameter_internel
each unrolled SAD check is

    cmp r0, #0x7f ; itt eq ; ldrbeq r0, [rX, #n] ; cmpeq r0, #0x7

The sample-rate compare becomes `cmp r0, r0`, so an 8ch 16/20/24-bit LPCM SAD
is accepted at any sample rate. Everything else is left alone.

Usage: patch_libthal_audio.py <stock libthal_audio.so> <patched output>
"""
import hashlib
import struct
import sys

FUNCTIONS = (
    "thal_audio_set_digital_output_mode",
    "_Z39thal_set_audio_spdif_parameter_internelv",
)
SITES_PER_FUNCTION = 10            # one per unrolled SAD slot
CMP_R0_7F = bytes.fromhex("7f28")  # Thumb `cmp r0, #0x7f`
ITT_EQ = bytes.fromhex("04bf")     # Thumb `itt eq`
CMPEQ_R0_7 = bytes.fromhex("0728")  # Thumb `cmp r0, #0x7`
CMP_R0_R0 = bytes.fromhex("8042")  # Thumb `cmp r0, r0`


def elf_symbols(data):
    """Return {name: (vaddr, size)} from .dynsym and a vaddr->file-offset mapper."""
    if data[:4] != b"\x7fELF" or data[4] != 1 or data[5] != 1:
        sys.exit("not a 32-bit little-endian ELF")
    e_phoff, e_shoff = struct.unpack_from("<II", data, 0x1C)
    e_phentsize, e_phnum, e_shentsize, e_shnum = struct.unpack_from("<HHHH", data, 0x2A)

    loads = []
    for i in range(e_phnum):
        p_type, p_offset, p_vaddr, _, p_filesz = struct.unpack_from("<IIIII", data, e_phoff + i * e_phentsize)
        if p_type == 1:  # PT_LOAD
            loads.append((p_vaddr, p_offset, p_filesz))

    def to_offset(vaddr):
        for start, off, size in loads:
            if start <= vaddr < start + size:
                return vaddr - start + off
        sys.exit(f"address {vaddr:#x} is not in a loaded segment")

    sections = [struct.unpack_from("<IIIIIIIIII", data, e_shoff + i * e_shentsize) for i in range(e_shnum)]
    symbols = {}
    for sh in sections:
        if sh[1] != 11:  # SHT_DYNSYM
            continue
        strtab = sections[sh[6]]
        str_off = strtab[4]
        for j in range(sh[5] // 16):
            st_name, st_value, st_size = struct.unpack_from("<III", data, sh[4] + j * 16)
            end = data.index(b"\0", str_off + st_name)
            symbols[data[str_off + st_name:end].decode()] = (st_value & ~1, st_size)
    return symbols, to_offset


def main():
    src, dst = sys.argv[1:3]
    data = bytearray(open(src, "rb").read())
    print("stock   sha256", hashlib.sha256(data).hexdigest())
    symbols, to_offset = elf_symbols(data)

    for name in FUNCTIONS:
        if name not in symbols:
            sys.exit(f"refusing: {name} not found; this lib is not supported")
        vaddr, size = symbols[name]
        start = to_offset(vaddr)
        sites = [
            off for off in range(start, start + size - 8, 2)
            if data[off:off + 2] == CMP_R0_7F
            and data[off + 2:off + 4] == ITT_EQ
            and data[off + 6:off + 8] == CMPEQ_R0_7
        ]
        if len(sites) != SITES_PER_FUNCTION:
            sys.exit(f"refusing: {name} has {len(sites)} matches, expected {SITES_PER_FUNCTION}")
        for off in sites:
            data[off:off + 2] = CMP_R0_R0
        print(f"patched {len(sites)} checks in {name}")

    open(dst, "wb").write(data)
    print("patched sha256", hashlib.sha256(data).hexdigest())


if __name__ == "__main__":
    main()
