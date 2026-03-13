/*
 * emu_memory.c
 * Flat 16 MB emulated RAM for Musashi M68K emulator.
 *
 * Big-endian byte order (M68K native). All accesses are masked to
 * the 16 MB address space — no bus errors, no MMU.
 */

#include <string.h>
#include "emu_memory.h"
#include "mfp_emu.h"
#include "xil_printf.h"

/* Static allocation — lives in DDR on the ZU3EG */
unsigned char emu_ram[EMU_RAM_SIZE];

void emu_mem_init(void)
{
    memset(emu_ram, 0, EMU_RAM_SIZE);
}

int emu_mem_load(unsigned int addr, const unsigned char *data, unsigned int len)
{
    if ((addr & EMU_RAM_MASK) + len > EMU_RAM_SIZE)
        return -1;
    memcpy(&emu_ram[addr & EMU_RAM_MASK], data, len);
    return 0;
}

void emu_mem_set_vectors(unsigned int ssp, unsigned int pc)
{
    /* Vector 0: Initial SSP (big-endian at address 0x00000000) */
    emu_ram[0] = (ssp >> 24) & 0xFF;
    emu_ram[1] = (ssp >> 16) & 0xFF;
    emu_ram[2] = (ssp >>  8) & 0xFF;
    emu_ram[3] = (ssp >>  0) & 0xFF;

    /* Vector 1: Initial PC (big-endian at address 0x00000004) */
    emu_ram[4] = (pc >> 24) & 0xFF;
    emu_ram[5] = (pc >> 16) & 0xFF;
    emu_ram[6] = (pc >>  8) & 0xFF;
    emu_ram[7] = (pc >>  0) & 0xFF;
}

/* ------------------------------------------------------------------ */
/* MFP address range check                                             */
/* ------------------------------------------------------------------ */

static inline int is_mfp(unsigned int addr)
{
    return (addr >= EMU_MFP_BASE) && (addr < EMU_MFP_BASE + EMU_MFP_SIZE);
}

/* ------------------------------------------------------------------ */
/* Musashi memory callbacks — big-endian byte access with MFP intercept*/
/* ------------------------------------------------------------------ */

unsigned int m68k_read_memory_8(unsigned int address)
{
    if (is_mfp(address))
        return mfp_read(address - EMU_MFP_BASE);
    return emu_ram[address & EMU_RAM_MASK];
}

unsigned int m68k_read_memory_16(unsigned int address)
{
    /* MFP registers are byte-wide; decompose word reads into byte
     * reads when any byte falls in the MFP range */
    if (is_mfp(address) || is_mfp(address + 1)) {
        return ((unsigned int)m68k_read_memory_8(address) << 8) |
                (unsigned int)m68k_read_memory_8(address + 1);
    }
    return ((unsigned int)emu_ram[ address      & EMU_RAM_MASK] << 8) |
            (unsigned int)emu_ram[(address + 1) & EMU_RAM_MASK];
}

unsigned int m68k_read_memory_32(unsigned int address)
{
    /* Check first and last byte; middle bytes are covered because the
     * MFP region is wider than 4 bytes (0x30) so any straddling access
     * will have either byte 0 or byte 3 inside the range */
    if (is_mfp(address) || is_mfp(address + 3)) {
        return ((unsigned int)m68k_read_memory_8(address)     << 24) |
               ((unsigned int)m68k_read_memory_8(address + 1) << 16) |
               ((unsigned int)m68k_read_memory_8(address + 2) <<  8) |
                (unsigned int)m68k_read_memory_8(address + 3);
    }
    return ((unsigned int)emu_ram[ address      & EMU_RAM_MASK] << 24) |
           ((unsigned int)emu_ram[(address + 1) & EMU_RAM_MASK] << 16) |
           ((unsigned int)emu_ram[(address + 2) & EMU_RAM_MASK] <<  8) |
            (unsigned int)emu_ram[(address + 3) & EMU_RAM_MASK];
}

void m68k_write_memory_8(unsigned int address, unsigned int value)
{
    if (is_mfp(address)) {
        mfp_write(address - EMU_MFP_BASE, value & 0xFF);
        return;
    }
    /* ROM region: ignore writes (write-protected) */
    if (address >= EMU_ROM_BASE && address < EMU_ROM_BASE + EMU_ROM_SIZE) {
#ifdef DEBUG
        xil_printf("[MEM] WARNING: write to ROM @%06X ignored\r\n", address);
#endif
        return;
    }
    emu_ram[address & EMU_RAM_MASK] = value & 0xFF;
}

void m68k_write_memory_16(unsigned int address, unsigned int value)
{
    if (is_mfp(address) || is_mfp(address + 1)) {
        m68k_write_memory_8(address,     (value >> 8) & 0xFF);
        m68k_write_memory_8(address + 1,  value       & 0xFF);
        return;
    }
    if (address >= EMU_ROM_BASE && address < EMU_ROM_BASE + EMU_ROM_SIZE) {
#ifdef DEBUG
        xil_printf("[MEM] WARNING: write to ROM @%06X ignored\r\n", address);
#endif
        return;
    }
    emu_ram[ address      & EMU_RAM_MASK] = (value >> 8) & 0xFF;
    emu_ram[(address + 1) & EMU_RAM_MASK] =  value       & 0xFF;
}

void m68k_write_memory_32(unsigned int address, unsigned int value)
{
    if (is_mfp(address) || is_mfp(address + 3)) {
        m68k_write_memory_8(address,     (value >> 24) & 0xFF);
        m68k_write_memory_8(address + 1, (value >> 16) & 0xFF);
        m68k_write_memory_8(address + 2, (value >>  8) & 0xFF);
        m68k_write_memory_8(address + 3,  value        & 0xFF);
        return;
    }
    if (address >= EMU_ROM_BASE && address < EMU_ROM_BASE + EMU_ROM_SIZE) {
#ifdef DEBUG
        xil_printf("[MEM] WARNING: write to ROM @%06X ignored\r\n", address);
#endif
        return;
    }
    emu_ram[ address      & EMU_RAM_MASK] = (value >> 24) & 0xFF;
    emu_ram[(address + 1) & EMU_RAM_MASK] = (value >> 16) & 0xFF;
    emu_ram[(address + 2) & EMU_RAM_MASK] = (value >>  8) & 0xFF;
    emu_ram[(address + 3) & EMU_RAM_MASK] =  value        & 0xFF;
}
