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

/* MC68020 coprocessor interface register layout (standard from Motorola):
 * Offset  Register         AXI CIR offset
 * $00     Response (R)     OFF_CIR_RESPONSE
 * $02     Control (W)      OFF_CIR_RESPONSE (mode)
 * $04     Save             OFF_CIR_SAVE
 * $06     Restore          OFF_CIR_RESTORE
 * $08     Operation Word   OFF_CIR_OPWORD
 * $0A     Command          OFF_CIR_COMMAND
 * $0C     (reserved)
 * $0E     Condition        OFF_CIR_CONDITION
 * $10     Operand          OFF_CIR_OPERAND
 * $14     Inst Address     OFF_CIR_INSTADDR
 * $16     Operand Address  OFF_CIR_OPADDR
 */
static uint16_t fpu_cir_read(uint32_t offset)
{
    uint16_t val;
    switch (offset) {
    case 0x00:
        val = (uint16_t)cir_rd(OFF_CIR_RESPONSE);
        /* AN-947 Null CA=0 ($0900) when idle → return MC68882 ID ($0802).
         * FPU_HARD.PRG polls for $0802 to detect idle FPU. */
        if (val == 0x0900)
            return 0x0802;
        return val;
    case 0x04: return (uint16_t)cir_rd(OFF_CIR_SAVE);
    case 0x08: return (uint16_t)cir_rd(OFF_CIR_OPWORD);
    case 0x0A: return (uint16_t)cir_rd(OFF_CIR_COMMAND);
    case 0x0E: return (uint16_t)cir_rd(OFF_CIR_CONDITION);
    case 0x10: return (uint16_t)cir_rd(OFF_CIR_OPERAND);
    case 0x14: return (uint16_t)cir_rd(OFF_CIR_INSTADDR);
    case 0x16: return (uint16_t)cir_rd(OFF_CIR_OPADDR);
    default:
#ifdef CIR_DEBUG
        xil_printf("[CIR] R unknown off=$%02X\r\n", (unsigned)offset);
#endif
        return 0;
    }
}

static void fpu_cir_write(uint32_t offset, uint16_t value)
{
    switch (offset) {
    case 0x00: /* Control/mode */
    case 0x02:
        cir_wr(OFF_CIR_RESPONSE, value);
        break;
    case 0x06: cir_wr(OFF_CIR_RESTORE, value); break;
    case 0x08: /* OpWord — starts CIR dialog */
        cir_wr(OFF_CIR_RESPONSE, 1);  /* ensure CIR mode */
        cir_wr(OFF_CIR_OPWORD, value);
        break;
    case 0x0A: /* Command — the VHDL CIR FSM supports command-only trigger
               * (SFP004 compat): if only command_written is set and
               * cir_instr_type = cpGEN, it transitions IDLE→DECODE.
               * Must ensure CIR mode since fline_init() sets peripheral. */
        cir_wr(OFF_CIR_RESPONSE, 1);  /* ensure CIR mode */
        cir_wr(OFF_CIR_COMMAND, value);
        break;
    case 0x0E: cir_wr(OFF_CIR_CONDITION, value); break;
    case 0x10: /* Operand (16-bit write — only lower half, upper is 0) */
        cir_wr(OFF_CIR_RESPONSE, 1);
        cir_wr(OFF_CIR_OPERAND, value);
        break;
    case 0x14: cir_wr(OFF_CIR_INSTADDR, value); break;
    case 0x16: cir_wr(OFF_CIR_OPADDR, value); break;
    default:
#ifdef CIR_DEBUG
        xil_printf("[CIR] W unknown off=$%02X val=$%04X\r\n",
                   (unsigned)offset, (unsigned)value);
#endif
        break;
    }
}

/* 32-bit CIR operand access — the MC68020 CIR interface transfers operand
 * data as 32-bit long words on the data bus.  These must map to a single
 * AXI write/read so the VHDL FSM sees one cir_operand_word_arrived pulse
 * per long word, matching real hardware behavior.  Other CIR registers are
 * word-sized and don't need 32-bit native access. */
static uint32_t fpu_cir_read32(uint32_t offset)
{
    if (offset == 0x10)
        return cir_rd(OFF_CIR_OPERAND);
    /* Non-operand: fall back to two 16-bit reads (big-endian) */
    return ((uint32_t)fpu_cir_read(offset) << 16) |
            (uint32_t)fpu_cir_read(offset + 2);
}

static void fpu_cir_write32(uint32_t offset, uint32_t value)
{
    if (offset == 0x10) {
        /* Single 32-bit AXI write — do NOT write OFF_CIR_RESPONSE first.
         * The extra bus_write to addr 13 can disturb the CIR_XFER_SRC FSM
         * edge-detection between the poll read and the operand write.
         * CIR mode is already active at this point. */
        cir_wr(OFF_CIR_OPERAND, value);
        return;
    }
    /* Non-operand: decompose to two 16-bit writes (big-endian) */
    fpu_cir_write(offset, (value >> 16) & 0xFFFF);
    fpu_cir_write(offset + 2, value & 0xFFFF);
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
    if (is_fpu_cir(address)) {
        uint32_t off = ((address & 0xFFFFFF) - FPU_CIR_BASE) & ~1;
        return fpu_cir_read32(off);
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
    if (is_fpu_cir(address)) {
        uint32_t off = ((address & 0xFFFFFF) - FPU_CIR_BASE) & ~1;
        fpu_cir_write32(off, value);
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
