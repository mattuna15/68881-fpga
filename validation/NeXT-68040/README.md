# NeXT 68040LC Emulator

NeXT computer emulator targeting the 68LC040 (68040 without internal FPU)
running on the Zynq UltraScale+ validation platform. FPU instructions are
intercepted via F-line trapping and routed to the hardware MC68882 FPGA
over AXI-Lite.

## Architecture

```
ARM Cortex-A53 (bare-metal on ZU3EG)
  +-- Musashi M68K emulator (68LC040 mode)
        +-- NeXT memory map (ROM/RAM/VRAM/I/O)
        +-- NeXT device stubs (SCR1, SCR2, SCC, timer, interrupts, DMA)
        +-- F-line handler --> MC68882 FPGA (AXI-Lite)
        +-- SCC serial TX --> ARM UART console
```

## Status

### Working

- 68LC040 CPU emulation via Musashi (fixed CPU_ADDRESS_MASK bug for 32-bit addressing)
- Musashi CPU_TYPE_LC040 fix: added LC040 to all `CPU_TYPE_IS_xxx_PLUS` macros and fixed `#else` fallback chains that evaluated to 0 when only `M68K_EMULATE_040` was enabled (caused `movec`, `movem`, and all 010+ instructions to throw illegal instruction exceptions)
- NeXT hardware register stubs (SCR1/SCR2, SCC serial, timer, event counter, interrupt controller, DMA CSRs)
- SLOT_ID_BMAP address remapping: the 68040 ROM uses `SLOT_ID_BMAP=0x00100000` (from mk-108.1 cpu.h), shifting all device registers from `0x020xxxxx` to `0x021xxxxx`. I/O handlers now accept both ranges via `next_io_canon()`.
- Byte-level I/O reads for event counter, SCR1, SCR2 (ROM reads these as individual bytes)
- RTC stub: returns RTDATA=1 when RTCE is active on SCR2 reads (needs full MC68HC68T1 protocol for completion)
- SCC channel A serial console: TX routed to ARM UART, RX buffered from ARM UART
- Test program verified on hardware: reads SCR1, outputs `NXT` via SCC, halts cleanly
- QEMU support: two-process launch (A53 + PMU MicroBlaze), verified `NXT` output
- Vitis IDE project with hardware launch configuration
- Standalone CMake build for QEMU (packages sources as static lib to solve link-order issues)
- NeXT ROM images obtained (68030 Rev 1.2, 68040 Rev 2.5, 68040 Turbo Rev 3.3)
- ROM loaded at 0x00000000 with BMAP mirror at 0x01000000
- Instruction trace hook (configurable TRACE_LIMIT in main.c) for boot debugging

### ROM Boot — Monitor Reached

The 68040 Turbo ROM (Rev 3.3 v74, 128 KB) boots successfully through
all hardware init stages and reaches the ROM monitor serial input poll:

1. Sets VBR to ROM exception table at `0x010145B0`
2. Configures 68040 CACR, TT0/TT1/DTT0/DTT1 registers
3. Executes PFLUSH and CINVA (cache invalidate)
4. Programmes BMAP memory controller registers at `0x020C0xxx`
5. Sizes main memory via BMAP probe sequence
6. Reads event counter (microsecond timer) for timing calibration
7. Reads RTC via SCR2 bit-bang protocol — NVRAM checksum validates
8. Reads NVRAM a second time (readback verify)
9. DSP56001 probe: writes ICR_INIT, polls ISR.HF2, loads DSP program memory
10. Second DSP handshake: polls IVR bit 2 after host command
11. SCSI/Ethernet/video init (writes to various device registers)
12. Relocates VBR to VRAM at `0x0B03FC00`
13. **Reaches serial console input poll at `$010024E2`** — the ROM monitor prompt

The ROM loops at `$010024E2` calling a subroutine at `$0100A1A8` (likely SCC
serial poll), testing D3, and looping while no input. This is the ROM's
command-line prompt waiting for serial console keystrokes.

The ROM renders its output (including "System test failed") to the NeXT mono
framebuffer in VRAM via its bitmap console `mg_putc` function at `$010081C8`.
The instruction hook intercepts each `mg_putc` call and echoes the character
to the ARM UART, making ROM output visible under QEMU.

Key findings:
- `mon_global` structure at `$0B03F800` (VRAM), ROM keeps pointer in A3
- `mg_putc = $010081C8` (bitmap console), `mg_getc = $01008140`
- ROM version: `mg_seq = 74` (Rev 3.3 v74), confirmed via mon_global scan
- ROM always uses bitmap console for POST output, even with `ni_alt_cons=1`

### Next Steps

1. Wire up serial input so typed characters reach the ROM monitor via `mg_getc`
2. Boot a kernel via the ROM's `bsd` or `en` boot commands
3. Cross-compile standalone boot code from mk-108.1 sources
4. On real hardware: ROM output goes to DP via VRAM → text_fb → dp_video

