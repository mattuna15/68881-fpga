/*
 * next_memory.c
 * Musashi memory callbacks for NeXT 68040LC emulator.
 *
 * Sparse 32-bit address map:
 *   EPROM     : 0x00000000 (128 KB, R/O — exception vectors live here)
 *   I/O       : 0x02000000 (1 MB, dispatched to next_devs)
 *   Main RAM  : 0x04000000 (64 MB, R/W — kernel loads here)
 *   Video RAM : 0x0B000000 (256 KB, R/W)
 *   Unmapped  : returns 0, writes ignored
 */

#include "next_memory.h"
#include "next_devs.h"
#include "next_video.h"
#include "xil_printf.h"
#include "musashi/m68k.h"
#include <string.h>

/* Track VRAM writes for display refresh — per-scanline dirty bitmap.
 * Each bit in vram_dirty_lines[] represents one scanline (832 lines max).
 * The VRAM write paths set the appropriate bit based on the byte offset
 * and the scanline stride (NEXT_VIDEO_NBPL bytes/line — 280 Turbo, 288 classic). */
static int vram_dirty;
static uint32_t vram_dirty_lines[26];  /* 832 bits = 26 × 32 */

int next_vram_is_dirty(void)  { return vram_dirty; }
void next_vram_mark_clean(void) { vram_dirty = 0; }

void next_vram_get_dirty_lines(uint32_t *out)
{
    /* Note: on dual-core configurations the emulator core may set a dirty
     * bit between memcpy and memset, causing that bit to be lost. This is
     * benign — the affected scanline will simply be redrawn one frame late.
     * No memory barrier is needed since the worst case is a single-frame
     * delay on one scanline. */
    memcpy(out, vram_dirty_lines, sizeof(vram_dirty_lines));
    memset(vram_dirty_lines, 0, sizeof(vram_dirty_lines));
}

void next_vram_mark_all_dirty(void)
{
    memset(vram_dirty_lines, 0xFF, sizeof(vram_dirty_lines));
    vram_dirty = 1;
}

static inline void vram_set_line_dirty(uint32_t offset)
{
    uint32_t line = offset / NEXT_VIDEO_NBPL;
    if (line < 832) {
        vram_dirty_lines[line >> 5] |= (1u << (line & 31));
    }
}

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

/* Turbo 4-bank RAM decode.
 * Each bank is 32 MB, based at $04/$06/$08/$0A 000000.  Previous masks
 * the incoming address with $07FFFFFF and indexes its NEXTRam[128 MB]
 * buffer directly — so bank 0 at $04000000 lands at NEXTRam offset
 * $04000000 (64 MB into the buffer), bank 2 at $08000000 lands at
 * NEXTRam offset 0, etc.  We match that layout exactly so that any
 * inter-bank pointers the ROM computes (e.g. A2=$06960100 walking
 * into bank 1) index the same physical byte as Previous. */
#define NEXT_RAM_BANK_MASK   0x07FFFFFFu  /* $06000000 | (32MB - 1) */

static inline int in_ram(uint32_t addr)
{
    /* All four Turbo banks live in $04000000..$0BFFFFFF. */
    return (addr >= NEXT_RAM_BASE) &&
           (addr < NEXT_RAM_BASE + NEXT_RAM_SIZE);
}

