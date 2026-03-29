# NeXTMach Kernel Boot on Musashi 68040LC — Checklist

## Context

Boot the NeXTMach Mach kernel (`NeXTMach/mk-108.1/`) on the existing Musashi
emulator (`validation/hello_world/src/`) configured as a 68LC040 (no internal
FPU). The hardware MC68882 FPGA handles FPU instructions via the existing
F-line callback. This builds on the existing 68040 EmuTOS plan
(`docs/plans/2026-03-22-68040-emutos-variant.md`) but targets a completely
different OS — the NeXT Mach kernel expects NeXT hardware, not Atari ST.

The kernel entry point is at physical `0x04000000`. It requires a ROM monitor
to provide a `mon_global` parameter structure, and probes for NeXT-specific
hardware at `0x02xxxxxx`. The goal is to reach console output (serial or
bitmap) and the kernel `main()` call.

---

## Key Reference Files

| Area | File |
|------|------|
| Kernel entry | `NeXTMach/mk-108.1/next/locore.s` |
| Early init | `NeXTMach/mk-108.1/next/next_init.c` |
| Machine dep | `NeXTMach/mk-108.1/next/machdep.c` |
| ROM monitor API | `NeXTMach/mk-108.1/mon/global.h` |
| HW addresses | `NeXTMach/mk-108.1/next/cpu.h` |
| Memory layout | `NeXTMach/mk-108.1/next/vm_param.h` |
| SCR registers | `NeXTMach/mk-108.1/next/scr.h` |
| Interrupt defs | `NeXTMach/mk-108.1/next/scb.h`, `scb.s` |
| MMU setup | `NeXTMach/mk-108.1/next/mmu.h`, `pmap.c` |
| Serial console | `NeXTMach/mk-108.1/nextdev/zs.c`, `zsreg.h` |
| Bitmap console | `NeXTMach/mk-108.1/nextdev/km.c` |
| Autoconfig | `NeXTMach/mk-108.1/next/autoconf.c` |
| Timer/clock | `NeXTMach/mk-108.1/next/clock.c` |
| Existing Musashi config | `validation/hello_world/src/musashi/m68kconf.h` |
| Existing memory map | `validation/hello_world/src/emu_memory.c` |
| Existing main | `validation/hello_world/src/main.c` |

---

## Phase 1: Musashi 68040LC Configuration

- [ ] **1.1** Enable 68040 in `m68kconf.h`: `M68K_EMULATE_040 = M68K_OPT_ON`
- [ ] **1.2** Keep `M68K_EMULATE_PMMU = M68K_OPT_OFF` initially (flat memory, no MMU translation). The kernel will write to TT/TC/SRP registers via `movc` but Musashi will just absorb them as NOPs.
- [ ] **1.3** Add boot menu option (e.g. option 4): "NeXTMach kernel" in `main.c`
- [ ] **1.4** Set `m68k_set_cpu_type(M68K_CPU_TYPE_68LC040)` for the NeXT boot path
- [ ] **1.5** F-line callback stays as-is — FPU instructions trap to external MC68882 hardware

---

## Phase 2: Memory Map Expansion

The NeXT kernel uses a 32-bit address space. Current emulator is 16 MB (24-bit masked). Need to expand or remap.

### Address Space Required

| Range | Size | Purpose |
|-------|------|---------|
| `0x00000000-0x00020000` | 128 KB | EPROM / ROM monitor |
| `0x02000000-0x020c0000` | 768 KB | Device I/O space |
| `0x04000000-0x04400000` | 4 MB+ | Main RAM (kernel text/data) |
| `0x0B000000-0x0B03A800` | 238 KB | Monochrome video RAM |

- [ ] **2.1** Expand emulated RAM from 16 MB to at least 128 MB (or use sparse mapping). The kernel loads at `0x04000000` which is outside the current 16 MB window.
- [ ] **2.2** Add a NeXT-specific memory read/write handler in `emu_memory.c` (or new file `next_memory.c`) that maps:
  - `0x04000000+` → main RAM array (kernel code/data)
  - `0x02000000-0x020c0000` → I/O register handlers
  - `0x0B000000+` → video RAM (can map to existing `gfx_fb` buffer)
  - `0x00000000-0x00020000` → ROM monitor area
- [ ] **2.3** Set initial SSP and PC vectors at `0x04000000` (SSP) and `0x04000004` (PC → `entry` in locore.s)

---

## Phase 3: ROM Monitor Stub (`mon_global`)

The kernel's `NeXT_init()` expects a pointer to a `mon_global` structure passed from the ROM monitor. We need to fake this.

**Reference**: `NeXTMach/mk-108.1/mon/global.h`

