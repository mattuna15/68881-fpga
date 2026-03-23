/*
 * blitter_emu.c
 * Atari ST Blitter chip emulation ($FF8A00-$FF8A3D).
 *
 * Implements all 16 halftone operations (HOP) and 16 logic operations (OP),
 * skew with FXSR/NFSR, and three endmasks. Blit executes immediately when
 * software sets the BUSY bit in the status register.
 */

#include <string.h>
#include "blitter_emu.h"
#include "emu_memory.h"
#include "xil_printf.h"

/* ---------- Register state ---------- */

static struct {
    uint16_t halftone[16];   /* $00-$1F: fill pattern RAM */
    int16_t  src_x_incr;     /* $20: source X increment (signed) */
    int16_t  src_y_incr;     /* $22: source Y increment (signed) */
    uint32_t src_addr;       /* $24: source address (24-bit) */
    uint16_t endmask_1;      /* $28: mask for first word */
    uint16_t endmask_2;      /* $2A: mask for middle words */
    uint16_t endmask_3;      /* $2C: mask for last word */
    int16_t  dst_x_incr;     /* $2E: destination X increment (signed) */
    int16_t  dst_y_incr;     /* $30: destination Y increment (signed) */
    uint32_t dst_addr;       /* $32: destination address (24-bit) */
    uint16_t x_count;        /* $36: words per line (volatile) */
    uint16_t y_count;        /* $38: lines to process (volatile) */
    uint8_t  hop;            /* $3A: halftone operation */
    uint8_t  op;             /* $3B: logic operation */
    uint8_t  status;         /* $3C: bit7=busy, bit6=hog, bits3:0=lineno */
    uint8_t  skew;           /* $3D: bit7=FXSR, bit6=NFSR, bits3:0=skew */
    uint16_t x_count_reload; /* saved x_count for per-line reload */
} blt;

/* ---------- Helpers ---------- */

/* Read a big-endian word from emu_ram */
static inline uint16_t ram_read16(uint32_t addr)
{
    addr &= EMU_RAM_MASK;
    return ((uint16_t)emu_ram[addr] << 8) | emu_ram[(addr + 1) & EMU_RAM_MASK];
}

/* Write a big-endian word to emu_ram */
static inline void ram_write16(uint32_t addr, uint16_t val)
{
    addr &= EMU_RAM_MASK;
    emu_ram[addr] = (val >> 8) & 0xFF;
    emu_ram[(addr + 1) & EMU_RAM_MASK] = val & 0xFF;
}

/* Apply 4-bit logic operation truth table */
static inline uint16_t apply_op(uint8_t op, uint16_t s, uint16_t d)
{
    uint16_t result = 0;
    if (op & 0x01) result |=  s &  d;
    if (op & 0x02) result |=  s & ~d;
    if (op & 0x04) result |= ~s &  d;
    if (op & 0x08) result |= ~s & ~d;
    return result;
}

/* ---------- Blit execution ---------- */

