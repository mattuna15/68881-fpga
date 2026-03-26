# NeXT 68040LC Emulator

NeXT Mach kernel boot emulator targeting a 68LC040 (68040 without internal FPU)
on the Zynq UltraScale+ validation platform. FPU instructions are intercepted
via F-line trapping and routed to the hardware MC68882 FPGA over AXI-Lite.

## Architecture

```
ARM Cortex-A53 (bare-metal)
  └── Musashi M68K emulator (68LC040 mode)
        ├── NeXT memory map (ROM/RAM/VRAM/I/O)
        ├── NeXT device stubs (SCR1, SCR2, SCC, timer, interrupts, DMA)
        ├── F-line handler → MC68882 FPGA (AXI-Lite)
        └── SCC serial TX → ARM UART console
```

## Memory Map

| Range | Size | Description |
|-------|------|-------------|
| `0x00000000` | 128 KB | EPROM (exception vectors, halt loop) |
| `0x02000000` | 1 MB | NeXT device I/O space |
| `0x04000000` | 16 MB | Main RAM (kernel loads here) |
| `0x0B000000` | 256 KB | Video RAM (mono framebuffer) |

## NeXT Hardware Stubs

| Register | Address | Status |
|----------|---------|--------|
| SCR1 (machine type) | `0x0200C000` | Returns NeXT_WARP9 (68040) |
| SCR2 (system control) | `0x0200D000` | Read/write |
| INTRMASK | `0x02007800` | Read/write |
| INTRSTAT | `0x02007000` | Read-only |
| SCC channel A | `0x02018000` | TX→UART, RX buffer |
| Timer | `0x02016000` | 16-bit counter at ~1 MHz |
| Event counter | `0x0201A000` | Microsecond counter |
| DMA CSRs | `0x020000xx` | Stub: return COMPLETE |

## Building

### Vitis IDE

The project appears as **NeXT-68040** in the Vitis Explorer alongside `hello_world`.
Select it in the FLOW panel Component dropdown and click Build.

### Running on Hardware

Use the **NeXT-68040_hw** launch configuration (FLOW → Run).
Requires the AXU3EG board with the MC68882 bitstream programmed.

### Running on QEMU

```powershell
cd validation\NeXT-68040
.\qemu_build_run.ps1          # run existing build
.\qemu_build_run.ps1 -Build   # build with QEMU_MODE + run
.\qemu_build_run.ps1 -Clean   # clean build + run
```

QEMU mode skips DisplayPort and FPU hardware init. The 68K emulation,
device stubs, and SCC serial output all work under QEMU.

## Current Status

The test program reads SCR1 and writes `NXT\r\n` to the SCC serial port,
then halts. Next step: load a real NeXT Mach kernel binary.

## Key Files

| File | Purpose |
|------|---------|
| `src/main.c` | Boot flow and emulation loop |
| `src/next_memory.c/h` | Musashi memory callbacks, sparse 32-bit address map |
| `src/next_devs.c/h` | NeXT hardware register emulation |
| `src/next_hw.h` | NeXT hardware address definitions (from mk-108.1) |
| `src/next_mon_stub.c/h` | Fake ROM monitor (mon_global) for kernel boot |
| `src/musashi/m68kconf.h` | Musashi config: 68040 enabled, F-line callback |
| `src/fline_handler.c` | F-line FPU instruction decode → MC68882 hardware |

## Reference

- NeXT Mach kernel source: `NeXTMach/mk-108.1/`
- Hardware addresses: `NeXTMach/mk-108.1/next/cpu.h`
- Boot checklist: `docs/nextmach_boot_checklist.md`
- FPSP comparison: `docs/fpsp_comparison_checklist.md`
