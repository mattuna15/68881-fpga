/*
 * next_mon_stub.h
 * Fake ROM monitor (mon_global) for NeXT Mach kernel boot.
 *
 * The kernel's NeXT_init() expects a pointer to a mon_global structure
 * from the ROM monitor. We build one in main RAM and point the kernel
 * at it via register setup before jumping to the entry point.
 */

#ifndef NEXT_MON_STUB_H
#define NEXT_MON_STUB_H

#include <stdint.h>

/* Build a mon_global structure in RAM at the given physical address.
 * Returns the address of the mon_global for passing to the kernel.
 *
 * Parameters:
 *   mg_addr    - physical address to place the structure (must be in RAM)
 *   ram_base   - base of main memory (0x04000000)
 *   ram_size   - size of main memory in bytes
 *   machine    - machine type (NeXT_WARP9 etc.)
 */
uint32_t next_mon_build(uint32_t mg_addr, uint32_t ram_base,
                        uint32_t ram_size, uint8_t machine);

/* Console device IDs (from mon/global.h conventions) */
#define CONS_I_KBD      0   /* keyboard input */
#define CONS_I_SCC_A    1   /* SCC channel A input */
#define CONS_I_SCC_B    2   /* SCC channel B input */
#define CONS_O_BITMAP   0   /* bitmap (km) output */
#define CONS_O_SCC_A    1   /* SCC channel A output */
#define CONS_O_SCC_B    2   /* SCC channel B output */

#endif /* NEXT_MON_STUB_H */
