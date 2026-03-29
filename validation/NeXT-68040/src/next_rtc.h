/*
 * next_rtc.h
 * MC68HC68T1 / MCS1850 RTC emulation for NeXT 68040LC emulator.
 *
 * The NeXT ROM communicates with the RTC chip via a serial bit-bang
 * protocol on SCR2 (RTCE, RTCLK, RTDATA).  This module intercepts
 * SCR2 reads and writes to emulate the RTC.
 *
 * Backend:
 *   QEMU_MODE  — software free-running seconds counter
 *   Hardware   — ZynqMP PS RTC at 0xFFA60000
 */

#ifndef NEXT_RTC_H
#define NEXT_RTC_H

#include <stdint.h>

/* Initialise the RTC subsystem.
 * On hardware: calibrates the ZynqMP PS RTC.
 * On QEMU: sets the software counter to a fixed epoch. */
void next_rtc_init(void);

/* Call when software writes to SCR2.  Tracks RTCE/RTCLK/RTDATA
 * transitions to implement the serial protocol.
 * old_scr2 is the value BEFORE the write; new_scr2 is the value written. */
void next_rtc_scr2_write(uint32_t new_scr2, uint32_t old_scr2);

/* Call when software reads SCR2.  Returns the value with RTDATA
 * set or cleared depending on the current RTC read-back bit.
 * base_scr2 is the raw SCR2 register value. */
uint32_t next_rtc_scr2_read(uint32_t base_scr2);

/* Advance the software RTC by the given number of emulated CPU cycles.
 * Only meaningful in QEMU_MODE; no-op on hardware. */
void next_rtc_tick(int cycles);

#endif /* NEXT_RTC_H */
