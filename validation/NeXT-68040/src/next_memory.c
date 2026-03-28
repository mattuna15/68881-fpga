/*
 * next_memory.c
 * Musashi memory callbacks for NeXT 68040LC emulator.
 *
 * Sparse 32-bit address map:
 *   EPROM     : 0x00000000 (128 KB, R/O — exception vectors live here)
 *   I/O       : 0x02000000 (1 MB, dispatched to next_devs)
 *   Main RAM  : 0x04000000 (16 MB, R/W — kernel loads here)
 *   Video RAM : 0x0B000000 (256 KB, R/W)
 *   Unmapped  : returns 0, writes ignored
 */

#include "next_memory.h"
#include "next_devs.h"
#include "next_video.h"
#include "xil_printf.h"
#include <string.h>

/* Track VRAM writes for display refresh */
static int vram_dirty;

int next_vram_is_dirty(void)  { return vram_dirty; }
void next_vram_mark_clean(void) { vram_dirty = 0; }

/* ------------------------------------------------------------------ */
/* Static memory arrays (in DDR on the ZU3EG)                          */
/* ------------------------------------------------------------------ */
unsigned char next_ram[NEXT_RAM_SIZE];
unsigned char next_rom[NEXT_ROM_SIZE];
unsigned char next_vram[NEXT_VRAM_SIZE];

/* ------------------------------------------------------------------ */
/* Address normalisation                                               */
/* ------------------------------------------------------------------ */

/* The 68040 ROM uses Transparent Translation (TT) registers to create
 * a 1:1 mapping with caching disabled for the upper 2GB ($80000000+).
 * Since we don't implement the MMU, mask off bit 31 so that addresses
 * like $820C0020 map to $020C0020 (I/O) and $8B000000 maps to
 * $0B000000 (VRAM).  This matches the TT0/TT1 identity mapping. */
static inline uint32_t addr_normalise(uint32_t addr)
{
    return addr & 0x7FFFFFFF;
}

/* ------------------------------------------------------------------ */
/* Address classification helpers                                      */
/* ------------------------------------------------------------------ */

static inline int in_ram(uint32_t addr)
{
    return (addr >= NEXT_RAM_BASE) &&
           (addr < NEXT_RAM_BASE + NEXT_RAM_SIZE);
}

static inline int in_rom(uint32_t addr)
{
    return (addr < NEXT_ROM_SIZE) ||
           (addr >= NEXT_ROM_BMAP && addr < NEXT_ROM_BMAP + NEXT_ROM_SIZE);
}

static inline uint32_t rom_offset(uint32_t addr)
{
    if (addr >= NEXT_ROM_BMAP)
        return addr - NEXT_ROM_BMAP;
    return addr;
}

static inline int in_vram(uint32_t addr)
{
    return ((addr >= NEXT_VRAM_BASE) &&
            (addr < NEXT_VRAM_BASE + NEXT_VRAM_SIZE)) ||
           ((addr >= NEXT_VRAM_TURBO_BASE) &&
            (addr < NEXT_VRAM_TURBO_BASE + NEXT_VRAM_SIZE));
}

static inline uint32_t vram_offset(uint32_t addr)
{
    if (addr >= NEXT_VRAM_TURBO_BASE)
        return addr - NEXT_VRAM_TURBO_BASE;
    return addr - NEXT_VRAM_BASE;
}

/* ------------------------------------------------------------------ */
/* Init / Load                                                         */
/* ------------------------------------------------------------------ */

void next_mem_init(void)
{
    memset(next_ram, 0, NEXT_RAM_SIZE);
    memset(next_rom, 0, NEXT_ROM_SIZE);
    memset(next_vram, 0, NEXT_VRAM_SIZE);
}

int next_mem_load(uint32_t addr, const uint8_t *data, uint32_t len)
{
    if (addr < NEXT_RAM_BASE)
        return -1;
    uint32_t offset = addr - NEXT_RAM_BASE;
    if (offset + len > NEXT_RAM_SIZE)
        return -1;
    memcpy(&next_ram[offset], data, len);
    return 0;
}

int next_rom_load(const uint8_t *data, uint32_t len)
{
    if (len > NEXT_ROM_SIZE)
        return -1;
    memcpy(next_rom, data, len);
    return 0;
}

