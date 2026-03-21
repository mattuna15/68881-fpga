/*
 * floppy_emu.h
 * Atari ST floppy DMA controller + WD1772 FDC emulation.
 *
 * DMA register map ($FF8604-$FF860D):
 *   $FF8604-05: DMA data (word) — FDC register or sector count
 *   $FF8606-07: DMA control (word) — selects FDC register, direction
 *   $FF8609:    DMA address high byte
 *   $FF860B:    DMA address mid byte
 *   $FF860D:    DMA address low byte
 */

#ifndef FLOPPY_EMU_H
#define FLOPPY_EMU_H

#include <stdint.h>

/* Floppy DMA address range in 68K address space */
#define FLOPPY_DMA_BASE  0xFF8604
#define FLOPPY_DMA_SIZE  0x0A   /* $FF8604-$FF860D */

/* Maximum .ST image size: 80 tracks * 2 sides * 11 sectors * 512 bytes */
#define ST_IMAGE_MAX_SIZE  (80 * 2 * 11 * 512)

/* Fast inline range check */
static inline int is_floppy_dma(unsigned int addr)
{
    return (addr >= FLOPPY_DMA_BASE) && (addr < FLOPPY_DMA_BASE + FLOPPY_DMA_SIZE);
}

/* Initialise floppy emulation with pointer to .ST image data.
 * image_data: pointer to raw .ST image (NULL if no image loaded)
 * image_size: size in bytes (0 if no image) */
void floppy_init(const uint8_t *image_data, uint32_t image_size);

/* Read a byte from floppy DMA register space.
 * offset = address - FLOPPY_DMA_BASE (0x00..0x09) */
uint8_t floppy_read(uint32_t offset);

/* Write a byte to floppy DMA register space.
 * offset = address - FLOPPY_DMA_BASE (0x00..0x09) */
void floppy_write(uint32_t offset, uint8_t value);

#endif /* FLOPPY_EMU_H */
