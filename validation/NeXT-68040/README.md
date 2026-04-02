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

### ROM Boot — Monitor Reached (QEMU)

The 68040 Turbo ROM (Rev 3.3 v74, 128 KB) boots successfully through
all hardware init stages under QEMU and reaches the ROM monitor serial
input poll:

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

### Hardware Boot — In Progress

Two issues were diagnosed and fixed by comparing QEMU (working) with
ZynqMP hardware (failing):

**1. FPU frame format mismatch (fixed)**

The Turbo ROM's POST includes FPU testing (FSAVE/FRESTORE) between the
event counter calibration and RTC access.  On QEMU, `fline_init()` is
not called, so F-line instructions trap as exceptions and the ROM detects
"no FPU" — it skips the test.  On hardware, `fline_init()` routes F-line
instructions to the MC68882 FPGA, which responds with **68882 frame
formats** instead of the 68040 formats the Turbo ROM expects.  The ROM
detected a wrong FPU type and entered a blink error loop before reaching
RTC.

Fix: disabled `fline_init()` on hardware (temporary `#if 0` in `main.c`).
The ROM now skips the FPU test and proceeds through RTC.  Proper fix:
add FSAVE/FRESTORE frame translation (68882 ↔ 68040) in `fline_handler.c`.

**2. RTC counter value mismatch (fixed)**

The ZynqMP PS RTC returned an unexpected counter value (0 or small Unix
timestamp) in registers `$20-$23`.  The ROM's timing calibration uses
the RTC counter alongside the event counter, and the wrong value sent
it down a failing code path (error code 4, blink loop at `$01004104`).

