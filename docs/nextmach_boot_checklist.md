# NeXTMach Kernel Boot on Musashi 68040LC — Checklist

## Context

Boot the NeXT Turbo ROM (Rev 3.3 v74) and eventually a NeXTMach Mach kernel
on the Musashi emulator configured as a 68LC040 (no internal FPU). The
hardware MC68881/68882 FPGA handles FPU instructions via F-line trapping
with FSAVE/FRESTORE frame translation (68881/68882 ↔ 68040).

**Current status**: ROM monitor boots on both QEMU and ZynqMP hardware.
Interactive `NeXT>` prompt with keyboard input via KMS emulation. Hardware
FPU verified (42 × 42 = 1764). See `validation/NeXT-68040/README.md`.

---

## Key Reference Files

| Area | File |
|------|------|
| Emulator main | `validation/NeXT-68040/src/main.c` |
| Memory map | `validation/NeXT-68040/src/next_memory.c` |
| Device stubs | `validation/NeXT-68040/src/next_devs.c` |
| RTC/NVRAM | `validation/NeXT-68040/src/next_rtc.c` |
| KMS keyboard | `validation/NeXT-68040/src/next_kms.c` |
| DSP stub | `validation/NeXT-68040/src/next_dsp.c` |
| FPU F-line | `validation/NeXT-68040/src/fline_handler.c` |
| Video output | `validation/NeXT-68040/src/next_video.c` |
| Mon stub | `validation/NeXT-68040/src/next_mon_stub.c` |
| HW addresses | `validation/NeXT-68040/src/next_hw.h` |
| Kernel entry | `NeXTMach/mk-108.1/next/locore.s` |
| Early init | `NeXTMach/mk-108.1/next/next_init.c` |
| ROM monitor API | `NeXTMach/mk-108.1/mon/global.h` |
| HW addresses | `NeXTMach/mk-108.1/next/cpu.h` |
| SCR registers | `NeXTMach/mk-108.1/next/scr.h` |
| KMS keyboard | `NeXTMach/mk-108.1/nextdev/km.c`, `kmreg.h`, `keycodes.h` |
| KMS registers | `NeXTMach/mk-108.1/nextdev/monreg.h` |
| Serial console | `NeXTMach/mk-108.1/nextdev/zs.c` |
| Bitmap console | `NeXTMach/mk-108.1/nextdev/km.c` |
| Timer/clock | `NeXTMach/mk-108.1/next/clock.c` |
| Event counter | `NeXTMach/mk-108.1/next/eventc.h` |
| ROM boot code | `NeXTMach/mk-108.1/stand/boot.c` |
| ROM diagnostics | `NeXTMach/mk-108.1/stand/diagnostics.c` |

---

## Phase 1: Musashi 68040LC Configuration — COMPLETE

- [x] **1.1** Enable 68040 in `m68kconf.h`: `M68K_EMULATE_040 = M68K_OPT_ON`
- [x] **1.2** Fixed Musashi `CPU_ADDRESS_MASK` for LC040 (was missing, left at 24-bit)
- [x] **1.3** Fixed Musashi `CPU_TYPE_IS_xxx_PLUS` macros (LC040 was missing from all bitmasks)
- [x] **1.4** Set `m68k_set_cpu_type(M68K_CPU_TYPE_68LC040)` in `main.c`
- [x] **1.5** F-line callback routes FPU instructions to external MC68882 FPGA hardware

---

## Phase 2: Memory Map — COMPLETE

| Range | Size | Description |
|-------|------|-------------|
| `0x00000000` | 128 KB | EPROM (ROM at both $00000000 and $01000000 BMAP mirror) |
| `0x02000000` | 3 MB | I/O space ($020xxxxx, $021xxxxx, $022xxxxx with BMAP remap) |
| `0x04000000` | 16 MB | Main RAM |
| `0x0B000000` | 256 KB | VRAM (non-Turbo layout, stride 288 bytes/line) |
| bit 31 mirror | — | All addresses masked via `addr_normalise()` |

- [x] **2.1** 32-bit address space with `next_memory.c` (RAM/ROM/VRAM/I/O dispatch)
- [x] **2.2** SLOT_ID_BMAP remapping via `next_io_canon()` ($021xxxxx → $020xxxxx)
- [x] **2.3** Bit 31 stripping for 68040 TT identity mapping ($8xxxxxxx → $0xxxxxxx)

---

## Phase 3: ROM Boot — COMPLETE

Using Turbo ROM (Rev 3.3 v74, 128 KB) instead of kernel direct load.

- [x] **3.1** ROM loaded at $00000000 with BMAP mirror at $01000000
- [x] **3.2** ROM vectors: SSP=$04000400, PC=$0100001E
- [x] **3.3** `mon_global` stub built at $04008000 (used as fallback; ROM builds its own at $0B03F800)
- [x] **3.4** ROM auto-discovers `mg_putc=$010081C8`, `mg_getc=$01008140`

---

## Phase 4: NeXT Hardware Register Stubs — COMPLETE