/* Write a big-endian 32-bit value into ROM at byte offset */
static void rom_wr32(uint32_t offset, uint32_t val)
{
    if (offset + 3 >= NEXT_ROM_SIZE) return;
    next_rom[offset + 0] = (val >> 24) & 0xFF;
    next_rom[offset + 1] = (val >> 16) & 0xFF;
    next_rom[offset + 2] = (val >>  8) & 0xFF;
    next_rom[offset + 3] = (val >>  0) & 0xFF;
}

void next_mem_set_vectors(uint32_t ssp, uint32_t pc)
{
    /* Place a 2-instruction halt loop at ROM offset 0x400:
     *   nop            ; $4E71
     *   bra.s .-2      ; $60FE (branch to self)
     * Any unhandled exception lands here and spins safely. */
    uint32_t halt_addr = 0x00000400;
    next_rom[0x400] = 0x4E;  /* nop */
    next_rom[0x401] = 0x71;
    next_rom[0x402] = 0x60;  /* bra.s $-2 */
    next_rom[0x403] = 0xFE;

    /* Vector 0: Initial SSP */
    rom_wr32(0x000, ssp);

    /* Vector 1: Initial PC (entry point) */
    rom_wr32(0x004, pc);

    /* Vectors 2-255: all point to halt loop so stray exceptions
     * don't run off into unmapped memory */
    for (int i = 2; i < 256; i++)
        rom_wr32(i * 4, halt_addr);
}

/* ------------------------------------------------------------------ */
/* Musashi memory callbacks — 8-bit                                    */
/* ------------------------------------------------------------------ */

unsigned int m68k_read_memory_8(unsigned int address)
{
    address = addr_normalise(address);
    if (in_rom(address))
        return next_rom[rom_offset(address)];

    if (in_ram(address))
        return next_ram[address - NEXT_RAM_BASE];

    if (in_vram(address))
        return next_vram[vram_offset(address)];

    if (is_next_io(address))
        return next_io_read_8(address);

    return 0;
}

void m68k_write_memory_8(unsigned int address, unsigned int value)
{
    address = addr_normalise(address);
    if (in_ram(address)) {
        next_ram[address - NEXT_RAM_BASE] = value & 0xFF;
        return;
    }

    if (in_vram(address)) {
        next_vram[vram_offset(address)] = value & 0xFF;
        vram_dirty = 1;
        return;
    }

    if (is_next_io(address)) {
        next_io_write_8(address, value & 0xFF);
        return;
    }

    if (in_rom(address))
        return;  /* ROM: writes ignored */

    /* Unmapped: silently ignore */
}

/* ------------------------------------------------------------------ */
/* Musashi memory callbacks — 16-bit                                   */
/* ------------------------------------------------------------------ */

unsigned int m68k_read_memory_16(unsigned int address)
{
    address = addr_normalise(address);
    /* Fast path: RAM */
    if (in_ram(address) && in_ram(address + 1)) {
        uint32_t off = address - NEXT_RAM_BASE;
        return ((unsigned int)next_ram[off] << 8) |
                (unsigned int)next_ram[off + 1];
    }

    /* Fast path: ROM */
    if (in_rom(address) && in_rom(address + 1)) {
    {
        uint32_t off = rom_offset(address);
        return ((unsigned int)next_rom[off] << 8) |
                (unsigned int)next_rom[off + 1];
    }
    }

    /* I/O: native 16-bit handler */
    if (is_next_io(address))
        return next_io_read_16(address);

    /* VRAM */
    if (in_vram(address) && in_vram(address + 1)) {
        uint32_t off = vram_offset(address);
        return ((unsigned int)next_vram[off] << 8) |
                (unsigned int)next_vram[off + 1];
    }

    /* Fallback: byte-by-byte */
    return ((unsigned int)m68k_read_memory_8(address) << 8) |
            (unsigned int)m68k_read_memory_8(address + 1);
}

void m68k_write_memory_16(unsigned int address, unsigned int value)
{
    address = addr_normalise(address);
    if (in_ram(address) && in_ram(address + 1)) {
        uint32_t off = address - NEXT_RAM_BASE;
        next_ram[off]     = (value >> 8) & 0xFF;
        next_ram[off + 1] =  value       & 0xFF;
        return;
    }

    if (is_next_io(address)) {
        next_io_write_16(address, value & 0xFFFF);
        return;
    }

    if (in_vram(address) && in_vram(address + 1)) {
        uint32_t off = vram_offset(address);
        next_vram[off]     = (value >> 8) & 0xFF;
        next_vram[off + 1] =  value       & 0xFF;
        vram_dirty = 1;
        return;
    }

    /* Fallback */
    m68k_write_memory_8(address,     (value >> 8) & 0xFF);
    m68k_write_memory_8(address + 1,  value       & 0xFF);
}