static inline uint32_t ram_offset(uint32_t addr)
{
    /* Match Previous's NEXTRam layout:
     *   bank 0 ($04xxxxxx) → buffer offset $04xxxxxx (64..96 MB)
     *   bank 1 ($06xxxxxx) → buffer offset $06xxxxxx (96..128 MB)
     *   bank 2 ($08xxxxxx) → buffer offset $00xxxxxx ( 0..32 MB)
     *   bank 3 ($0Axxxxxx) → buffer offset $02xxxxxx (32..64 MB)
     * Achieved by stripping bits 27+ (the bank-select above $08000000
     * folds back to low 128 MB). */
    return addr & NEXT_RAM_BANK_MASK;
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
    if (!in_ram(addr) || !in_ram(addr + len - 1))
        return -1;
    /* Copy byte-by-byte so each destination byte goes through the
     * bank-mask offset calculation (straddling bank boundaries is
     * not safe with a plain memcpy). */
    for (uint32_t i = 0; i < len; i++)
        next_ram[ram_offset(addr + i)] = data[i];
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
/* Bus-error hole detection                                            */
/* The gap between RAM end ($08000000 after 64 MB) and VRAM start      */
/* ($0B000000) has no physical backing on our target.  Reading it on   */
/* a real NeXT raises a bus error, which the ROM's memory-sizing       */
/* routine uses to detect the end of installed RAM.  Returning 0 here  */
/* silently would let the ROM walk off into phantom banks.             */
/* ------------------------------------------------------------------ */
static inline int in_ram_hole(uint32_t addr)
{
    return addr >= (NEXT_RAM_BASE + NEXT_RAM_SIZE) && addr < 0x0B000000;
}

static inline int bus_error_if_hole(uint32_t addr)
{
    /* With RAM now covering the full Turbo window ($04000000-$0BFFFFFF,
     * 128 MB), there is no hole between RAM and VRAM.  Keep this helper
     * as a compile-compatibility no-op for the existing call sites. */
    (void)addr;
    return 0;
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
        return next_ram[ram_offset(address)];

    if (in_vram(address))
        return next_vram[vram_offset(address)];

    if (is_next_io(address))
        return next_io_read_8(address);

    if (bus_error_if_hole(address))
        return 0;

    return 0;
}

/* Stack-region watchpoint: the Turbo ROM's POST stack lives in the top
 * of VRAM ($0C03E000..$0C040000). Log writes that land in that range
 * but are NOT from a PC that is close-ish to the current SP (i.e. not
 * a plain stack push). Those are the writes that clobber the stack.
 *
 * We also suppress logging for the huge $AAAAAAAA pattern-fill loop at
 * $01003C88 (which is already well-understood legit POST). Everything
 * else in the stack region is suspect. */
/* Stack-region watchpoint.  Narrow to the specific 64-byte band that
 * the OOB crash dump shows getting clobbered with $01010101 pattern
 * ($0C03F5E0..$0C03F620 — the region that ends up being saved-reg /
 * local-variable area of a later function frame).  That way we catch
 * ONLY the bogus writes and not the well-known $AA / counter fills
 * walking across all of VRAM.
 *
 * Also filter by PC for the two known-good ROM fill subroutines. */
/* Laser-focused watchpoint on exactly the 4 bytes that the RTS at
 * $01003F1C pops ($0C03F68E..$0C03F691).  NO filtering — we want
 * every single write that lands in those bytes, in order. */
static inline void ret_slot_watch(unsigned int address, unsigned int value, int width)
{
    uint32_t last = address + ((width == 8) ? 0 : (width == 16 ? 1 : 3));
    if (address > 0x0C03F691u || last < 0x0C03F68Eu)
        return;
    static int n = 0;
    if (n < 200) {
        uint32_t pc = m68k_get_reg(NULL, M68K_REG_PPC);
        uint32_t sp = m68k_get_reg(NULL, M68K_REG_A7);
        xil_printf("[RET%d] @%08X = %08X PC=$%08X A7=$%08X n=%d\r\n",
                   width, address, value, pc, sp, n);
        n++;
    }
}

/* Read-side watchpoint: log every read from the same 4-byte slot. */
static inline void ret_slot_read_watch(unsigned int address, unsigned int value, int width)
{
    uint32_t last = address + ((width == 8) ? 0 : (width == 16 ? 1 : 3));
    if (address > 0x0C03F691u || last < 0x0C03F68Eu)
        return;
    static int n = 0;
    if (n < 60) {
        uint32_t pc = m68k_get_reg(NULL, M68K_REG_PPC);
        uint32_t sp = m68k_get_reg(NULL, M68K_REG_A7);
        xil_printf("[RETR%d] @%08X = %08X PC=$%08X A7=$%08X n=%d\r\n",
                   width, address, value, pc, sp, n);
        n++;
    }
}

static inline void stack_watch(unsigned int address, unsigned int value, int width)
{
    ret_slot_watch(address, value, width);
    /* Two windows of interest:
     *   (a) $0C03F680..$0C03F6A0 — the return-address slot at $0C03F68E
     *       is where the RTS at $01003F1C pops $380C0400.  Find the
     *       instruction that puts $380C0400 there.
     *   (b) $0C03F5E0..$0C03F640 — local-variable area in the nested
     *       function frame where we see the $01 pattern build-up.
     */
    int in_ret = (address >= 0x0C03F680 && address < 0x0C03F6A4);
    int in_loc = (address >= 0x0C03F5E0 && address < 0x0C03F640);
    if (!in_ret && !in_loc)
        return;

    uint32_t pc = m68k_get_reg(NULL, M68K_REG_PPC);
    /* Known-good loops — exclude so we have budget for the real writes. */
    if (pc == 0x01003C88 || pc == 0x01003D08 || pc == 0x01003C90 ||
        pc == 0x0100474E || pc == 0x01004752)
        return;
    /* Also filter ordinary stack push/pop: any write where dest is very
     * close to current A7 (within 256 bytes).  Those are almost always
     * legitimate function-frame pushes. */
    {
        uint32_t sp_now = m68k_get_reg(NULL, M68K_REG_A7);
        int32_t diff = (int32_t)(address - sp_now);
        if (diff >= -4 && diff < 256)
            return;
    }
    /* Separate counters so the two windows don't starve each other. */
    static int ret_log = 0;
    static int loc_log = 0;
    int *counter = in_ret ? &ret_log : &loc_log;
    int cap = in_ret ? 120 : 10;
    if (*counter < cap) {
        uint32_t sp = m68k_get_reg(NULL, M68K_REG_A7);
        xil_printf("[STKW%d] @%08X = %08X PC=$%08X A7=$%08X\r\n",
                   width, address, value, pc, sp);
        (*counter)++;
    }
}

void m68k_write_memory_8(unsigned int address, unsigned int value)
{
    address = addr_normalise(address);
    stack_watch(address, value, 8);
    if (in_ram(address)) {
        next_ram[ram_offset(address)] = value & 0xFF;
        return;
    }

    if (in_vram(address)) {
        uint32_t off = vram_offset(address);
        next_vram[off] = value & 0xFF;
        vram_set_line_dirty(off);
        vram_dirty = 1;
        return;
    }

    if (is_next_io(address)) {
        next_io_write_8(address, value & 0xFF);
        return;
    }

    if (in_rom(address))
        return;  /* ROM: writes ignored */

    if (bus_error_if_hole(address))
        return;

    /* Unmapped: silently ignore */
}

/* ------------------------------------------------------------------ */
/* Musashi memory callbacks — 16-bit                                   */
/* ------------------------------------------------------------------ */

unsigned int m68k_read_memory_16(unsigned int address)
{
    address = addr_normalise(address);
    /* OOB trap: any 16-bit read from an address outside every known
     * valid region.  For instruction fetches this returns an ILLEGAL
     * opcode, forcing an exception immediately rather than letting the
     * CPU walk through phantom zeros.  For stray data reads it still
     * logs the first few occurrences so we can see *where* the bad
     * pointer originated. */
    if (!in_rom(address) && !in_ram(address) &&
        !in_vram(address) && !is_next_io(address)) {
        static int oob_log = 0;
        if (oob_log < 6) {
            uint32_t pc  = m68k_get_reg(NULL, M68K_REG_PC);
            uint32_t ppc = m68k_get_reg(NULL, M68K_REG_PPC);
            uint32_t sp  = m68k_get_reg(NULL, M68K_REG_A7);
            uint32_t sr  = m68k_get_reg(NULL, M68K_REG_SR);
            xil_printf("[OOB-R16] addr=$%08X PC=$%08X PPC=$%08X SR=$%04X A7=$%08X\r\n",
                       address, pc, ppc, sr & 0xFFFF, sp);
            for (int i = 0; i < 8; i++) {
                uint32_t v = next_phys_read_32(sp + i * 4);
                xil_printf("  [A7+%02X] %08X\r\n", i * 4, v);
            }
            /* On the FIRST OOB fetch only, dump the recent PC history so
             * we can see what valid instruction ran right before the CPU
             * jumped off into garbage. */
            if (oob_log == 0) {
                extern void emu_dump_pc_ring(const char *why);
                emu_dump_pc_ring("first OOB-R16 fetch");
            }
            oob_log++;
        }
        return 0x4AFC;  /* ILLEGAL instruction */
    }
    /* Fast path: RAM — both bytes must be in the same bank, otherwise
     * fall through to byte-by-byte which will re-mask each byte. */
    if (in_ram(address) && in_ram(address + 1) &&
        (ram_offset(address) + 1 == ram_offset(address + 1))) {
        uint32_t off = ram_offset(address);
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

    if (bus_error_if_hole(address))
        return 0;

    /* Fallback: byte-by-byte */
    return ((unsigned int)m68k_read_memory_8(address) << 8) |
            (unsigned int)m68k_read_memory_8(address + 1);
}

void m68k_write_memory_16(unsigned int address, unsigned int value)
{
    address = addr_normalise(address);
    stack_watch(address, value, 16);
    if (in_ram(address) && in_ram(address + 1) &&
        (ram_offset(address) + 1 == ram_offset(address + 1))) {
        uint32_t off = ram_offset(address);
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
        vram_set_line_dirty(off);
        vram_dirty = 1;
        return;
    }

    if (bus_error_if_hole(address))
        return;

    /* Fallback */
    m68k_write_memory_8(address,     (value >> 8) & 0xFF);
    m68k_write_memory_8(address + 1,  value       & 0xFF);
}

/* ------------------------------------------------------------------ */
/* Musashi memory callbacks — 32-bit                                   */
/* ------------------------------------------------------------------ */

static unsigned int m68k_read_memory_32_impl(unsigned int address);
unsigned int m68k_read_memory_32(unsigned int address)
{
    unsigned int v = m68k_read_memory_32_impl(address);
    ret_slot_read_watch(addr_normalise(address), v, 32);
    return v;
}
static unsigned int m68k_read_memory_32_impl(unsigned int address)
{
    address = addr_normalise(address);
    /* Vector-fetch watchpoint.  The ROM has relocated VBR to somewhere
     * around $0C03FC00 (inside VRAM).  Any read in $0C03FC00..$0C03FFFF
     * is an exception dispatch picking up a handler address — log it
     * with the current PC / PPC so we can see which exception fired
     * and from what instruction. */
    if (address >= 0x0C03FC00 && address < 0x0C040000) {
        static int vec_log = 0;
        if (vec_log < 20) {
            uint32_t pc  = m68k_get_reg(NULL, M68K_REG_PC);
            uint32_t ppc = m68k_get_reg(NULL, M68K_REG_PPC);
            uint32_t sp  = m68k_get_reg(NULL, M68K_REG_A7);
            int vec = (address - 0x0C03FC00) / 4;
            xil_printf("[VEC] fetch vec%d @%08X PC=$%08X PPC=$%08X A7=$%08X\r\n",
                       vec, address, pc, ppc, sp);
            vec_log++;
        }
    }
    /* Fast path: RAM — all four bytes must land in the same bank. */
    if (in_ram(address) && in_ram(address + 3) &&
        (ram_offset(address) + 3 == ram_offset(address + 3))) {
        uint32_t off = ram_offset(address);
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

    if (bus_error_if_hole(address))
        return 0;

    /* Fallback */
    return ((unsigned int)m68k_read_memory_8(address)     << 24) |
           ((unsigned int)m68k_read_memory_8(address + 1) << 16) |
           ((unsigned int)m68k_read_memory_8(address + 2) <<  8) |
            (unsigned int)m68k_read_memory_8(address + 3);
}

void m68k_write_memory_32(unsigned int address, unsigned int value)
{
    address = addr_normalise(address);
    stack_watch(address, value, 32);
    /* Fast path: RAM — all four bytes must land in the same bank. */
    if (in_ram(address) && in_ram(address + 3) &&
        (ram_offset(address) + 3 == ram_offset(address + 3))) {
        uint32_t off = ram_offset(address);
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
        vram_set_line_dirty(off);
        vram_dirty = 1;
        return;
    }


    if (bus_error_if_hole(address))
        return;

    /* Fallback */
    m68k_write_memory_8(address,     (value >> 24) & 0xFF);
    m68k_write_memory_8(address + 1, (value >> 16) & 0xFF);
    m68k_write_memory_8(address + 2, (value >>  8) & 0xFF);
    m68k_write_memory_8(address + 3,  value        & 0xFF);
}
