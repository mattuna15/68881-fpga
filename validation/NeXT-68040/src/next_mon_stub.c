/*
 * next_mon_stub.c
 * Build a fake mon_global structure for NeXT Mach kernel boot.
 *
 * The actual mon_global is ~500 bytes with many fields. We only
 * populate the fields that NeXT_init() reads during early boot:
 *   - mg_simm[4]       (offset 0x00, 4 bytes)
 *   - mg_flags          (offset 0x04, 1 byte)
 *   - mg_sid            (offset 0x08, 4 bytes)
 *   - mg_pagesize       (offset 0x0C, 4 bytes)
 *   - mg_mon_stack      (offset 0x10, 4 bytes)
 *   - mg_vbr            (offset 0x14, 4 bytes)
 *   - mg_region[0]      (offset 0x18, 8 bytes: base + size)
 *   - mg_console_i      (offset varies)
 *   - mg_console_o      (offset varies)
 *   - mg_machine_type   (offset varies)
 *   - mg_board_rev      (offset varies)
 *
 * Since the exact offsets depend on the mk-108.1 struct layout, we
 * write a minimal binary blob that the kernel can parse. The offsets
 * below are derived from reading mon/global.h.
 */

#include "next_mon_stub.h"
#include "next_memory.h"
#include "next_hw.h"
#include <string.h>

/* mon_global field offsets (from NeXTMach/mk-108.1/mon/global.h).
 * These are approximate — the struct uses bitfields and padding that
 * may differ between compiler versions. We build the structure by
 * writing bytes directly into emulated RAM. */

/* Write a big-endian 32-bit value into RAM at physical address.
 * Uses the same bank-masked offset as the main memory read/write
 * paths in next_memory.c so the CPU sees the same bytes we wrote. */
static void ram_wr32(uint32_t addr, uint32_t val)
{
    if (addr < NEXT_RAM_BASE || addr >= NEXT_RAM_BASE + NEXT_RAM_SIZE)
        return;
    uint32_t off = addr & 0x07FFFFFFu;
    next_ram[off + 0] = (val >> 24) & 0xFF;
    next_ram[off + 1] = (val >> 16) & 0xFF;
    next_ram[off + 2] = (val >>  8) & 0xFF;
    next_ram[off + 3] = (val >>  0) & 0xFF;
}

static void ram_wr8(uint32_t addr, uint8_t val)
{
    if (addr < NEXT_RAM_BASE || addr >= NEXT_RAM_BASE + NEXT_RAM_SIZE)
        return;
    next_ram[addr & 0x07FFFFFFu] = val;
}

uint32_t next_mon_build(uint32_t mg_addr, uint32_t ram_base,
                        uint32_t ram_size, uint8_t machine)
{
    /* Zero the mon_global area (512 bytes should cover the structure) */
    uint32_t mg_size = 512;
    if (mg_addr >= NEXT_RAM_BASE && mg_addr + mg_size <= NEXT_RAM_BASE + NEXT_RAM_SIZE) {
        /* Zero via the per-byte write helper so we go through the
         * bank-mask offset like every other writer. */
        for (uint32_t i = 0; i < mg_size; i++)
            ram_wr8(mg_addr + i, 0);
    }

    /* mg_simm[0..3]: SIMM configuration.
     * Each byte encodes the SIMM size: 0x20 = 32MB, 0x10 = 16MB, 0x04 = 4MB,
     * 0x01 = 1MB, 0x00 = empty. We report 4x 32MB SIMMs = 128 MB total. */
    ram_wr8(mg_addr + 0x00, 0x20);  /* SIMM 0: 32 MB */
    ram_wr8(mg_addr + 0x01, 0x20);  /* SIMM 1: 32 MB */
    ram_wr8(mg_addr + 0x02, 0x20);  /* SIMM 2: 32 MB */
    ram_wr8(mg_addr + 0x03, 0x20);  /* SIMM 3: 32 MB */

    /* mg_flags (offset 0x04): boot flags */
    ram_wr8(mg_addr + 0x04, 0x00);

    /* mg_sid (offset 0x08): slot ID = 0 */
    ram_wr32(mg_addr + 0x08, 0x00000000);

    /* mg_pagesize (offset 0x0C): 8192 bytes */
    ram_wr32(mg_addr + 0x0C, 8192);

    /* mg_mon_stack (offset 0x10): monitor stack at top of first 64KB */
    ram_wr32(mg_addr + 0x10, ram_base + 0x10000);

    /* mg_vbr (offset 0x14): initial VBR (exception vectors at addr 0) */
    ram_wr32(mg_addr + 0x14, 0x00000000);

    /* mg_region[0]: base and size of main memory
     * Each region is 8 bytes: { uint32_t base, uint32_t size }
     * Up to 4 regions starting at offset 0x18. */
    ram_wr32(mg_addr + 0x18, ram_base);   /* region[0].base */
    ram_wr32(mg_addr + 0x1C, ram_size);   /* region[0].size */

    /* Remaining regions: empty (size=0) */
    ram_wr32(mg_addr + 0x20, 0);  /* region[1].base */
    ram_wr32(mg_addr + 0x24, 0);  /* region[1].size */
    ram_wr32(mg_addr + 0x28, 0);  /* region[2] */
    ram_wr32(mg_addr + 0x2C, 0);
    ram_wr32(mg_addr + 0x30, 0);  /* region[3] */
    ram_wr32(mg_addr + 0x34, 0);

    /* Console I/O (offsets are further into the struct — these are
     * approximate and may need adjustment based on actual struct layout).
     * Place at a known offset we can reference. */
    /* mg_console_i at ~offset 0x80 */
    ram_wr32(mg_addr + 0x80, CONS_I_SCC_A);
    /* mg_console_o at ~offset 0x84 */
    ram_wr32(mg_addr + 0x84, CONS_O_SCC_A);

    /* mg_machine_type at ~offset 0x88 */
    ram_wr8(mg_addr + 0x88, machine);
    /* mg_board_rev at ~offset 0x89 */
    ram_wr8(mg_addr + 0x89, 0x00);

    return mg_addr;
}
