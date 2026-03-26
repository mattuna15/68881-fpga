/*
 * next_devs.h
 * NeXT hardware device emulation stubs.
 *
 * Provides minimal emulation of NeXT system registers, SCC serial,
 * timer, and interrupt controller — enough to boot the Mach kernel
 * to console output.
 */

#ifndef NEXT_DEVS_H
#define NEXT_DEVS_H

#include <stdint.h>

/* Initialise all NeXT device stubs */
void next_devs_init(void);

/* SCC serial: push a byte into the RX buffer (from ARM UART) */
int next_scc_rx_push(uint8_t ch);

/* Timer: advance by the given number of emulated CPU cycles.
 * Returns 1 if the timer interrupt should fire. */
int next_timer_tick(int cycles);

/* Interrupt controller: compute highest pending IPL (0-7).
 * Call after timer_tick or any device state change. */
int next_intr_pending_ipl(void);

/* Interrupt acknowledge: called from Musashi int-ack callback.
 * Returns autovector number or -1 if spurious. */
int next_intr_acknowledge(int level);

/* I/O read/write handlers — called from memory dispatch */
uint8_t  next_io_read_8(uint32_t address);
uint16_t next_io_read_16(uint32_t address);
uint32_t next_io_read_32(uint32_t address);
void     next_io_write_8(uint32_t address, uint8_t value);
void     next_io_write_16(uint32_t address, uint16_t value);
void     next_io_write_32(uint32_t address, uint32_t value);

/* Check if address falls in NeXT I/O space (0x02000000-0x020FFFFF) */
static inline int is_next_io(uint32_t addr)
{
    return (addr >= 0x02000000) && (addr < 0x02100000);
}

#endif /* NEXT_DEVS_H */
