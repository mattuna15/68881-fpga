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
#include "acia_emu.h"
#include "atari_video.h"
#include "gfx_fb.h"
#include "usb_hid.h"
#include "floppy_emu.h"
#include "psg_emu.h"
#include "blitter_emu.h"
#include "cir_periph.h"
#include "xil_printf.h"

/* ------------------------------------------------------------------ */
/* MC68882 CIR register mapping at Atari TT address $FFFA40            */
/*                                                                      */
/* The 68882 coprocessor interface uses 16-bit registers on the 68K bus. */
/* FPU_HARD.PRG and other Atari TT software access the CIR protocol    */
/* directly at these addresses instead of using F-line instructions.     */
/*                                                                      */
/* Atari TT map         → AXI CIR offset                               */
/* $FFFA40: Response     → OFF_CIR_RESPONSE (0x34) read                 */
/* $FFFA42: Control      → OFF_CIR_RESPONSE (0x34) write (mode)         */
/* $FFFA44: Save         → OFF_CIR_SAVE (0x30) read                     */
/* $FFFA46: Restore      → OFF_CIR_RESTORE (0x70) write                 */
/* $FFFA48: Command      → OFF_CIR_COMMAND (0x14)                       */
/* $FFFA4A: Operand      → OFF_CIR_OPERAND (0x20)                       */
/* $FFFA4C: OpWord (reg select) → OFF_CIR_OPWORD (0x10)                 */
/* $FFFA4E: (reserved)                                                  */
/* $FFFA50: Condition    → OFF_CIR_CONDITION (0x1C)                     */
/* ------------------------------------------------------------------ */

static uint16_t fpu_cir_read(uint32_t offset)
{
    static int cir_dbg_count = 0;
    uint16_t val;
    switch (offset) {
    case 0x00:
        val = (uint16_t)cir_rd(OFF_CIR_RESPONSE);
        if (cir_dbg_count < 20) {
            xil_printf("[CIR] R response=$%04X\r\n", val);
            cir_dbg_count++;
        }
        return val;
    case 0x04: return (uint16_t)cir_rd(OFF_CIR_SAVE);       /* Save */
    case 0x08: return (uint16_t)cir_rd(OFF_CIR_COMMAND);    /* Command */
    case 0x0A: return (uint16_t)cir_rd(OFF_CIR_OPERAND);    /* Operand */
    case 0x0C: return (uint16_t)cir_rd(OFF_CIR_OPWORD);     /* OpWord */
    case 0x10: return (uint16_t)cir_rd(OFF_CIR_CONDITION);   /* Condition */
    default:   return 0;
    }
}

static int cir_write_dbg_count = 0;

static void fpu_cir_write(uint32_t offset, uint16_t value)
{
    if (cir_write_dbg_count < 30) {
        static const char *names[] = {"Resp/Ctrl","?","Save","Restore",
                                       "Command","Operand","OpWord","?","Condition"};
        int idx = offset / 2;
        xil_printf("[CIR] W $FFFA%02X (%s) = $%04X\r\n",
                   0x40 + offset, (idx < 9) ? names[idx] : "?", value);
        cir_write_dbg_count++;
    }
    switch (offset) {
    case 0x00: cir_wr(OFF_CIR_RESPONSE, value); break;  /* Control/mode */
    case 0x06: cir_wr(OFF_CIR_RESTORE, value); break;   /* Restore */
    case 0x08: cir_wr(OFF_CIR_COMMAND, value); break;   /* Command */
    case 0x0A: cir_wr(OFF_CIR_OPERAND, value); break;   /* Operand */
    case 0x0C: cir_wr(OFF_CIR_OPWORD, value); break;    /* OpWord */
    default:   break;
    }
}

