# NeXT 68040LC Emulator — Defect / TODO Checklist

Tracked issues for the NeXT 68040LC system emulator (`validation/NeXT-68040/`).

## Open — High Priority

- [ ] **FPU FSAVE/FRESTORE frame translation** — Turbo ROM POST expects 68040 FPU
  frames; MC68882 returns 68882 frames. Currently `fline_init()` is disabled as
  workaround. Need to translate frame formats in `fline_handler.c`.
  Files: `main.c`, `fline_handler.c`

- [ ] **MCS1850 RTC protocol** — New clock chip inverts RTC_WRITE bit (bit 7=1 for
  reads, 0 for writes). ROM switches to new protocol after detecting RTC_NEW_CLOCK
  in STATUS register. Our emulator only handles old protocol. Causes NVRAM corruption
  on write-back (ROM rewrites NVRAM with ni_new_clock_chip=1 using new protocol,
  emulator misinterprets as write). Manifests as SIMM config warning and stale NVRAM.
  Files: `next_rtc.c`

- [ ] **Animation loop workaround** — ROM gets stuck in event/animation loop at
  `$010024E2` after POST. Currently forced out by setting D3=0 on keystroke in
  instruction hook. Root cause: animation timer interrupts not implemented.
  Files: `main.c`

## Open — Medium Priority

- [ ] **Add throttled logging for unknown 8-bit/16-bit I/O reads** — Currently
  silent (return 0). 32-bit path logs first 20. Align all paths for boot debugging.
  Files: `next_devs.c`

- [ ] **Add throttled logging for unknown I/O writes** — All write paths silent
  (behind `NEXT_IO_DEBUG`). At minimum 32-bit path should log unconditionally.
  Files: `next_devs.c`

- [ ] **Add throttled logging for unmapped memory accesses** — Reads return 0,
  writes are ignored, both silent. Makes kernel debugging very difficult.
  Files: `next_memory.c`

- [ ] **RTC protocol watchdog/timeout** — If bit-bang protocol gets out of sync,
  state machine stays in ADDR_PHASE or DATA_PHASE indefinitely with no diagnostic.
  Add cycle counter and reset to IDLE after timeout.
  Files: `next_rtc.c`

- [ ] **Log incomplete RTC transactions** — When CE drops mid-byte (bit_count != 0
  and != 8), log a warning. Currently silently resets to IDLE.
  Files: `next_rtc.c`

- [ ] **SCC 16-bit read side-effects** — Decomposing 16-bit reads to two
  `next_io_read_8` calls causes `scc_wr_reg_ptr` side-effect from first byte to
  affect second byte. Low risk (ROM uses byte access), but incorrect emulation.
  Files: `next_devs.c`

- [ ] **`next_scc_rx_pop()` returns 0 on empty** — Indistinguishable from NUL byte.
  Document that callers must check `next_scc_rx_available()` first, or add assertion.
  Files: `next_devs.c`

- [ ] **Log unmapped KMS characters** — `next_kms_push_ascii()` silently ignores
  characters with no NeXT keycode mapping. Throttled warning would help debugging.
  Files: `next_kms.c`

- [ ] **Log KMS write commands** — `next_kms_write()` is a complete no-op. ROM sends
  MON_KM_POLL and other commands that are silently discarded.
  Files: `next_kms.c`

## Open — Low Priority

- [ ] **Stuck-PC detection disabled** — `#if 0` in main.c emulation loop. Consider
  re-enabling behind a runtime flag for hung emulation diagnosis.
  Files: `main.c`

- [ ] **DSP `next_dsp_write32` fragile for non-zero offsets** — Byte decomposition
  logic at offset != 0 may write to ISR (offset 2) via default case. Low risk since
  ROM only does 32-bit writes at offset 0 or 4.
  Files: `next_dsp.c`

- [ ] **RTC counter epoch** — Using fixed `NEXT_EPOCH_DEFAULT` (3,913,401,600)
  instead of ZynqMP PS RTC. Correct for boot but not for real-time clock display.
  Files: `next_rtc.c`

- [ ] **USB HID keyboard** — Currently keyboard input via serial UART only. The
  hello_world project has a working USB HID driver (`usb_hid.c`) that could be
  integrated for direct USB keyboard support.
  Files: `main.c`, `next_kms.c`

## Fixed

- [x] **FPU blink error loop** — Disabled `fline_init()` (2026-03-29). b00dd53
- [x] **RTC counter calibration failure** — Fixed epoch value. b00dd53
- [x] **KMS keyboard emulation** — Added KMS chip emulation at P_MON. 26403f9
- [x] **Video guard for screen dimensions** — Compile-time `#if` guard. 5f19dcb
- [x] **KMS key-up events** — Push down+up pair per keystroke. 5f19dcb
- [x] **DSP ISR write handler** — Added missing `case 2: break`. 5f19dcb
- [x] **KMS queue overflow warning** — Throttled log on full queue. 5f19dcb
- [x] **SCC RX overflow warning** — Throttled log on full buffer. 5f19dcb