static void blitter_execute(void)
{
    uint32_t src_addr = blt.src_addr & 0xFFFFFE; /* word-aligned */
    uint32_t dst_addr = blt.dst_addr & 0xFFFFFE;
    uint8_t  lineno   = blt.status & 0x0F;
    uint8_t  skew_amt = blt.skew & 0x0F;
    int      fxsr     = (blt.skew >> 7) & 1;
    int      nfsr     = (blt.skew >> 6) & 1;
    uint8_t  hop      = blt.hop & 0x03;
    uint8_t  op       = blt.op & 0x0F;

    /* Hatari: x/y count of 0 is treated as 65536 */
    uint16_t x_count_start = blt.x_count ? blt.x_count : 65535;
    uint16_t y_count_start = blt.y_count ? blt.y_count : 65535;
    blt.x_count_reload = x_count_start;

    for (uint16_t y = y_count_start; y > 0; y--) {
        uint16_t src_prev = 0;
        uint16_t xcount = blt.x_count_reload;

        /* FXSR: extra source read before first word of line */
        if (fxsr) {
            src_prev = ram_read16(src_addr);
            src_addr = (uint32_t)((int32_t)src_addr + blt.src_x_incr) & 0xFFFFFF;
        }

        for (uint16_t x = 0; x < xcount; x++) {
            /* Read source word (unless NFSR suppresses the final read).
             * Hatari: NFSR skips the fetch but uses the last bus value,
             * not zero. We approximate by keeping src_word from previous
             * iteration (src_prev holds it after the shift below). */
            uint16_t src_word;
            if (nfsr && x == xcount - 1) {
                src_word = src_prev;  /* last bus value, not 0 */
            } else {
                src_word = ram_read16(src_addr);
            }

            /* Apply skew: combine previous and current source words.
             * Barrel shifter direction depends on scan direction (Hatari lines 489-509). */
            uint16_t skewed;
            if (skew_amt == 0) {
                skewed = src_word;
            } else if (blt.src_x_incr >= 0) {
                skewed = (uint16_t)((((uint32_t)src_prev << 16) | src_word) >> skew_amt);
            } else {
                skewed = (uint16_t)((((uint32_t)src_word << 16) | src_prev) >> skew_amt);
            }
            src_prev = src_word;

            /* HOP: select source data */
            uint16_t source;
            switch (hop) {
            case 0:  source = 0xFFFF; break;
            case 1:  source = blt.halftone[lineno & 0xF]; break;
            case 2:  source = skewed; break;
            default: source = skewed & blt.halftone[lineno & 0xF]; break;
            }

            /* Read destination */
            uint16_t dest = ram_read16(dst_addr);

            /* Apply logic operation */
            uint16_t result = apply_op(op, source, dest);

            /* Select endmask (Hatari lines 787-793: endmask_1 alone for single-word) */
            uint16_t mask;
            if (xcount == 1) {
                mask = blt.endmask_1;
            } else if (x == 0) {
                mask = blt.endmask_1;
            } else if (x == xcount - 1) {
                mask = blt.endmask_3;
            } else {
                mask = blt.endmask_2;
            }

            /* Merge with destination using mask */
            uint16_t final_val = (result & mask) | (dest & ~mask);
            ram_write16(dst_addr, final_val);

            /* Advance addresses (matches Hatari lines 822-852).
             * Source only advances when a fetch occurred.
             * When NFSR: src_y_incr applies one word early (at xcount-2),
             * and no src advance on the last word (no fetch happened). */
            int last_word = (x == xcount - 1);
            int fetched_src = !(nfsr && last_word);

            if (fetched_src) {
                if (last_word || (nfsr && x == xcount - 2))
                    src_addr = (uint32_t)((int32_t)src_addr + blt.src_y_incr) & 0xFFFFFF;
                else
                    src_addr = (uint32_t)((int32_t)src_addr + blt.src_x_incr) & 0xFFFFFF;
            }

            if (last_word)
                dst_addr = (uint32_t)((int32_t)dst_addr + blt.dst_y_incr) & 0xFFFFFF;
            else
                dst_addr = (uint32_t)((int32_t)dst_addr + blt.dst_x_incr) & 0xFFFFFF;
        }

        /* Advance halftone line number (Hatari lines 844-847) */
        if (blt.dst_y_incr >= 0)
            lineno = (lineno + 1) & 0x0F;
        else
            lineno = (lineno - 1) & 0x0F;
    }

    /* Update registers to reflect completed state */
    blt.src_addr = src_addr;
    blt.dst_addr = dst_addr;
    blt.y_count  = 0;
    blt.status   = (blt.status & 0x30) | lineno; /* clear BUSY+HOG (Hatari), keep SMUDGE, update LINENO */
}

/* ---------- Public API ---------- */

void blitter_init(void)
{
    memset(&blt, 0, sizeof(blt));
    blt.endmask_1 = 0xFFFF;
    blt.endmask_2 = 0xFFFF;
    blt.endmask_3 = 0xFFFF;
}

uint8_t blitter_read(uint32_t offset)
{
    if (offset <= 0x1F) {
        /* Halftone RAM: 16 words at $00-$1F */
        uint32_t idx = offset >> 1;
        if (offset & 1)
            return blt.halftone[idx] & 0xFF;
        else
            return (blt.halftone[idx] >> 8) & 0xFF;
    }

    switch (offset) {
    case 0x20: return (blt.src_x_incr >> 8) & 0xFF;
    case 0x21: return blt.src_x_incr & 0xFF;
    case 0x22: return (blt.src_y_incr >> 8) & 0xFF;
    case 0x23: return blt.src_y_incr & 0xFF;
    case 0x24: return (blt.src_addr >> 24) & 0xFF;
    case 0x25: return (blt.src_addr >> 16) & 0xFF;
    case 0x26: return (blt.src_addr >> 8) & 0xFF;
    case 0x27: return blt.src_addr & 0xFF;
    case 0x28: return (blt.endmask_1 >> 8) & 0xFF;
    case 0x29: return blt.endmask_1 & 0xFF;
    case 0x2A: return (blt.endmask_2 >> 8) & 0xFF;
    case 0x2B: return blt.endmask_2 & 0xFF;
    case 0x2C: return (blt.endmask_3 >> 8) & 0xFF;
    case 0x2D: return blt.endmask_3 & 0xFF;
    case 0x2E: return (blt.dst_x_incr >> 8) & 0xFF;
    case 0x2F: return blt.dst_x_incr & 0xFF;
    case 0x30: return (blt.dst_y_incr >> 8) & 0xFF;
    case 0x31: return blt.dst_y_incr & 0xFF;
    case 0x32: return (blt.dst_addr >> 24) & 0xFF;
    case 0x33: return (blt.dst_addr >> 16) & 0xFF;
    case 0x34: return (blt.dst_addr >> 8) & 0xFF;
    case 0x35: return blt.dst_addr & 0xFF;
    case 0x36: return (blt.x_count >> 8) & 0xFF;
    case 0x37: return blt.x_count & 0xFF;
    case 0x38: return (blt.y_count >> 8) & 0xFF;
    case 0x39: return blt.y_count & 0xFF;
    case 0x3A: return blt.hop;
    case 0x3B: return blt.op;
    case 0x3C: return blt.status;
    case 0x3D: return blt.skew;
    default:   return 0;
    }
}