/* Mouse I/O region: 0xFD0050-0xFD005B (12 bytes, read-only)
 * Layout (big-endian):
 *   0x50: buttons (1 byte)
 *   0x51: (reserved)
 *   0x52-0x53: delta X (int16, big-endian)
 *   0x54-0x55: delta Y (int16, big-endian)
 *   0x56-0x57: abs X (uint16, big-endian)
 *   0x58-0x59: abs Y (uint16, big-endian)
 *   0x5A-0x5B: (reserved)
 * Reading 0x52 clears accumulated deltas. */
#define MOUSE_IO_BASE   0xFD0050
#define MOUSE_IO_SIZE   0x0C

static inline int is_mouse_io(unsigned int addr)
{
    return (addr >= MOUSE_IO_BASE) && (addr < MOUSE_IO_BASE + MOUSE_IO_SIZE);
}

/* Snapshot deltas for atomic word reads (high byte snapshots, low byte returns
 * from snapshot, reading dy low byte clears the live deltas) */
static int16_t mouse_snap_dx, mouse_snap_dy;

static unsigned int mouse_io_read(unsigned int addr)
{
    const usb_mouse_state_t *ms = usb_mouse_state();
    uint32_t off = addr - MOUSE_IO_BASE;
    switch (off) {
    case 0x00: return ms->buttons;
    case 0x01: return 0;
    case 0x02: /* DX high byte: snapshot both deltas */
        mouse_snap_dx = ms->dx;
        mouse_snap_dy = ms->dy;
        return (mouse_snap_dx >> 8) & 0xFF;
    case 0x03: return mouse_snap_dx & 0xFF;
    case 0x04: return (mouse_snap_dy >> 8) & 0xFF;
    case 0x05: /* DY low byte: clear live deltas after full read */
        usb_mouse_clear_deltas();
        return mouse_snap_dy & 0xFF;
    case 0x06: return (ms->abs_x >> 8) & 0xFF;
    case 0x07: return ms->abs_x & 0xFF;
    case 0x08: return (ms->abs_y >> 8) & 0xFF;
    case 0x09: return ms->abs_y & 0xFF;
    default:   return 0;
    }
}

static void mouse_io_write(unsigned int addr, unsigned int value)
{
    /* Only abs_x (0x06-0x07) and abs_y (0x08-0x09) are writable (for SET_MOUSE_POS) */
    usb_mouse_set_pos(addr - MOUSE_IO_BASE, value);
}


/* Static allocation — lives in DDR on the ZU3EG */
unsigned char emu_ram[EMU_RAM_SIZE];

void emu_mem_init(void)
{
    memset(emu_ram, 0, EMU_RAM_SIZE);
}

