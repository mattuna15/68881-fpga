# FMOVECR Constants: QEMU Reference Summary

Source reference:
- QEMU upstream m68k FPU helper table: `target/m68k/fpu_helper.c` (`fpu_rom[128]`)
- URL: https://raw.githubusercontent.com/qemu/qemu/master/target/m68k/fpu_helper.c

Notes:
- `FMOVECR #ccc,FPn` uses `ccc` as a constant-ROM offset.
- Undefined offsets are treated as `0.0` in QEMU for some FPU variants.
- Values below are the 80-bit extended encoding as `SEEEE_MMMMMMMMMMMMMMMM`
  represented here as a single 20-hex-digit value.

| Offset | Constant   | FP80 Hex |
|---|---|---|
| `0x00` | Pi       | `4000C90FDAA22168C235` |
| `0x0B` | Log10(2) | `3FFD9A209A84FBCFF798` |
| `0x0C` | e        | `4000ADF85458A2BB4A9A` |
| `0x0D` | Log2(e)  | `3FFFB8AA3B295C17F0BC` |
| `0x0E` | Log10(e) | `3FFDDE5BD8A937287195` |
| `0x0F` | 0.0      | `00000000000000000000` |
| `0x30` | ln(2)    | `3FFEB17217F7D1CF79AC` |
| `0x31` | ln(10)   | `4000935D8DDDAAA8AC17` |
| `0x32` | 10^0     | `3FFF8000000000000000` |
| `0x33` | 10^1     | `4002A000000000000000` |
| `0x34` | 10^2     | `4005C800000000000000` |
| `0x35` | 10^4     | `400C9C40000000000000` |
| `0x36` | 10^8     | `4019BEBC200000000000` |
| `0x37` | 10^16    | `40348E1BC9BF04000000` |
| `0x38` | 10^32    | `40699DC5ADA82B70B59E` |
| `0x39` | 10^64    | `40D3C2781F49FFCFA6D5` |
| `0x3A` | 10^128   | `41A893BA47C980E98CE0` |
| `0x3B` | 10^256   | `4351AA7EEBFB9DF9DE8E` |
| `0x3C` | 10^512   | `46A3E319A0AEA60E91C7` |
| `0x3D` | 10^1024  | `4D48C976758681750C17` |
| `0x3E` | 10^2048  | `5A929E8B3B5DC53D5DE5` |
| `0x3F` | 10^4096  | `7525C46052028A20979B` |