- [x] **4.1** **P_SCR1** — machine type NeXT_WARP9, 25 MHz, board rev 0
- [x] **4.2** **P_SCR2** — read/write, EKG LED, DRAM banks, RTC bit-bang
- [x] **4.3** **P_INTRMASK / P_INTRSTAT** — interrupt controller
- [x] **4.4** **P_SCC** — Zilog 8530 channel A serial (TX→ARM UART, RX buffered)
- [x] **4.5** **P_TIMER / P_TIMER_CSR** — 16-bit timer at 1 MHz
- [x] **4.6** **P_EVENTC** — 20-bit microsecond counter with latch mechanism
- [x] **4.7** **P_MON / KMS** — keyboard/mouse/sound chip emulation at $0200E000
- [x] **4.8** **P_BRIGHTNESS** — returns max (0x3D)
- [x] **4.9** **P_BMAP** — accepts writes, reads return 0
- [x] **4.10** **P_SID** — slot ID returns 0
- [x] **4.11** **DMA CSRs** — 12 channels, return DMACSR_COMPLETE
- [x] **4.12** **DSP56001** — host interface stub (ICR/CVR/ISR/IVR + 4K memory)

---

## Phase 5: RTC/NVRAM — COMPLETE

- [x] **5.1** MC68HC68T1/MCS1850 bit-bang protocol via SCR2 (RTCE/RTCLK/RTDATA)
- [x] **5.2** NVRAM defaults from Previous emulator (32 bytes with checksum)
- [x] **5.3** RTC counter: fixed epoch (NEXT_EPOCH_DEFAULT) — ZynqMP PS RTC caused calibration failure
- [x] **5.4** ROM reads NVRAM, verifies checksum, writes back with ni_new_clock_chip

**Known issue**: MCS1850 protocol (bit 7 inversion for new clock chip) not yet implemented. ROM's NVRAM write-back using new protocol corrupts data. Tracked in `docs/next68040_defect_checklist.md`.

---

## Phase 6: FPU Integration — COMPLETE

- [x] **6.1** F-line handler routes all 68881 FPU opcodes to hardware FPGA
- [x] **6.2** FSAVE/FRESTORE frame translation (68881/68882 ↔ 68040):
  - NULL ($0000) → 68040 NULL ($00000000)
  - IDLE ($0018/$0038) → 68040 IDLE ($40000000)
  - BUSY ($00B4/$00D4) → 68040 IDLE (safe fallback)
  - 68040 IDLE/UNIMP/BUSY → 68882 NULL (reset FPU)
- [x] **6.3** ROM POST passes with hardware FPU enabled
- [x] **6.4** Verified: FMOVE.L #42,FP0 / FMUL.X FP0,FP0 / FMOVE.L FP0,D0 → D0=$6E4 (1764)
- [ ] **6.5** 68040-only opcodes (FSMOVE/FDMOVE etc.) — not yet needed, ROM uses 68881 set

---

## Phase 7: ROM Monitor — COMPLETE

- [x] **7.1** ROM boots through POST on both QEMU and ZynqMP hardware
- [x] **7.2** Display output: NeXT 2bpp VRAM → 1920x1080 DisplayPort
- [x] **7.3** ROM displays "System test failed" + boot messages on bitmap console
- [x] **7.4** `mg_putc` hook mirrors bitmap console output to ARM UART
- [x] **7.5** Interactive `NeXT>` prompt with full command set (p, e, d, r, s, b, c, etc.)
- [x] **7.6** KMS keyboard emulation: UART RX → ASCII→NeXT keycode → keyboard events at $0200E000
- [x] **7.7** Animation loop workaround: D3=0 force on keystroke at $010024E8

---

## Phase 8: Kernel Boot — NOT STARTED

- [ ] **8.1** Obtain or build a NeXTSTEP kernel image (Mach kernel binary)
- [ ] **8.2** Load kernel via ROM `b` command or direct memory load
- [ ] **8.3** Implement additional hardware stubs as kernel probes them
- [ ] **8.4** Handle MMU setup (Musashi PMMU or identity mapping)
- [ ] **8.5** Watch for kernel console output ("Mach Operating System" banner)
- [ ] **8.6** Handle `configure()` device probing (SCSI, ethernet, etc.)

---

## Hardware-Specific Fixes (QEMU worked, hardware needed these)

| Issue | Root Cause | Fix |
|-------|-----------|-----|
| FPU blink error loop | ROM POST FSAVE got 68882 frames, expected 68040 | Frame translation in fline_handler.c |
| Timing calibration error 4 | ZynqMP PS RTC returned wrong counter value | Fixed epoch (NEXT_EPOCH_DEFAULT) |
| Post-RTC stuck loop | Animation timer interrupts not implemented | D3=0 force on keystroke |

---

## Known Risks for Kernel Boot

1. **MMU dependency**: Kernel requires working 68040 MMU. Musashi PMMU may need enabling.
2. **Device probing**: `configure()` probes SCSI, ethernet, etc. May need bus error support.
3. **DMA**: Kernel initializes DMA channels. Current stubs may be insufficient.
4. **MCS1850 protocol**: NVRAM write-back corruption may affect kernel configuration.
5. **Interrupt delivery**: Timer/VBL interrupts needed for kernel scheduling.
