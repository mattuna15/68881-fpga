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
- NeXT hardware register stubs (SCR1/SCR2, SCC serial, timer, event counter, interrupt controller, DMA CSRs)
- SCC channel A serial console: TX routed to ARM UART, RX buffered from ARM UART
- Test program verified on hardware: reads SCR1, outputs `NXT` via SCC, halts cleanly
- QEMU support: two-process launch (A53 + PMU MicroBlaze), verified `NXT` output
- Vitis IDE project with hardware launch configuration
- Standalone CMake build for QEMU (packages sources as static lib to solve link-order issues)
- NeXT ROM images obtained (68030 Rev 1.2, 68040 Rev 2.5, 68040 Turbo Rev 3.3)
- ROM loaded at 0x00000000 with BMAP mirror at 0x01000000

### ROM Boot - In Progress

The 68040 Turbo ROM (Rev 3.3 v74, 128 KB) loads and begins executing at
PC=0x0100001E but hits a recursive exception cascade. The ROM's first
instructions use `movec` to set VBR and configure 68040 TT registers,
then probe hardware. An unhandled exception (likely from accessing an
unimplemented register) triggers the ROM's exception handler, which itself
faults, pushing 68040 exception frames down the stack into the device I/O
space (0x020Exxxx).

### Next Steps

1. Enable `M68K_EMULATE_PMMU` in Musashi so `movec` TT/TC/SRP instructions work
2. Add trace logging at the first exception to identify which instruction/address triggers it
3. Expand device stubs for registers the ROM probes during early init
4. Get the ROM monitor to reach its serial console prompt
5. Cross-compile standalone boot code from mk-108.1 sources (MIT syntax assembly needs translation)

## Memory Map

| Range | Size | Description |
|-------|------|-------------|
| `0x00000000` | 128 KB | EPROM (exception vectors, ROM monitor) |
| `0x01000000` | 128 KB | EPROM BMAP mirror (68040 execution address) |
| `0x02000000` | 1 MB | NeXT device I/O space |
| `0x04000000` | 16 MB | Main RAM (kernel loads here) |
| `0x0B000000` | 256 KB | Video RAM (mono framebuffer) |

## NeXT Hardware Stubs

| Register | Address | Status |
|----------|---------|--------|
| SCR1 (machine type) | `0x0200C000` | Returns NeXT_WARP9 (68040 Turbo) |
| SCR2 (system control) | `0x0200D000` | Read/write, DRAM config |
| INTRMASK | `0x02007800` | Read/write |
| INTRSTAT | `0x02007000` | Read-only |
| SCC channel A | `0x02018000` | TX to UART, RX buffer |
| Timer | `0x02016000` | 16-bit counter at ~1 MHz |
| Event counter | `0x0201A000` | Microsecond counter |
| DMA CSRs | `0x020000xx` | Stub: return COMPLETE |
| All other I/O | `0x02xxxxxx` | Accept writes, reads return 0 |

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
| `src/next_devs.c/h` | NeXT hardware register emulation stubs |
| `src/next_hw.h` | NeXT hardware address definitions (from mk-108.1) |
| `src/next_mon_stub.c/h` | Fake ROM monitor (mon_global) for kernel boot |
| `src/next_rom_image.h` | Rev 3.3 ROM binary as C header (128 KB) |
| `src/musashi/m68kconf.h` | Musashi config: 68040 enabled, F-line callback |
| `src/musashi/m68kcpu.c` | Patched: added CPU_ADDRESS_MASK for 68LC040 |
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

## Reference

- NeXT Mach kernel source: `NeXTMach/mk-108.1/`
- Hardware addresses: `NeXTMach/mk-108.1/next/cpu.h`, `scr.h`
- ROM monitor headers: `NeXTMach/mk-108.1/mon/global.h`
- Boot checklist: `docs/nextmach_boot_checklist.md`
- FPSP comparison: `docs/fpsp_comparison_checklist.md`
- Previous (NeXT emulator): https://github.com/previous-emulator/previous
