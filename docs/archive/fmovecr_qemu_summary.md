# FMOVECR Constant ROM

`FMOVECR #ccc,FPn` loads a constant from the 68881's internal ROM into an FP
register. The 7-bit offset `ccc` (0x00-0x7F) selects the constant.

## Documented constants (offsets 0x00-0x3F)

Source: Motorola MC68881/MC68882 User's Manual, Section 6.

| Offset | Constant | FP80 Hex |
|--------|----------|----------|
| `0x00` | Pi | `4000C90FDAA22168C235` |
| `0x0B` | Log10(2) | `3FFD9A209A84FBCFF798` |
| `0x0C` | e | `4000ADF85458A2BB4A9A` |
| `0x0D` | Log2(e) | `3FFFB8AA3B295C17F0BC` |
| `0x0E` | Log10(e) | `3FFDDE5BD8A937287195` |
| `0x0F` | 0.0 | `00000000000000000000` |
| `0x30` | ln(2) | `3FFEB17217F7D1CF79AC` |
| `0x31` | ln(10) | `4000935D8DDDAAA8AC17` |
| `0x32` | 10^0 | `3FFF8000000000000000` |
| `0x33` | 10^1 | `4002A000000000000000` |
| `0x34` | 10^2 | `4005C800000000000000` |
| `0x35` | 10^4 | `400C9C40000000000000` |
| `0x36` | 10^8 | `4019BEBC200000000000` |
| `0x37` | 10^16 | `40348E1BC9BF04000000` |
| `0x38` | 10^32 | `40699DC5ADA82B70B59E` |
| `0x39` | 10^64 | `40D3C2781F49FFCFA6D5` |
| `0x3A` | 10^128 | `41A893BA47C980E98CE0` |
| `0x3B` | 10^256 | `4351AA7EEBFB9DF9DE8E` |
| `0x3C` | 10^512 | `46A3E319A0AEA60E91C7` |
| `0x3D` | 10^1024 | `4D48C976758681750C17` |
| `0x3E` | 10^2048 | `5A929E8B3B5DC53D5DE5` |
| `0x3F` | 10^4096 | `7525C46052028A20979B` |

## Undocumented constants (offsets 0x01-0x0A)

Source: WinUAE (Toni Wilen), verified against real 68881/68882 silicon. Both
the 68881 and 68882 return identical values for these offsets.

| Offset | FP80 Hex | Notes |
|--------|----------|-------|
| `0x01` | `4001FE00068200000000` | Rounding mode-dependent adjustments |
| `0x02` | `4001FFC0050380000000` | |
| `0x03` | `20007FFFFFFF00000000` | Can set Infinity or NaN CC bits depending on rounding |
| `0x04` | `0000FFFFFFFFFFFFFFFF` | |
| `0x05` | `3C00FFFFFFFFFFFFF800` | |
| `0x06` | `3F80FFFFFF0000000000` | |
| `0x07` | `0001F65D8D9C00000000` | Sets NaN CC, has rounding-dependent adjustments |
| `0x08` | `7FFF001E000000000000` | |
| `0x09` | `3FFF000E000000000000` | |
| `0x0A` | `7F000006000000000000` | Also used for offsets > 0x0A in the undoc table |

Offsets 0x01, 0x03, and 0x07 have special interactions with the FPCR rounding
mode and precision bits that do not follow normal rounding rules. The WinUAE
source has per-offset case statements handling this behaviour.

## Undocumented default (offsets 0x10-0x2F)

All offsets in the range 0x10-0x2F return the same value:

| FP80 Hex |
|----------|
| `40000000000000000000` |

## Offsets 0x40-0x7F

Offsets in the upper half of the ROM address space (0x40-0x7F) generate an
F-line exception on real hardware.

## Implementation

The FPGA implementation stores all 64 entries (0x00-0x3F) in a constant ROM
array in `src/mc68881_top.vhd` (`FMOVECR_ROM`). This includes all 22 documented
constants, 10 undocumented constants (0x01-0x0A), and the undocumented default
value for offsets 0x10-0x2F. Offsets 0x40-0x7F are filled with zero (handled by
decode logic before reaching the ROM).

The testbench `tb/tb_mc68881_fmovecr.vhd` verifies all 22 documented constants,
all 10 undocumented constants, and a sample of offsets from the 0x10-0x2F default
range.

## References

- Motorola MC68881/MC68882 User's Manual, Section 6 (documented constants)
- WinUAE source, `fpu/fpu_uae.cpp` (Toni Wilen, undocumented constants)
- QEMU `target/m68k/fpu_helper.c` (`fpu_rom[128]`) for cross-reference
