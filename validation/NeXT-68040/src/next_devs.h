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

/* Check if address falls in NeXT I/O space.
 * The 68040 ROM uses SLOT_ID_BMAP which shifts device registers.
 * Before BMAP config: offset=0x100000 (0x020xxxxx → 0x021xxxxx)
 * After BMAP config:  offset=0x200000 (0x020xxxxx → 0x022xxxxx)
 * Accept the full range 0x02000000 - 0x022FFFFF. */
static inline int is_next_io(uint32_t addr)
{
    return (addr >= 0x02000000) && (addr < 0x02300000);
}

/* Normalise a NeXT I/O address: strip the SLOT_ID_BMAP offset so that
 * 0x021xxxxx / 0x022xxxxx addresses map back to canonical 0x020xxxxx. */
static inline uint32_t next_io_canon(uint32_t addr)
{
    if (addr >= 0x02200000 && addr < 0x02300000)
        return addr - 0x00200000;
    if (addr >= 0x02100000 && addr < 0x02200000)
        return addr - 0x00100000;
    return addr;
}

/* Get the ROM's mon_global pointer (written to P_MON during boot) */
uint32_t next_get_mon_global(void);

#endif /* NEXT_DEVS_H */