## Memory Map (Turbo 68040)

Derived from analysis of the [Previous NeXT emulator](https://github.com/previous-emulator/previous)
(`previous/src/cpu/memory.c`). The Turbo has a different layout from the
standard 68030/68040 systems.

| Range | Size | Description |
|-------|------|-------------|
| `0x00000000` | 128 KB | EPROM (exception vectors, ROM monitor) |
| `0x01000000` | 128 KB | EPROM BMAP mirror (68040 execution address) |
| `0x02000000` | 128 KB | I/O space (device registers) |
| `0x020C0000` | 64 B | BMAP chip (memory controller / Ethernet) |
| `0x02200000` | 128 KB | TMC (Turbo Memory Controller — video config, ADB) |
| `0x04000000` | 128 MB | Main RAM (4 banks × 32 MB on Turbo) |
| `0x0B000000` | — | **NOT VRAM on Turbo** — falls in RAM bank 3 ($0A-$0B) |
| `0x0C000000` | 256 KB | **VRAM (Turbo display)** — 2bpp mono framebuffer |
| `0x80000000+` | — | Non-cached mirror via TT (bit 31 = same physical addr) |

**Important:** The 68040 ROM accesses I/O and VRAM through `$8xxxxxxx`
addresses (e.g., `$820C0020` = `$020C0020`, `$8C000000` = `$0C000000`).
All memory callbacks mask bit 31 via `addr_normalise()`.

### Non-Turbo vs Turbo VRAM

| | Non-Turbo | Turbo |
|---|---|---|
| VRAM address | `$0B000000` | `$0C000000` |
| Stride | 288 bytes/line (1152px padded) | 280 bytes/line (1120px, no pad) |
| RAM banks | 4 × 16 MB | 4 × 32 MB |
| `$0B000000` is | VRAM | RAM bank 3 |
| `$0C000000` is | VRAM MWF mirror | VRAM (primary) |

## Peripheral Register Map (Turbo)

Source: Previous emulator `src/ioMemTabTurbo.c`, `src/tmc.c`, `src/sysReg.c`.

### I/O Space (`$02000000-$0201FFFF`)

| Address | Device | Notes |
|---------|--------|-------|
| `$02000010-$020001D0` | DMA CSRs | 7 channels, Motorola controller |
| `$02004xxx` | DMA address regs | Next/Limit/Start/Stop per channel |
| `$02006000-$0200600F` | Ethernet (AT&T 7213) | Status/mask/mode/node ID |
| `$02006010-$02006014` | Memory timing | 5 bytes |
| `$02007000` | Interrupt status | 32-bit, read-only |
| `$02007800` | Interrupt mask | 32-bit, read/write |
| `$02008000-$02008007` | DSP56001 | ICR/CVR/ISR/IVR + 24-bit data |
| `$0200C000-$0200C003` | SCR1 | Machine type, read-only |
| `$0200D000-$0200D003` | SCR2 | RTC bit-bang, DSP, LED |
| `$0200E000-$0200E00F` | KMS | Keyboard/mouse/sound (NOT mon_global) |
| `$02010000` | Brightness | 32-bit |
| `$02012000-$02012003` | GPIO | Turbo only (replaces MO drive) |
| `$02014000-$0201400B` | SCSI (NCR53C90A) | + DMA ctrl at $02014020 |
| `$02014100-$02014108` | Floppy (82077AA) | |
| `$02016000-$02016004` | Hardclock/Timer | Counter + CSR |
| `$02018000-$02018003` | SCC (Z8530) | Ctrl B/A, Data B/A |
| `$0201A000-$0201A003` | Event counter | Microsecond timer |
| `$0201C000-$0201C003` | RAMDAC (Turbo) | Moved from $02018100 |

### TMC Space (`$02200000`, Turbo only)

| Offset | Register | Value |
|--------|----------|-------|
| `$0000` | TMC SCR1 | Turbo-format system control |
| `$0010` | TMC Control | Default $0D17038F |
| `$0080` | Horizontal config | HFPORCH=24, HSYNC=32, HBPORCH=72, HDISCNT=280 |
| `$0090` | Vertical config | VFPORCH=8, VSYNC=8, VBPORCH=48, VDISCNT=832 |
| `$0100` | Video interrupt | Bit 0=status, bit 1=mask |
| `$0208` | ADB | Apple Desktop Bus |

### Video Parameters (Turbo BW)

- Resolution: 1120 × 832, 2bpp (4 pixels/byte), MSB = leftmost
- Stride: 280 bytes/line (no padding)
- Palette: 00=white(255), 01=light grey(170), 10=dark grey(85), 11=black(0)
- VBL: 68 Hz
- Total VRAM used: 280 × 832 = 232,960 bytes

## Building

### Vitis IDE (Hardware)

The project appears as **NeXT-68040** in the Vitis Explorer.
Select it in the FLOW panel Component dropdown, Build, then Run
with the **NeXT-68040_hw** launch configuration.

### QEMU (Software Debugging)

```powershell
cd validation\NeXT-68040
.\qemu_build_run.ps1 -Build -Clean   # first time
.\qemu_build_run.ps1                 # subsequent runs
```

QEMU uses a two-process launch: A53 (foreground, serial on stdio) +
PMU MicroBlaze (background, delayed 3s). Uses `arm-generic-fdt` machine
with ZynqMP DTBs from the Vitis toolchain. The A53 boots with
`use-pmufw=false` and an APU reset register write.

## ROM Images

Located in `rom/NeXTROMS/NeXTROMS/`:

| ROM | File | Size | Target |
|-----|------|------|--------|
| 68030 Rev 1.2 | `68030/Rev_1.2.BIN` | 64 KB | NeXT Cube (68030) |
| 68040 Rev 2.5 | `68040/Rev_2.5_v66.BIN` | 128 KB | NeXTstation (68040) |
| 68040 Turbo Rev 3.3 | `68040 (turbo)/Rev_3.3_v74.BIN` | 128 KB | NeXTstation Turbo |

The Turbo ROM (Rev 3.3) is currently loaded. Its vectors:
- Initial SSP: `0x04000400` (main RAM)
- Initial PC: `0x0100001E` (ROM BMAP address)

## Key Files

| File | Purpose |
|------|---------|
| `src/main.c` | Boot flow, emulation loop, ROM loading |
| `src/next_memory.c/h` | Musashi memory callbacks, sparse 32-bit address map |
| `src/next_devs.c/h` | NeXT hardware register emulation stubs + SLOT_ID_BMAP remapping |
| `src/next_rtc.c/h` | MC68HC68T1 RTC emulation (SCR2 bit-bang, QEMU/hardware backends) |
| `src/next_dsp.c/h` | DSP56001 host interface stub (ICR/CVR/ISR/IVR + 4K memory) |
| `src/next_hw.h` | NeXT hardware address definitions (from mk-108.1) |
| `src/next_mon_stub.c/h` | Fake ROM monitor (mon_global) for kernel boot |
| `src/next_rom_image.h` | Rev 3.3 ROM binary as C header (128 KB) |
| `src/musashi/m68kconf.h` | Musashi config: 68040 enabled, F-line callback |
| `src/musashi/m68kcpu.c/h` | Patched: CPU_ADDRESS_MASK + CPU_TYPE_IS_xxx_PLUS for 68LC040 |
| `src/fline_handler.c` | F-line FPU instruction decode to MC68882 hardware |
| `CMakeLists.txt` | Standalone CMake for QEMU builds |
| `qemu_build_run.ps1` | Build + launch script for QEMU |
| `_ide/launch.json` | Vitis hardware launch configuration |

## Bugs Found and Fixed

### Musashi 68LC040 CPU_ADDRESS_MASK (Critical)

The Musashi `m68k_set_cpu_type(M68K_CPU_TYPE_68LC040)` case was missing
`CPU_ADDRESS_MASK = 0xffffffff`. All other 68040 variants set this, but
the LC040 case omitted it, leaving the mask at the 68000 default of
`0x00ffffff` (24-bit). This caused all 32-bit addresses above 16 MB to
be truncated, making the kernel entry point `0x04001000` become `0x001000`
(zeroed RAM = garbage instructions).

Fix: one line added to `musashi/m68kcpu.c` line 939.

### Musashi 68LC040 CPU_TYPE_IS_xxx_PLUS macros (Critical)

`CPU_TYPE_LC040 (0x100)` was missing from all `CPU_TYPE_IS_xxx_PLUS` bitmask
macros in `m68kcpu.h`. Additionally, when only `M68K_EMULATE_040` is enabled
(010/020/030 all OFF), the `#else` fallback chains resolved to 0:

    CPU_TYPE_IS_010_PLUS → CPU_TYPE_IS_EC020_PLUS → CPU_TYPE_IS_020_PLUS → 0

This caused **every** 010+ instruction (`movec`, `moves`, bitfield ops, etc.)
to throw an illegal instruction exception for the LC040, making ROM boot
impossible — the very first `movec A0,VBR` at the ROM entry point failed.

Fix: added `CPU_TYPE_LC040` to all bitmask variants, changed `#else` branches
to delegate upward (`020_PLUS → 030_PLUS → 040_PLUS`) instead of returning 0,
and added `M68K_EMULATE_040` to the `EC020_PLUS` preprocessor guard.

## Reference

- NeXT Mach kernel source: `NeXTMach/mk-108.1/`
- Hardware addresses: `NeXTMach/mk-108.1/next/cpu.h`, `scr.h`
- ROM monitor headers: `NeXTMach/mk-108.1/mon/global.h`
- Boot checklist: `docs/nextmach_boot_checklist.md`
- FPSP comparison: `docs/fpsp_comparison_checklist.md`
- Previous (NeXT emulator): https://github.com/previous-emulator/previous