Fix: use a fixed epoch value (`NEXT_EPOCH_DEFAULT = 3,913,401,600`,
matching QEMU's `NEXT_EPOCH_2024`) instead of reading the ZynqMP PS
RTC.  The ROM now boots through all POST stages on real hardware and
reaches the monitor prompt at `$010024E2`.

### Hardware Boot — Monitor Reached

With both fixes applied, the Turbo ROM boots on ZynqMP hardware:

1. All POST stages pass (memory, timing calibration, RTC, DSP probe)
2. VRAM renders to DisplayPort via dp_video (1920x1080, NeXT mono centred)
3. ROM displays "System test failed" on the NeXT bitmap console
4. **Reaches serial console input poll at `$010024E2`** — the ROM monitor prompt

### ROM Monitor Commands

The `NeXT>` prompt accepts these commands (Copyright 1988-1990 NeXT Inc.):

| Command | Description |
|---------|-------------|
| `p` | Inspect/modify configuration parameters (NVRAM) |
| `a [n]` | Open address register |
| `m` | Print memory configuration |
| `d [n]` | Open data register |
| `r [regname]` | Open processor register |
| `s [systemreg]` | Open system register |
| `e [lwb] [alist] [format]` | Examine memory (long/word/byte) |
| `ec` | Print recorded system error codes |
| `ej [drive#]` | Eject optical disk (default=0) |
| `eo` | Same as `ej` |
| `ef [drive#]` | Eject floppy disk (default=0) |
| `c` | Continue execution at last PC |
| `b [device[(ctrl,unit,part)] [filename] [flags]]` | Boot from device |
| `S [fcode]` | Open function code (address space) |
| `R [radix]` | Set input radix |

Notes: `[lwb]` selects long/word/byte length (default=long). `[alist]` is a
starting address or list of addresses to cyclically examine.

### ROM Monitor Input — KMS Keyboard

The ROM monitor prompt at `$010024E2` does NOT use SCC serial for input.
It polls the **KMS (Keyboard/Mouse/Sound) chip** at `P_MON` (`$0200E000`):

- `$0200E000`: `mon_csr` — status register; bit 22 (`KM_DAV`) = keyboard data available
- `$0200E008`: `mon_km_data` — keyboard event data

The `mg_getc` function at `$01008140` is `kmgetc()` (from `nextdev/km.c`),
which polls `mon_csr.km_dav` and reads `mon_km_data`.  The keyboard data
is a 32-bit `union kybd_event` (from `nextdev/kmreg.h`):

```
bits 31-16: device address (0 for keyboard)
bit 15:     valid (must be 1)
bits 14-8:  modifier flags (alt, command, shift, control)
bit 8:      up_down (0=down, 1=up)
bits 7-1:   key_code (7-bit NeXT scan code)
```

Key codes map through `ascii[]` table in `nextdev/keycodes.h`.  The ROM
processes key-down events (ignores key-up).

To inject serial input: when ARM UART has data, convert ASCII to NeXT
key_code (reverse lookup in `ascii[]`), build a `kybd_event` with
`valid=1, up_down=0`, and make `mon_csr` return `KM_DAV=1` with the
event in `mon_km_data`.

Current workaround: `mg_getc` intercept in `main.c` instruction hook
(pops SCC RX data and returns directly).  Not yet working because the
ROM's tight poll loop at `$010024E2` calls `$0100A1A8` which reads
`mon_csr` directly, not through `mg_getc`.

### Hardware FPU Verified

The MC68881 FPGA handles FPU instructions via F-line trapping with
FSAVE/FRESTORE frame translation (68881/68882 ↔ 68040).  Verified
from the ROM monitor:

```
NeXT> e 4001000
4001000: ? F23C4000       ; FMOVE.L #42, FP0
4001004: ? 0000002A       ;   (immediate: 42)
4001008: ? F2000023       ; FMUL.X FP0, FP0
400100C: ? F2006000       ; FMOVE.L FP0, D0
4001010: ? 4E404E71       ; TRAP #0 (return to monitor)
NeXT> r pc
pc: ? 4001000
NeXT> c
Exception #32 (0x80) at pc 0x4001012 sp 0x4fff72a
NeXT> d 0
d0: 000006E4              ; 1764 = 42 × 42 ✓
```

Full stack: serial keystroke → KMS → ROM monitor → 68K code → F-line
trap → ARM fline_handler → AXI-Lite → MC68881 FPGA → result to D0.

### Mach Kernel Boot — SCSI Disk Loaded, Autoconfiguration In Progress

The Mach kernel (NEXTSTEP 3.3) loads from a SCSI disk image on SD card
and reaches the autoconfiguration phase. The kernel loads ~800 KB of
code from disk and begins device probing.

**Boot sequence completed:**
1. ROM monitor: `b sd` → probes SCSI targets 0-7, finds disk at target 6
2. ROM reads boot blocks, disk label, kernel binary from SCSI disk
3. Kernel starts: MMU enabled, timer configured at 500 µs, ESP reset
4. Kernel SCSI probe: targets 0-5 timeout, target 6 found (INQUIRY)
5. Disk attach: START/STOP, TEST UNIT READY, READ CAPACITY (730016 sectors)
6. Disk I/O: reads boot sectors, kernel text from LBAs 380512-414688
7. LUN probe: INQUIRY for LUNs 0-7 on target 6 (LUNs 1-7 return 0x7F)

**Current hang point:** After LUN probing completes, the kernel's final
SELECT timeout (target 0, wrapping from target 7) triggers a `screset`
loop. The IPL 3 interrupt fires correctly via Musashi's `MOVE to SR`
handler, but a batch-boundary timing interaction between the IPL 3 SCSI
handler and the IPL 6 timer causes the SCSI controller state machine
to enter "bad reselection" error recovery.

**Fixes applied (this session):**
- DMA CSR read format: returns `csr << 24` (Turbo format), not write echo
- ESP DMA ctrl INT enable: edge detection prevents spurious re-raise
- SELECT timeout phase: set to STATUS on timeout (matches Previous emulator)
- Generic DMA CSR: proper 8-bit state tracking with Turbo write-bit decoding

**Expected next display text:** `en0 at 0x2006000`, `dsp0`, `sound0`,
`root on sd0` — these are the device probes AFTER SCSI completes.

### Next Steps

1. Fix batch-boundary timer pre-emption of IPL 3 SCSI handler
2. Implement MCS1850 protocol support (bit 7 inversion for new clock chip reads/writes)
3. USB HID keyboard integration (from hello_world project)

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
