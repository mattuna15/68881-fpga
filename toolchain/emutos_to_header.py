#!/usr/bin/env python3
"""
Convert EmuTOS ROM image to C header for the M68K emulator.

Reads etos256us.img and outputs rom_image.h with the ROM data as a
C unsigned char array, trimming trailing 0xFF padding.

Usage:
    python emutos_to_header.py [input.img] [output.h]

Defaults:
    input:  toolchain/emutos-src-1.4/etos256us.img
    output: validation/hello_world/src/rom_image.h
"""

import sys
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)

DEFAULT_INPUT = os.path.join(PROJECT_ROOT, "toolchain", "emutos-src-1.4", "etos256us.img")
DEFAULT_OUTPUT = os.path.join(PROJECT_ROOT, "validation", "hello_world", "src", "rom_image.h")


def main():
    input_path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_INPUT
    output_path = sys.argv[2] if len(sys.argv) > 2 else DEFAULT_OUTPUT

    with open(input_path, "rb") as f:
        data = f.read()

    print(f"Read {len(data)} bytes from {input_path}")

    # Parse TOS ROM header
    version_hi = data[2]
    version_lo = data[3]
    reseth = int.from_bytes(data[4:8], "big")
    print(f"  TOS version = {version_hi}.{version_lo:02d}")
    print(f"  reseth (entry point) = 0x{reseth:08X}")

    if reseth == 0:
        print("WARNING: reseth is zero — image may be invalid")

    # Trim trailing 0x00 and 0xFF padding
    end = len(data)
    while end > 8 and data[end - 1] in (0x00, 0xFF):
        end -= 1
    # Round up to next 4-byte boundary for clean alignment
    end = (end + 3) & ~3
    trimmed = data[:end]

    print(f"  Trimmed from {len(data)} to {len(trimmed)} bytes "
          f"({len(data) - len(trimmed)} bytes of padding removed)")

    # Generate C header
    with open(output_path, "w", newline="\n") as f:
        f.write("/* Auto-generated from EmuTOS - do not edit */\n")
        f.write(f"#define ROM_IMAGE_SIZE {len(trimmed)}\n")
        f.write(f"static const unsigned char rom_image_data[ROM_IMAGE_SIZE] = {{\n")

        for i in range(0, len(trimmed), 16):
            chunk = trimmed[i:i + 16]
            hex_bytes = ", ".join(f"0x{b:02x}" for b in chunk)
            if i + 16 < len(trimmed):
                f.write(f"  {hex_bytes},\n")
            else:
                f.write(f"  {hex_bytes}\n")

        f.write("};\n")

    print(f"Wrote {output_path} ({len(trimmed)} bytes)")


if __name__ == "__main__":
    main()
