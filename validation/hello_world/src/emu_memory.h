/*
 * emu_memory.h
 * Flat 16 MB emulated RAM for Musashi M68K emulator.
 * Provides Musashi memory callback implementations.
 */

#ifndef EMU_MEMORY_H
#define EMU_MEMORY_H

#include "musashi/m68k.h"
#include "blitter_emu.h"

/* 16 MB address space */
#define EMU_RAM_SIZE  (16 * 1024 * 1024)
#define EMU_RAM_MASK  (EMU_RAM_SIZE - 1)

/* Memory map regions */
#define EMU_ROM_BASE  0xE00000      /* 256 KB EmuTOS ROM */
#define EMU_ROM_SIZE  0x040000
#define EMU_MFP_BASE  0xFD0000      /* MC68901 MFP I/O */
#define EMU_MFP_SIZE  0x000040      /* 0x00-0x2F regs + 0x30 tick + 0x34 RTC + 0x38 datetime */

/* MC68882 CIR registers at Atari TT address */
#define FPU_CIR_BASE  0xFFFA40
#define FPU_CIR_SIZE  0x12       /* $FFFA40-$FFFA51 */

static inline int is_fpu_cir(unsigned int addr)
{
    return (addr >= FPU_CIR_BASE) && (addr < FPU_CIR_BASE + FPU_CIR_SIZE);
}

/* The emulated RAM buffer (statically allocated in DDR) */
extern unsigned char emu_ram[];

/* Clear all emulated RAM to zero */
void emu_mem_init(void);

/* Load a program image into emulated RAM at the given address.
 * Returns 0 on success, -1 if it would exceed RAM bounds. */
int emu_mem_load(unsigned int addr, const unsigned char *data, unsigned int len);

/* Set up M68K initial SSP and PC from the vector table in emu_ram.
 * Call after loading a program and before m68k_pulse_reset(). */
void emu_mem_set_vectors(unsigned int ssp, unsigned int pc);

/*
 * Musashi memory callbacks — declared here, defined in emu_memory.c.
 * These are called by the Musashi core for all memory accesses.
 */
unsigned int  m68k_read_memory_8(unsigned int address);
unsigned int  m68k_read_memory_16(unsigned int address);
unsigned int  m68k_read_memory_32(unsigned int address);
void          m68k_write_memory_8(unsigned int address, unsigned int value);
void          m68k_write_memory_16(unsigned int address, unsigned int value);
void          m68k_write_memory_32(unsigned int address, unsigned int value);

#endif /* EMU_MEMORY_H */
