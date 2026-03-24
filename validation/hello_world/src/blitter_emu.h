/*
 * blitter_emu.h
 * Atari ST Blitter chip emulation ($FF8A00-$FF8A3D).
 *
 * DMA-based raster engine that copies/combines rectangular blocks
 * of 16-bit words between source and destination in emu_ram[].
 */

#ifndef BLITTER_EMU_H
#define BLITTER_EMU_H

#include <stdint.h>

/* Blitter register range in 68K address space */
#define BLITTER_BASE  0xFF8A00
#define BLITTER_SIZE  0x3E     /* $FF8A00-$FF8A3D */

/* Fast inline range check */
static inline int is_blitter(unsigned int addr)
{
    return (addr >= BLITTER_BASE) && (addr < BLITTER_BASE + BLITTER_SIZE);
}

/* Initialise blitter state (call once at startup) */
void blitter_init(void);

/* Read a byte from blitter register space.
 * offset = address - BLITTER_BASE (0x00..0x3D) */
uint8_t blitter_read(uint32_t offset);

/* Write a byte to blitter register space.
 * offset = address - BLITTER_BASE (0x00..0x3D) */
void blitter_write(uint32_t offset, uint8_t value);

#endif /* BLITTER_EMU_H */