void blitter_write(uint32_t offset, uint8_t value)
{
    if (offset <= 0x1F) {
        /* Halftone RAM */
        uint32_t idx = offset >> 1;
        if (offset & 1)
            blt.halftone[idx] = (blt.halftone[idx] & 0xFF00) | value;
        else
            blt.halftone[idx] = (blt.halftone[idx] & 0x00FF) | ((uint16_t)value << 8);
        return;
    }

    switch (offset) {
    case 0x20: blt.src_x_incr = (int16_t)((blt.src_x_incr & 0x00FF) | ((uint16_t)value << 8)); break;
    case 0x21: blt.src_x_incr = (int16_t)((blt.src_x_incr & 0xFF00) | value); break;
    case 0x22: blt.src_y_incr = (int16_t)((blt.src_y_incr & 0x00FF) | ((uint16_t)value << 8)); break;
    case 0x23: blt.src_y_incr = (int16_t)((blt.src_y_incr & 0xFF00) | value); break;
    case 0x24: blt.src_addr = (blt.src_addr & 0x00FFFFFF) | ((uint32_t)value << 24); break;
    case 0x25: blt.src_addr = (blt.src_addr & 0xFF00FFFF) | ((uint32_t)value << 16); break;
    case 0x26: blt.src_addr = (blt.src_addr & 0xFFFF00FF) | ((uint32_t)value << 8); break;
    case 0x27: blt.src_addr = (blt.src_addr & 0xFFFFFF00) | value; break;
    case 0x28: blt.endmask_1 = (blt.endmask_1 & 0x00FF) | ((uint16_t)value << 8); break;
    case 0x29: blt.endmask_1 = (blt.endmask_1 & 0xFF00) | value; break;
    case 0x2A: blt.endmask_2 = (blt.endmask_2 & 0x00FF) | ((uint16_t)value << 8); break;
    case 0x2B: blt.endmask_2 = (blt.endmask_2 & 0xFF00) | value; break;
    case 0x2C: blt.endmask_3 = (blt.endmask_3 & 0x00FF) | ((uint16_t)value << 8); break;
    case 0x2D: blt.endmask_3 = (blt.endmask_3 & 0xFF00) | value; break;
    case 0x2E: blt.dst_x_incr = (int16_t)((blt.dst_x_incr & 0x00FF) | ((uint16_t)value << 8)); break;
    case 0x2F: blt.dst_x_incr = (int16_t)((blt.dst_x_incr & 0xFF00) | value); break;
    case 0x30: blt.dst_y_incr = (int16_t)((blt.dst_y_incr & 0x00FF) | ((uint16_t)value << 8)); break;
    case 0x31: blt.dst_y_incr = (int16_t)((blt.dst_y_incr & 0xFF00) | value); break;
    case 0x32: blt.dst_addr = (blt.dst_addr & 0x00FFFFFF) | ((uint32_t)value << 24); break;
    case 0x33: blt.dst_addr = (blt.dst_addr & 0xFF00FFFF) | ((uint32_t)value << 16); break;
    case 0x34: blt.dst_addr = (blt.dst_addr & 0xFFFF00FF) | ((uint32_t)value << 8); break;
    case 0x35: blt.dst_addr = (blt.dst_addr & 0xFFFFFF00) | value; break;
    case 0x36: blt.x_count = (blt.x_count & 0x00FF) | ((uint16_t)value << 8); break;
    case 0x37: blt.x_count = (blt.x_count & 0xFF00) | value; break;
    case 0x38: blt.y_count = (blt.y_count & 0x00FF) | ((uint16_t)value << 8); break;
    case 0x39: blt.y_count = (blt.y_count & 0xFF00) | value; break;
    case 0x3A: blt.hop = value & 0x03; break;
    case 0x3B: blt.op  = value & 0x0F; break;
    case 0x3C:
        blt.status = value & 0xEF; /* Hatari: bit 4 masked out */
        if (value & 0x80) {
            if (blt.y_count == 0) {
                blt.status &= ~(0x80 | 0x40);
            } else {
                blitter_execute();
            }
        }
        break;
    case 0x3D: blt.skew = value; break;
    }
}
