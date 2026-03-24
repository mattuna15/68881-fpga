# RTC + Timer C Interrupt — Design Spec

## Context
The Merlin 2 emulator runs on an Alinx AXU3EG board (ZynqMP XCZU3EG) which has
a built-in PS RTC at `0xFFA60000` with battery backup. The M68K emulator
currently has a millisecond tick counter but no real-time clock or periodic
interrupt support. This adds wall-clock time access and a configurable Timer C
interrupt matching the MC68901 MFP convention.

## TRAP #15 Functions (3 new)

| TRAP D0 | Name | Parameters | Returns |
|---------|------|-----------|---------|
| 22 | GET_RTC | — | D1.L = Unix timestamp (seconds since 1970-01-01) |
| 23 | GET_DATETIME | — | D1.L = YYYYMMDD (BCD), D2.L = HHMMSSwd (BCD, wd=weekday 0=Sun) |
| 24 | SET_RTC | D1.L = Unix timestamp | — |

## MFP I/O Extensions

Extend the emulated MFP register space from 0x34 to 0x40 bytes:

| Offset | Size | R/W | Purpose |
|--------|------|-----|---------|
| 0x30-0x33 | 4 | R | Millisecond tick counter (existing) |
| 0x34-0x37 | 4 | R/W | RTC: read = current Unix seconds, write = set time |
| 0x38-0x3F | 8 | R | BCD datetime: bytes 0-3 = YYYYMMDD, bytes 4-7 = HHMMSSwd |

The emulator reads the ZynqMP PS RTC register `XRTC_CUR_TIME` (base + 0x10) on
every MFP_OFF_RTC read, and writes `XRTC_SET_TIME_WR` (base + 0x00) on write.
The BCD conversion from Unix epoch is done on the ARM side in `mfp_emu.c`.

## Timer C Periodic Interrupt

### Configuration
The BIOS already writes MFP Timer C/D control register (TCDCR at offset 0x1D)
and Timer C data register (TCDR at offset 0x23). Currently the emulator ignores
these. This change makes them functional for Timer C.

TCDCR bits 6-4 select the Timer C prescaler:

| Value | Prescaler | Value | Prescaler |
|-------|-----------|-------|-----------|
| 0 | Stopped | 4 | /50 |
| 1 | /4 | 5 | /64 |
| 2 | /10 | 6 | /100 |
| 3 | /16 | 7 | /200 |

TCDR holds the counter reload value (1-255).

Timer tick rate = MFP_XTAL / prescaler / counter_value, where MFP_XTAL =
2.4576 MHz (standard MC68901 crystal frequency).

### Interrupt delivery
- Timer C fires autovectored IPL 6 interrupt at vector 70 (address 0x118).
- Emulator tracks elapsed M68K cycles in the main emulation loop.
- Timer C period in CPU cycles = (prescaler * counter * CPU_CLOCK) / MFP_XTAL.
- At 33 MHz CPU, default config (prescaler /200, counter 192): period = 33e6 *
  200 * 192 / 2457600 = ~515,625 cycles ≈ 26ms ≈ 38 Hz.
- On expiry: `m68k_set_irq(6)`, handler executes, `RTE` returns.
- Interrupt acknowledged by reading the interrupt-in-service register or by
  the handler completing (autovector mode).

### Default BIOS setup
- BIOS installs Timer C handler at vector 70 during init.
- Default handler increments a 32-bit system tick counter at a known RAM address.
- Timer C enabled at ~38 Hz (TCDCR prescaler /200, TCDR = 192).
- Programs can replace the vector 70 handler for custom periodic callbacks.

## Emulator Changes

### mfp_emu.h
- `MFP_SIZE` from 0x34 to 0x40.
- New offsets: `MFP_OFF_RTC` (0x34), `MFP_OFF_DATETIME` (0x38).
- Timer C state: `tc_prescaler`, `tc_reload`, `tc_cycle_count`, `tc_period`,
  `tc_enabled` fields.
- `mfp_timer_tick(uint32_t cycles_elapsed)` — call from main loop to advance
  Timer C and return 1 if interrupt should fire.

