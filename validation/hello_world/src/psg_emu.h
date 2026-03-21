/*
 * psg_emu.h
 * Minimal YM2149 PSG emulation — only register 14 (Port A) for
 * drive/side select used by the Atari ST floppy subsystem.
 *
 * Register map:
 *   $FF8800 (write): register select (value & 0x0F)
 *   $FF8802 (read/write): register data
 */

#ifndef PSG_EMU_H
#define PSG_EMU_H

#include <stdint.h>

/* PSG address range in 68K address space */
#define PSG_BASE  0xFF8800
#define PSG_SIZE  0x04

/* Fast inline range check */
static inline int is_psg(unsigned int addr)
{
    return (addr >= PSG_BASE) && (addr < PSG_BASE + PSG_SIZE);
}

/* Initialise PSG state */
void psg_init(void);

/* Read a byte from PSG register space.
 * offset = address - PSG_BASE (0x00..0x03) */
uint8_t psg_read(uint32_t offset);

/* Write a byte to PSG register space.
 * offset = address - PSG_BASE (0x00..0x03) */
void psg_write(uint32_t offset, uint8_t value);

/* Get currently selected drive: 0=A, 1=B, -1=none */
int psg_get_drive(void);

/* Get currently selected side: 0 or 1 */
int psg_get_side(void);

#endif /* PSG_EMU_H */