- [ ] **3.1** Create `next_mon_stub.c/h` that builds a `mon_global` structure in emulated RAM with:
  - `mg_machine_type` = `NeXT_WARP9` (indicates 68040 hardware)
  - `mg_board_rev` = sensible value
  - `mg_pagesize` = 8192
  - `mg_region[0]` = main memory region (base=`0x04000000`, size=4MB+)
  - `mg_console_i` = `CONS_I_SCC_A` (serial input)
  - `mg_console_o` = `CONS_O_SCC_A` (serial output — easiest to emulate)
  - `mg_vbr` = address of initial SCB
  - `mg_simm[0..3]` = SIMM configuration (fake 4x1MB or similar)
- [ ] **3.2** Set up initial SCB (System Control Block) at `0x04000000` with exception vectors pointing to stub handlers (bus error, address error, etc.)
- [ ] **3.3** Build the initial stack and register state:
  - A0 = return address
  - `mg` parameter = pointer to `mon_global` in RAM
  - `cons_i`, `cons_o` = console device IDs
  - Other NeXT_init() parameters from locore.s calling convention

---

## Phase 4: NeXT Hardware Register Stubs

The kernel probes for NeXT hardware at fixed addresses. These must return sensible values or the kernel will crash/hang.

### Critical (kernel dies without these)

- [ ] **4.1** **P_SCR1** @ `0x0200C000` (read-only): System Control Register 1
  - Return machine type = `NeXT_WARP9` (68040)
  - CPU clock = 25 MHz
  - Board revision = reasonable value
  - This is the FIRST thing `NeXT_init()` reads to determine CPU type

- [ ] **4.2** **P_SCR2** @ `0x0200D000` (read/write): System Control Register 2
  - Readable/writable register
  - Bit 0 = EKG LED (toggle)
  - Bits 23-16 = DRAM bank configuration
  - Bit 15 = Timer on IPL7

- [ ] **4.3** **P_INTRMASK** @ `0x02007800` (read/write): Interrupt mask
  - Must be writable (kernel zeros it to disable all interrupts during init)
  - Store and return written value

- [ ] **4.4** **P_INTRSTAT** @ `0x02007000` (read-only): Interrupt status
  - Return 0 initially (no pending interrupts)

### Required for Console Output

- [ ] **4.5** **P_SCC** @ `0x02018000`: Zilog 8530 Serial Controller
  - Emulate channel A for serial console
  - Minimum: TX buffer empty status (RR0 bit 2 = 1), accept data writes
  - Route TX data bytes to ARM UART (`xil_printf`) for visibility
  - This is the simplest console path — serial output to ARM debug UART

- [ ] **4.6** **P_SCC_CLK** @ `0x02018004`: SCC clock select (just accept writes)

### Required for Timing

- [ ] **4.7** **P_TIMER** @ `0x02016000`: Timer counter
  - 16-bit counter at ~1 MHz
  - Increment based on emulated cycles
  - CSR at `0x02016004` — accept enable bit writes

- [ ] **4.8** **P_EVENTC** @ `0x0201A000`: Event counter
  - High-resolution microsecond counter
  - Return incrementing value based on emulated time

### Stub (accept writes, return 0)

- [ ] **4.9** **P_MON** @ `0x0200E000`: Monitor interface (stub)
- [ ] **4.10** **P_BRIGHTNESS** @ `0x02010000`: Display brightness (stub)
- [ ] **4.11** **P_BMAP** @ `0x020C0000`: BMAP control (stub)
- [ ] **4.12** **P_SID** @ `0x0200C800`: Slot ID (return 0)
- [ ] **4.13** DMA CSRs (`0x02000010`, `0x02000040`, etc.): Return DMACSR_COMPLETE for all, accept writes

---

## Phase 5: Kernel Image Loading

- [ ] **5.1** Cross-compile the NeXTMach kernel for 68040:
  - Need m68k-elf-gcc or similar cross-compiler
  - Kernel expects to be linked at `0x04000000` (`RELOC=04000000`)
  - Compile with `-m68040` flag
  - Output: raw binary or a.out format
- [ ] **5.2** Convert kernel binary to C header (`next_kernel.h`) using xxd, same approach as `rom_image.h`
- [ ] **5.3** Load kernel image into emulated RAM at `0x04000000` during boot init
- [ ] **5.4** Set vector table: SSP from kernel image offset 0, PC from offset 4

**Alternative**: If cross-compilation is complex, find a prebuilt NeXTSTEP kernel image (e.g. from NeXTSTEP 3.3 install media) and load it directly.

---

## Phase 6: FPU Integration for 68040LC