int emu_mem_load(unsigned int addr, const unsigned char *data, unsigned int len)
{
    unsigned int offset = addr & EMU_RAM_MASK;
    if (len > EMU_RAM_SIZE || offset + len > EMU_RAM_SIZE)
        return -1;
    memcpy(&emu_ram[offset], data, len);
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
/* I/O address range checks                                            */
/* ------------------------------------------------------------------ */

static inline int is_mfp(unsigned int addr)
{
    return (addr >= EMU_MFP_BASE) && (addr < EMU_MFP_BASE + EMU_MFP_SIZE);
}

static inline int is_atari_mfp(unsigned int addr)
{
    return (addr >= ATARI_MFP_BASE) && (addr < ATARI_MFP_BASE + ATARI_MFP_SIZE);
}

static inline int is_acia(unsigned int addr)
{
    return (addr >= ACIA_BASE) && (addr < ACIA_BASE + ACIA_SIZE);
}

/* ------------------------------------------------------------------ */
/* Musashi memory callbacks — big-endian byte access with MFP intercept*/
/* ------------------------------------------------------------------ */

unsigned int m68k_read_memory_8(unsigned int address)
{
    if (is_fpu_cir(address)) {
        /* CIR registers are word-sized; byte read returns high/low byte */
        uint32_t off = ((address & 0xFFFFFF) - FPU_CIR_BASE) & ~1;
        uint16_t val = fpu_cir_read(off);
        return (address & 1) ? (val & 0xFF) : ((val >> 8) & 0xFF);
    }
    if (is_atari_mfp(address))
        return atari_mfp_read(address - ATARI_MFP_BASE);
    if (is_acia(address))
        return acia_read(address);
    if (atari_vid_is_reg(address))
        return atari_vid_read(address - ATARI_VID_BASE);
    if (is_mfp(address))
        return mfp_read(address - EMU_MFP_BASE);
    if (gfx_is_io(address))
        return gfx_io_read(address - GFX_IO_BASE);
    if (is_mouse_io(address))
        return mouse_io_read(address);
    if (is_floppy_dma(address))
        return floppy_read(address - FLOPPY_DMA_BASE);
    if (is_psg(address))
        return psg_read(address - PSG_BASE);
    if (is_blitter(address))
        return blitter_read(address - BLITTER_BASE);
    if (gfx_is_fb(address))
        return gfx_read_8(address);
    return emu_ram[address & EMU_RAM_MASK];
}

unsigned int m68k_read_memory_16(unsigned int address)
{
    /* FPU CIR: native word access */
    if (is_fpu_cir(address)) {
        uint32_t off = ((address & 0xFFFFFF) - FPU_CIR_BASE) & ~1;
        return fpu_cir_read(off);
    }
    /* Atari MFP / ACIA: byte-wide I/O, decompose word reads */
    if (is_atari_mfp(address) || is_atari_mfp(address + 1) ||
        is_acia(address) || is_acia(address + 1)) {
        return ((unsigned int)m68k_read_memory_8(address) << 8) |
                (unsigned int)m68k_read_memory_8(address + 1);
    }
    if (atari_vid_is_reg(address) || atari_vid_is_reg(address + 1)) {
        return ((unsigned int)m68k_read_memory_8(address) << 8) |
                (unsigned int)m68k_read_memory_8(address + 1);
    }
    /* MFP registers are byte-wide; decompose word reads into byte
     * reads when any byte falls in the MFP range */
    if (is_mfp(address) || is_mfp(address + 1)) {
        return ((unsigned int)m68k_read_memory_8(address) << 8) |
                (unsigned int)m68k_read_memory_8(address + 1);
    }
    if (gfx_is_io(address) || gfx_is_io(address + 1)) {
        return ((unsigned int)m68k_read_memory_8(address) << 8) |
                (unsigned int)m68k_read_memory_8(address + 1);
    }
    if (is_mouse_io(address) || is_mouse_io(address + 1)) {
        return ((unsigned int)m68k_read_memory_8(address) << 8) |
                (unsigned int)m68k_read_memory_8(address + 1);
    }
    if (is_floppy_dma(address) || is_floppy_dma(address + 1)) {
        return ((unsigned int)m68k_read_memory_8(address) << 8) |
                (unsigned int)m68k_read_memory_8(address + 1);
    }
    if (is_psg(address) || is_psg(address + 1)) {
        return ((unsigned int)m68k_read_memory_8(address) << 8) |
                (unsigned int)m68k_read_memory_8(address + 1);
    }
    if (is_blitter(address) || is_blitter(address + 1)) {
        return ((unsigned int)m68k_read_memory_8(address) << 8) |
                (unsigned int)m68k_read_memory_8(address + 1);
    }
    if (gfx_is_fb(address) || gfx_is_fb(address + 1)) {
        return ((unsigned int)m68k_read_memory_8(address) << 8) |
                (unsigned int)m68k_read_memory_8(address + 1);
    }
    return ((unsigned int)emu_ram[ address      & EMU_RAM_MASK] << 8) |
            (unsigned int)emu_ram[(address + 1) & EMU_RAM_MASK];
}

unsigned int m68k_read_memory_32(unsigned int address)
{
    if (is_fpu_cir(address) || is_fpu_cir(address + 2)) {
        return ((unsigned int)m68k_read_memory_16(address) << 16) |
                (unsigned int)m68k_read_memory_16(address + 2);
    }
    if (is_atari_mfp(address) || is_atari_mfp(address + 3) ||
        is_acia(address) || is_acia(address + 3)) {
        return ((unsigned int)m68k_read_memory_8(address)     << 24) |
               ((unsigned int)m68k_read_memory_8(address + 1) << 16) |
               ((unsigned int)m68k_read_memory_8(address + 2) <<  8) |
                (unsigned int)m68k_read_memory_8(address + 3);
    }
    if (atari_vid_is_reg(address) || atari_vid_is_reg(address + 3)) {
        return ((unsigned int)m68k_read_memory_8(address)     << 24) |
               ((unsigned int)m68k_read_memory_8(address + 1) << 16) |
               ((unsigned int)m68k_read_memory_8(address + 2) <<  8) |
                (unsigned int)m68k_read_memory_8(address + 3);
    }
    /* Check first and last byte; middle bytes are covered because the
     * MFP region is wider than 4 bytes (0x30) so any straddling access
     * will have either byte 0 or byte 3 inside the range */
    if (is_mfp(address) || is_mfp(address + 3)) {
        return ((unsigned int)m68k_read_memory_8(address)     << 24) |
               ((unsigned int)m68k_read_memory_8(address + 1) << 16) |
               ((unsigned int)m68k_read_memory_8(address + 2) <<  8) |
                (unsigned int)m68k_read_memory_8(address + 3);
    }
    if (gfx_is_io(address) || gfx_is_io(address + 3)) {
        return ((unsigned int)m68k_read_memory_8(address)     << 24) |
               ((unsigned int)m68k_read_memory_8(address + 1) << 16) |
               ((unsigned int)m68k_read_memory_8(address + 2) <<  8) |
                (unsigned int)m68k_read_memory_8(address + 3);
    }
    if (is_mouse_io(address) || is_mouse_io(address + 3)) {
        return ((unsigned int)m68k_read_memory_8(address)     << 24) |
               ((unsigned int)m68k_read_memory_8(address + 1) << 16) |
               ((unsigned int)m68k_read_memory_8(address + 2) <<  8) |
                (unsigned int)m68k_read_memory_8(address + 3);
    }
    if (is_floppy_dma(address) || is_floppy_dma(address + 3)) {
        return ((unsigned int)m68k_read_memory_8(address)     << 24) |
               ((unsigned int)m68k_read_memory_8(address + 1) << 16) |
               ((unsigned int)m68k_read_memory_8(address + 2) <<  8) |
                (unsigned int)m68k_read_memory_8(address + 3);
    }
    if (is_psg(address) || is_psg(address + 3)) {
        return ((unsigned int)m68k_read_memory_8(address)     << 24) |
               ((unsigned int)m68k_read_memory_8(address + 1) << 16) |
               ((unsigned int)m68k_read_memory_8(address + 2) <<  8) |
                (unsigned int)m68k_read_memory_8(address + 3);
    }
    if (is_blitter(address) || is_blitter(address + 3)) {
        return ((unsigned int)m68k_read_memory_8(address)     << 24) |
               ((unsigned int)m68k_read_memory_8(address + 1) << 16) |
               ((unsigned int)m68k_read_memory_8(address + 2) <<  8) |
                (unsigned int)m68k_read_memory_8(address + 3);
    }
    if (gfx_is_fb(address) || gfx_is_fb(address + 3)) {
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
    /* Raw trace: catch ANY write near CIR region */
    if ((address & 0xFFFFFF) >= 0xFFFA40 && (address & 0xFFFFFF) <= 0xFFFA60) {
        static int cir_raw_w8 = 0;
        if (cir_raw_w8++ < 20)
            xil_printf("[CIR-RAW] W8 $%08X = $%02X\r\n", address, value & 0xFF);
    }
    if (is_fpu_cir(address)) {
        /* CIR registers are word-sized; byte writes accumulate via word handler.
         * Most CIR accesses are word-sized; byte writes are uncommon. */
        static uint8_t cir_hi_latch;
        if (!(address & 1)) {
            cir_hi_latch = value & 0xFF;
        } else {
            uint32_t off = ((address & 0xFFFFFF) - FPU_CIR_BASE) & ~1;
            fpu_cir_write(off, ((uint16_t)cir_hi_latch << 8) | (value & 0xFF));
        }
        return;
    }
    if (is_atari_mfp(address)) {
        atari_mfp_write(address - ATARI_MFP_BASE, value & 0xFF);
        return;
    }
    if (is_acia(address)) {
        acia_write(address, value & 0xFF);
        return;
    }
    if (atari_vid_is_reg(address)) {
        atari_vid_write(address - ATARI_VID_BASE, value & 0xFF);
        return;
    }
    if (is_mfp(address)) {
        mfp_write(address - EMU_MFP_BASE, value & 0xFF);
        return;
    }
    if (gfx_is_io(address)) {
        gfx_io_write(address - GFX_IO_BASE, value);
        return;
    }
    if (is_mouse_io(address)) {
        mouse_io_write(address, value);
        return;
    }
    if (is_floppy_dma(address)) {
        floppy_write(address - FLOPPY_DMA_BASE, value & 0xFF);
        return;
    }
    if (is_psg(address)) {
        psg_write(address - PSG_BASE, value & 0xFF);
        return;
    }
    if (is_blitter(address)) {
        blitter_write(address - BLITTER_BASE, value & 0xFF);
        return;
    }
    if (gfx_is_fb(address)) {
        gfx_write_8(address, value);
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
    /* Raw trace: catch ANY write near CIR region */
    if ((address & 0xFFFFFF) >= 0xFFFA40 && (address & 0xFFFFFF) <= 0xFFFA60) {
        static int cir_raw_w16 = 0;
        if (cir_raw_w16++ < 20)
            xil_printf("[CIR-RAW] W16 $%08X = $%04X\r\n", address, value & 0xFFFF);
    }
    /* FPU CIR: native word access */
    if (is_fpu_cir(address)) {
        uint32_t off = ((address & 0xFFFFFF) - FPU_CIR_BASE) & ~1;
        fpu_cir_write(off, value & 0xFFFF);
        return;
    }
    if (is_atari_mfp(address) || is_atari_mfp(address + 1) ||
        is_acia(address) || is_acia(address + 1)) {
        m68k_write_memory_8(address,     (value >> 8) & 0xFF);
        m68k_write_memory_8(address + 1,  value       & 0xFF);
        return;
    }
    if (atari_vid_is_reg(address) || atari_vid_is_reg(address + 1)) {
        m68k_write_memory_8(address,     (value >> 8) & 0xFF);
        m68k_write_memory_8(address + 1,  value       & 0xFF);
        return;
    }
    if (is_mfp(address) || is_mfp(address + 1)) {
        m68k_write_memory_8(address,     (value >> 8) & 0xFF);
        m68k_write_memory_8(address + 1,  value       & 0xFF);
        return;
    }
    if (gfx_is_io(address) || gfx_is_io(address + 1)) {
        m68k_write_memory_8(address,     (value >> 8) & 0xFF);
        m68k_write_memory_8(address + 1,  value       & 0xFF);
        return;
    }
    if (is_mouse_io(address) || is_mouse_io(address + 1)) {
        m68k_write_memory_8(address,     (value >> 8) & 0xFF);
        m68k_write_memory_8(address + 1,  value       & 0xFF);
        return;
    }
    if (is_floppy_dma(address) || is_floppy_dma(address + 1)) {
        m68k_write_memory_8(address,     (value >> 8) & 0xFF);
        m68k_write_memory_8(address + 1,  value       & 0xFF);
        return;
    }
    if (is_psg(address) || is_psg(address + 1)) {
        m68k_write_memory_8(address,     (value >> 8) & 0xFF);
        m68k_write_memory_8(address + 1,  value       & 0xFF);
        return;
    }
    if (is_blitter(address) || is_blitter(address + 1)) {
        m68k_write_memory_8(address,     (value >> 8) & 0xFF);
        m68k_write_memory_8(address + 1,  value       & 0xFF);
        return;
    }
    if (gfx_is_fb(address) || gfx_is_fb(address + 1)) {
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
    if (is_fpu_cir(address) || is_fpu_cir(address + 2)) {
        m68k_write_memory_16(address,     (value >> 16) & 0xFFFF);
        m68k_write_memory_16(address + 2,  value        & 0xFFFF);
        return;
    }
    if (is_atari_mfp(address) || is_atari_mfp(address + 3) ||
        is_acia(address) || is_acia(address + 3)) {
        m68k_write_memory_8(address,     (value >> 24) & 0xFF);
        m68k_write_memory_8(address + 1, (value >> 16) & 0xFF);
        m68k_write_memory_8(address + 2, (value >>  8) & 0xFF);
        m68k_write_memory_8(address + 3,  value        & 0xFF);
        return;
    }
    if (atari_vid_is_reg(address) || atari_vid_is_reg(address + 3)) {
        m68k_write_memory_8(address,     (value >> 24) & 0xFF);
        m68k_write_memory_8(address + 1, (value >> 16) & 0xFF);
        m68k_write_memory_8(address + 2, (value >>  8) & 0xFF);
        m68k_write_memory_8(address + 3,  value        & 0xFF);
        return;
    }
    if (is_mfp(address) || is_mfp(address + 3)) {
        m68k_write_memory_8(address,     (value >> 24) & 0xFF);
        m68k_write_memory_8(address + 1, (value >> 16) & 0xFF);
        m68k_write_memory_8(address + 2, (value >>  8) & 0xFF);
        m68k_write_memory_8(address + 3,  value        & 0xFF);
        return;
    }
    if (gfx_is_io(address) || gfx_is_io(address + 3)) {
        m68k_write_memory_8(address,     (value >> 24) & 0xFF);
        m68k_write_memory_8(address + 1, (value >> 16) & 0xFF);
        m68k_write_memory_8(address + 2, (value >>  8) & 0xFF);
        m68k_write_memory_8(address + 3,  value        & 0xFF);
        return;
    }
    if (is_mouse_io(address) || is_mouse_io(address + 3)) {
        m68k_write_memory_8(address,     (value >> 24) & 0xFF);
        m68k_write_memory_8(address + 1, (value >> 16) & 0xFF);
        m68k_write_memory_8(address + 2, (value >>  8) & 0xFF);
        m68k_write_memory_8(address + 3,  value        & 0xFF);
        return;
    }
    if (is_floppy_dma(address) || is_floppy_dma(address + 3)) {
        m68k_write_memory_8(address,     (value >> 24) & 0xFF);
        m68k_write_memory_8(address + 1, (value >> 16) & 0xFF);
        m68k_write_memory_8(address + 2, (value >>  8) & 0xFF);
        m68k_write_memory_8(address + 3,  value        & 0xFF);
        return;
    }
    if (is_psg(address) || is_psg(address + 3)) {
        m68k_write_memory_8(address,     (value >> 24) & 0xFF);
        m68k_write_memory_8(address + 1, (value >> 16) & 0xFF);
        m68k_write_memory_8(address + 2, (value >>  8) & 0xFF);
        m68k_write_memory_8(address + 3,  value        & 0xFF);
        return;
    }
    if (is_blitter(address) || is_blitter(address + 3)) {
        m68k_write_memory_8(address,     (value >> 24) & 0xFF);
        m68k_write_memory_8(address + 1, (value >> 16) & 0xFF);
        m68k_write_memory_8(address + 2, (value >>  8) & 0xFF);
        m68k_write_memory_8(address + 3,  value        & 0xFF);
        return;
    }
    if (gfx_is_fb(address) || gfx_is_fb(address + 3)) {
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