### mfp_emu.c
- RTC read: `Xil_In32(XRTC_BASEADDR + XRTC_CUR_TIME_OFFSET)`.
- RTC write: `Xil_Out32(XRTC_BASEADDR + XRTC_SET_TIME_WR_OFFSET, secs)`.
- BCD datetime conversion: standard epoch arithmetic (days since 1970,
  leap year handling, month table lookup) producing packed BCD bytes.
- Timer C: on write to TCDCR, extract bits 6-4, look up prescaler, recompute
  `tc_period`. On write to TCDR, update `tc_reload` and recompute.
  `mfp_timer_tick()` subtracts elapsed cycles from accumulator, fires when
  it reaches zero and reloads.

### main.c
- After each `m68k_execute(EMU_CYCLES_PER_TICK)`, call
  `mfp_timer_tick(EMU_CYCLES_PER_TICK)`.
- If it returns 1, call `m68k_set_irq(6)`.
- Clear IRQ after Musashi acknowledges it (callback or next execute cycle).

## BIOS Changes (bios.s)

### TRAP #15 handlers
- `.io22`: Read 4 bytes from `MFP_OFF_RTC` into D1.L. Return via `.ioExcEnd`.
- `.io23`: Read 8 bytes from `MFP_OFF_DATETIME` into D1.L and D2.L. Return.
- `.io24`: Write D1.L to `MFP_OFF_RTC`. Return.

### Timer C interrupt
- During init (`WARMSTART`), install handler address at vector 70 (`0x118`).
- Default handler:
  ```
  timer_c_handler:
      ADDQ.L  #1,TIMER_TICK    ; increment system tick counter
      RTE
  ```
- `TIMER_TICK` allocated in BIOS workspace (low RAM, e.g. offset in SAVED area).
- Optional: add TRAP #15 D0=25 `GET_TICKS` returning the tick counter in D1.L.

### Boot message
- On startup, read RTC and print: `RTC: 2026-03-19 14:30:00`
- If RTC reads 0 (never set), print: `RTC: not set`

## Toolchain Library

### New file: `toolchain/lib/merlin2_rtc.h`
```c
#ifndef MERLIN2_RTC_H
#define MERLIN2_RTC_H
#include <stdint.h>

typedef struct {
    uint16_t year;
    uint8_t month, day, hour, min, sec, weekday;
} rtc_datetime_t;

uint32_t rtc_get_time(void);
void rtc_get_datetime(rtc_datetime_t *dt);
void rtc_set_time(uint32_t unix_secs);
uint32_t rtc_get_ticks(void);
#endif
```

### New file: `toolchain/lib/merlin2_rtc.c`
- TRAP #15 wrappers (same pattern as `merlin2_gfx.c`).
- `rtc_get_datetime()` calls TRAP D0=23, unpacks BCD D1.L/D2.L into struct.

### merlin2.h updates
- Add `MERLIN2_TRAP_GET_RTC (22)`, `MERLIN2_TRAP_GET_DATETIME (23)`,
  `MERLIN2_TRAP_SET_RTC (24)`, `MERLIN2_TRAP_GET_TICKS (25)`.

## Verification
- BIOS prints RTC date/time on boot.
- `SET_RTC` via serial command or test program persists across soft reset.
- Timer C interrupt fires at ~38 Hz (verify by printing tick counter).
- Timer C can be reconfigured (change TCDCR/TCDR, observe new rate).
- GET_DATETIME returns correct BCD for known timestamps.
- GET_TICKS increments steadily.

## Files Modified
- `validation/hello_world/src/mfp_emu.h` — new offsets, timer state, MFP_SIZE
- `validation/hello_world/src/mfp_emu.c` — RTC access, BCD conversion, Timer C logic
- `validation/hello_world/src/main.c` — timer tick call in emulation loop, IRQ
- `validation/hello_world/src/roms/bios.s` — TRAP handlers, Timer C vector, boot message
- `validation/hello_world/src/rom_image.h` — regenerated after bios.s changes
- `toolchain/lib/merlin2_rtc.h` — new RTC library header
- `toolchain/lib/merlin2_rtc.c` — new RTC library source
- `toolchain/merlin2-bsp/merlin2.h` — new TRAP constants
