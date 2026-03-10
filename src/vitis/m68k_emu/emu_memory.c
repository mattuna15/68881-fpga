/*
 * emu_memory.c
 * Flat 16 MB emulated RAM for Musashi M68K emulator.
 *
 * Big-endian byte order (M68K native). All accesses are masked to
 * the 16 MB address space — no bus errors, no MMU.
 */

#include <string.h>
#include "emu_memory.h"

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
/* Musashi memory callbacks — big-endian byte access                   */
/* ------------------------------------------------------------------ */

unsigned int m68k_read_memory_8(unsigned int address)
{
    return emu_ram[address & EMU_RAM_MASK];
}

unsigned int m68k_read_memory_16(unsigned int address)
{
    return ((unsigned int)emu_ram[ address      & EMU_RAM_MASK] << 8) |
            (unsigned int)emu_ram[(address + 1) & EMU_RAM_MASK];
}

unsigned int m68k_read_memory_32(unsigned int address)
{
    return ((unsigned int)emu_ram[ address      & EMU_RAM_MASK] << 24) |
           ((unsigned int)emu_ram[(address + 1) & EMU_RAM_MASK] << 16) |
           ((unsigned int)emu_ram[(address + 2) & EMU_RAM_MASK] <<  8) |
            (unsigned int)emu_ram[(address + 3) & EMU_RAM_MASK];
}

void m68k_write_memory_8(unsigned int address, unsigned int value)
{
    emu_ram[address & EMU_RAM_MASK] = value & 0xFF;
}

void m68k_write_memory_16(unsigned int address, unsigned int value)
{
    emu_ram[ address      & EMU_RAM_MASK] = (value >> 8) & 0xFF;
    emu_ram[(address + 1) & EMU_RAM_MASK] =  value       & 0xFF;
}

void m68k_write_memory_32(unsigned int address, unsigned int value)
{
    emu_ram[ address      & EMU_RAM_MASK] = (value >> 24) & 0xFF;
    emu_ram[(address + 1) & EMU_RAM_MASK] = (value >> 16) & 0xFF;
    emu_ram[(address + 2) & EMU_RAM_MASK] = (value >>  8) & 0xFF;
    emu_ram[(address + 3) & EMU_RAM_MASK] =  value        & 0xFF;
}