/* ------------------------------------------------------------------ */
/* Musashi memory callbacks — 32-bit                                   */
/* ------------------------------------------------------------------ */

unsigned int m68k_read_memory_32(unsigned int address)
{
    address = addr_normalise(address);
    /* Fast path: RAM */
    if (in_ram(address) && in_ram(address + 3)) {
        uint32_t off = address - NEXT_RAM_BASE;
        return ((unsigned int)next_ram[off]     << 24) |
               ((unsigned int)next_ram[off + 1] << 16) |
               ((unsigned int)next_ram[off + 2] <<  8) |
                (unsigned int)next_ram[off + 3];
    }

    /* Fast path: ROM */
    if (in_rom(address) && in_rom(address + 3)) {
    {
        uint32_t off = rom_offset(address);
        return ((unsigned int)next_rom[off]     << 24) |
               ((unsigned int)next_rom[off + 1] << 16) |
               ((unsigned int)next_rom[off + 2] <<  8) |
                (unsigned int)next_rom[off + 3];
    }
    }

    /* I/O: native 32-bit handler */
    if (is_next_io(address))
        return next_io_read_32(address);

    /* VRAM */
    if (in_vram(address) && in_vram(address + 3)) {
        uint32_t off = vram_offset(address);
        return ((unsigned int)next_vram[off]     << 24) |
               ((unsigned int)next_vram[off + 1] << 16) |
               ((unsigned int)next_vram[off + 2] <<  8) |
                (unsigned int)next_vram[off + 3];
    }

    /* Fallback */
    return ((unsigned int)m68k_read_memory_8(address)     << 24) |
           ((unsigned int)m68k_read_memory_8(address + 1) << 16) |
           ((unsigned int)m68k_read_memory_8(address + 2) <<  8) |
            (unsigned int)m68k_read_memory_8(address + 3);
}

void m68k_write_memory_32(unsigned int address, unsigned int value)
{
    /* Debug: log first write with high bit set before normalisation */
    {
        static int hi_logged = 0;
        if (!hi_logged && (address & 0x80000000)) {
            xil_printf("[MEM] First hi-bit W32: raw=$%08X norm=$%08X val=$%08X\r\n",
                       address, address & 0x7FFFFFFF, value);
            hi_logged = 1;
        }
        static int oc_logged = 0;
        uint32_t norm = address & 0x7FFFFFFF;
        if (!oc_logged && norm >= 0x0C000000 && norm < 0x0C040000) {
            xil_printf("[MEM] First $0C W32: raw=$%08X norm=$%08X val=$%08X\r\n",
                       address, norm, value);
            oc_logged = 1;
        }
    }
    address = addr_normalise(address);
    /* Fast path: RAM */
    if (in_ram(address) && in_ram(address + 3)) {
        uint32_t off = address - NEXT_RAM_BASE;
        next_ram[off]     = (value >> 24) & 0xFF;
        next_ram[off + 1] = (value >> 16) & 0xFF;
        next_ram[off + 2] = (value >>  8) & 0xFF;
        next_ram[off + 3] =  value        & 0xFF;
        return;
    }

    /* I/O: native 32-bit handler */
    if (is_next_io(address)) {
        next_io_write_32(address, value);
        return;
    }

    /* VRAM */
    if (in_vram(address) && in_vram(address + 3)) {
        uint32_t off = vram_offset(address);
        next_vram[off]     = (value >> 24) & 0xFF;
        next_vram[off + 1] = (value >> 16) & 0xFF;
        next_vram[off + 2] = (value >>  8) & 0xFF;
        next_vram[off + 3] =  value        & 0xFF;
        vram_dirty = 1;
        return;
    }


    /* Fallback */
    m68k_write_memory_8(address,     (value >> 24) & 0xFF);
    m68k_write_memory_8(address + 1, (value >> 16) & 0xFF);
    m68k_write_memory_8(address + 2, (value >>  8) & 0xFF);
    m68k_write_memory_8(address + 3,  value        & 0xFF);
}
