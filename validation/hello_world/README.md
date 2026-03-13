# Rebuilding rom_image.h from bios.s

The BIOS ROM source is at `validation/hello_world/src/roms/bios.s`.
After making changes to `bios.s`, regenerate `rom_image.h` with these steps:

## 1. Assemble with vasm

```bash
C:\code\vasm68k\vasmm68k_mot.exe -Fbin -o bios.bin validation/hello_world/src/roms/bios.s
```

This produces a flat binary spanning the full address space (RAM at $402 + ROM at $FE0000).
Warnings about label/mnemonic conflicts are expected and harmless.

## 2. Extract the ROM portion and generate the header

The binary starts at address $402, so the ROM at $FE0000 is at file offset $FDFBFE ($FE0000 - $402).

```bash
python -c "
with open('bios.bin','rb') as f:
    data = f.read()
    rom_data = data[0xFE0000 - 0x402:]
    lines = ['/* Auto-generated ROM image from bios.s */']
    lines.append('#ifndef ROM_IMAGE_H')
    lines.append('#define ROM_IMAGE_H')
    lines.append('')
    lines.append('#include <stdint.h>')
    lines.append('')
    lines.append(f'static const unsigned int rom_image_size = {len(rom_data)};')
    lines.append('')
    lines.append('static const unsigned char rom_image_data[] = {')
    for i in range(0, len(rom_data), 16):
        chunk = rom_data[i:i+16]
        hex_vals = ', '.join(f'0x{b:02X}' for b in chunk)
        comma = '' if i + 16 >= len(rom_data) else ','
        lines.append(f'    {hex_vals}{comma}')
    lines.append('};')
    lines.append('')
    lines.append('#endif /* ROM_IMAGE_H */')
    with open('validation/hello_world/src/rom_image.h','w') as f:
        f.write('\n'.join(lines) + '\n')
    print(f'Generated rom_image.h: {len(rom_data)} bytes')
"
```

## 3. Verify

The first bytes should be `0x00, 0x7C, 0x07, 0x00` (`ORI.W #$0700,SR` — the BIOS entry point).

## Notes

- The RAM section at $402 (853 bytes of DS reservations) is not included — `emu_mem_init()` zeroes all 16MB at boot
- `main.c` loads the ROM data at `BIOS_ROMBAS` ($FE0000) via `emu_mem_load()`
- Clean up temp files: `rm bios.bin bios_rom.bin`
