/*
 * next_memory.h
 * Memory map for NeXT 68040LC emulator on Musashi.
 *
 * 32-bit address space with sparse mapping:
 *   0x00000000 - 0x0001FFFF : EPROM (128 KB, read-only, mirrors 0x01000000)
 *   0x01000000 - 0x0101FFFF : EPROM BMAP (128 KB, read-only, 68040 address)
 *   0x02000000 - 0x020FFFFF : Device I/O space
 *   0x04000000 - 0x04FFFFFF : Main RAM (16 MB, kernel + data)
 *   0x0B000000 - 0x0B03FFFF : Video RAM (256 KB)
 *
 * Unmapped addresses return 0 (no bus error emulation).
 */

#ifndef NEXT_MEMORY_H
#define NEXT_MEMORY_H

#include "musashi/m68k.h"
#include "xil_printf.h"
#include <stdint.h>

/* Main RAM: 16 MB at 0x04000000 */
#define NEXT_RAM_BASE   0x04000000
#define NEXT_RAM_SIZE   (16 * 1024 * 1024)

/* EPROM: 128 KB at 0x00000000, also mirrored at 0x01000000 (BMAP) */
#define NEXT_ROM_BASE   0x00000000
#define NEXT_ROM_BMAP   0x01000000
#define NEXT_ROM_SIZE   (128 * 1024)

/* Video RAM: 256 KB
 * Non-Turbo: 0x0B000000    Turbo: 0x0C000000
 * The Turbo ROM (Rev 3.3 v74) writes display data to 0x0C000000.
 * We map both ranges to the same backing buffer. */
#define NEXT_VRAM_BASE       0x0B000000
#define NEXT_VRAM_TURBO_BASE 0x0C000000
#define NEXT_VRAM_SIZE       (256 * 1024)

/* The emulated RAM buffer (lives in DDR on the ZU3EG) */
extern unsigned char next_ram[];
extern unsigned char next_rom[];
extern unsigned char next_vram[];

/* Clear all emulated memory */
void next_mem_init(void);

/* Load data into main RAM at physical address.
 * addr must be >= NEXT_RAM_BASE. Returns 0 on success. */
int next_mem_load(uint32_t addr, const uint8_t *data, uint32_t len);

/* Load data into EPROM at offset 0. Returns 0 on success. */
int next_rom_load(const uint8_t *data, uint32_t len);

/* Set up exception vectors in EPROM (SSP at 0x0, PC at 0x4).
 * Used for initial boot: Musashi reads vectors from address 0. */
void next_mem_set_vectors(uint32_t ssp, uint32_t pc);

/* Musashi memory callbacks (declared here, defined in next_memory.c) */
unsigned int m68k_read_memory_8(unsigned int address);
unsigned int m68k_read_memory_16(unsigned int address);
unsigned int m68k_read_memory_32(unsigned int address);
void         m68k_write_memory_8(unsigned int address, unsigned int value);
void         m68k_write_memory_16(unsigned int address, unsigned int value);
void         m68k_write_memory_32(unsigned int address, unsigned int value);

/* Physical memory read — bypasses MMU translation.
 * Used by the 68040 page table walker to read descriptors. */
static inline uint32_t next_phys_read_32(uint32_t addr)
{
    addr &= 0x7FFFFFFF;  /* strip TT bit 31 */
    if (addr >= NEXT_RAM_BASE && addr < NEXT_RAM_BASE + NEXT_RAM_SIZE) {
        uint32_t off = addr - NEXT_RAM_BASE;
        return ((uint32_t)next_ram[off] << 24) |
               ((uint32_t)next_ram[off+1] << 16) |
               ((uint32_t)next_ram[off+2] << 8) |
                (uint32_t)next_ram[off+3];
    }
    if (addr < NEXT_ROM_SIZE) {
        return ((uint32_t)next_rom[addr] << 24) |
               ((uint32_t)next_rom[addr+1] << 16) |
               ((uint32_t)next_rom[addr+2] << 8) |
                (uint32_t)next_rom[addr+3];
    }
    /* Unmapped address — log first few occurrences to aid debugging */
    {
        static int unmapped_log = 0;
        if (unmapped_log < 10) {
            xil_printf("[PHYS] WARNING: read from unmapped $%08X\r\n", addr);
            unmapped_log++;
        }
    }
    return 0;
}

/* VRAM dirty tracking for display refresh */
int  next_vram_is_dirty(void);
void next_vram_mark_clean(void);

/* Per-scanline dirty bitmap: copies 26 uint32_t words (832 bits) to out,
 * then clears internal bitmap. Each bit = one scanline. */
void next_vram_get_dirty_lines(uint32_t *out);

/* Mark all scanlines dirty (e.g. first render) */
void next_vram_mark_all_dirty(void);

#endif /* NEXT_MEMORY_H */