- [ ] **6.1** Add 68040-only FPU opcodes to `fline_handler.c` (from existing plan Step 7):
  - FSMOVE/FDMOVE, FSSQRT/FDSQRT, FSABS/FDABS, FSNEG/FDNEG
  - FSDIV/FDDIV, FSADD/FDADD, FSMUL/FDMUL, FSSUB/FDSUB
  - Map to existing FPOP_* hardware operations (extended precision internally)
- [ ] **6.2** Verify FSAVE/FRESTORE work for 68040 frame format:
  - 68040 NULL frame = 4 bytes (vs 68881 28 bytes)
  - 68040 idle frame = 0x0038 (56 bytes)
  - 68040 busy frame = 0x00D4 (212 bytes)
  - The MC68882 FPGA returns 68882 frame format — may need a translation shim
- [ ] **6.3** Handle `frestore` of 68040 NULL frame at boot (locore.s line ~190 does `frestore` to reset FPU)

---

## Phase 7: Boot Sequence Debugging

- [ ] **7.1** Add UART trace output at key emulation points:
  - Memory reads from I/O space (`0x02xxxxxx`) — log unhandled addresses
  - Exception vectors taken (bus error, address error, illegal instruction)
  - PC trace every N instructions for debugging hangs
- [ ] **7.2** Verify `NeXT_init()` is reached:
  - locore.s calls `jsr _NeXT_init` with parameters
  - Should see SCR1 read at `0x0200C000` early
- [ ] **7.3** Verify BSS zeroing doesn't overwrite our ROM monitor stub
- [ ] **7.4** Watch for MMU setup:
  - locore.s writes TT0/TT1 and TC registers via `movc`
  - With PMMU off, these are absorbed by Musashi — verify no crash
  - If kernel requires MMU translation to continue, will need to enable `M68K_EMULATE_PMMU` and set up a flat identity page table
- [ ] **7.5** Watch for `configure()` device probing — will probe SCSI, ethernet, etc. Unhandled reads should return 0 (device not present) rather than crashing.

---

## Phase 8: Console Output Verification

- [ ] **8.1** If serial console (`CONS_O_SCC_A`): SCC TX data bytes appear on ARM UART
- [ ] **8.2** If bitmap console (`CONS_O_BITMAP`): km driver writes to `0x0B000000` video RAM — need video RAM mapped and optionally routed to DisplayPort framebuffer
- [ ] **8.3** Look for kernel boot messages:
  - `"Mach Operating System"` or similar banner
  - Machine type identification
  - Memory probe results
  - Device autoconfiguration messages

---

## Phase 9: MMU (If Required)

The kernel may not proceed past `NeXT_init()` without a working MMU. If it hangs:

- [ ] **9.1** Enable `M68K_EMULATE_PMMU = M68K_OPT_ON` in `m68kconf.h`
- [ ] **9.2** Pre-build a flat identity-mapped page table in emulated RAM:
  - 68040 uses 3-level page tables (root → pointer → page)
  - Map `0x00000000-0x0FFFFFFF` as identity (1:1 physical = virtual)
  - Set URP/SRP to point to root table
- [ ] **9.3** Alternatively: let the kernel build its own page tables (it does this in `pmap_bootstrap()`) but ensure the RAM it writes to is accessible

---

## Dependency Order

```
Phase 1 (Musashi 040) ─┐
Phase 2 (Memory map)   ─┼─► Phase 5 (Kernel load) ─► Phase 7 (Debug boot)
Phase 3 (ROM monitor)  ─┤                                    │
Phase 4 (HW stubs)     ─┘                                    ▼
Phase 6 (FPU 040)      ─────────────────────► Phase 8 (Console output)
                                                              │
                                              Phase 9 (MMU, if needed)
```

Phases 1-4 can be developed in parallel. Phase 5 depends on having a kernel binary. Phase 6 is independent. Phase 7-9 are iterative debugging.

---

## Known Risks

1. **Kernel compilation**: The mk-108.1 source is from 1990. May not compile with modern m68k-elf-gcc without patches. Alternative: use a prebuilt NeXTSTEP 3.3 kernel binary.
2. **MMU dependency**: The kernel likely requires working 68040 MMU translation. Musashi's PMMU emulation may need to be enabled and verified.
3. **Device probing**: `configure()` probes many devices. Any probe that does a bus timeout (not just read-0) may require bus error exception support in Musashi.
4. **DMA complexity**: The kernel initializes DMA channels. If DMA CSR reads don't return expected values, init may hang.
5. **Frame format mismatch**: The kernel's `frestore`/`fsave` expect 68040 FPU frame formats. The MC68882 FPGA returns 68882 frames. A translation layer may be needed.
