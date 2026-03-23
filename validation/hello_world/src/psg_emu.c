/*
 * psg_emu.c
 * Minimal YM2149 PSG emulation — register 14 (Port A) only.
 *
 * Port A bits (directly from EmuTOS floppy driver):
 *   bit 0: drive A select (active low)
 *   bit 1: drive B select (active low)
 *   bit 2: side select (0=side 1, 1=side 0)
 *   bits 3-7: unused here (accent, serial, etc.)
 */

#include "psg_emu.h"

#define PSG_NUM_REGS  16

static uint8_t psg_regs[PSG_NUM_REGS];
static uint8_t psg_reg_select;

/* Latched side for each drive — set when a drive is selected via PSG.
 * On real hardware, selecting Drive B doesn't move Drive A's head.
 * flopvbl() toggles PSG rapidly but the physical head stays put. */
static int drive_side[2];  /* drive_side[0]=Drive A, [1]=Drive B */

void psg_init(void)
{
    for (int i = 0; i < PSG_NUM_REGS; i++)
        psg_regs[i] = 0;
    /* Port A defaults: all drives deselected (bits 0-1 high) */
    psg_regs[14] = 0xFF;
    psg_reg_select = 0;
    drive_side[0] = 0;
    drive_side[1] = 0;
}

uint8_t psg_read(uint32_t offset)
{
    /* YM2149: A1=0 → read selected register data, A1=1 → not used */
    if (!(offset & 2)) {
        if (psg_reg_select < PSG_NUM_REGS)
            return psg_regs[psg_reg_select];
    }
    return 0;
}

void psg_write(uint32_t offset, uint8_t value)
{
    /* YM2149 address decoding uses A1 only:
     * A1=0 ($FF8800/$FF8801) → register select
     * A1=1 ($FF8802/$FF8803) → data write */
    if (!(offset & 2)) {
        /* Register select */
        psg_reg_select = value & 0x0F;
    } else {
        /* Data write */
        if (psg_reg_select < PSG_NUM_REGS) {
            /* When a drive is selected, latch its side.
             * Hatari-verified PSG Port A bit mapping (active low):
             *   Bit 0 = side select (0=side 1, 1=side 0)
             *   Bit 1 = Drive A select
             *   Bit 2 = Drive B select */
            if (psg_reg_select == 14) {
                int side = (value & 0x01) ? 0 : 1;  /* bit 0 = side */
                if (!(value & 0x02))  /* Bit 1 low = Drive A selected */
                    drive_side[0] = side;
                if (!(value & 0x04))  /* Bit 2 low = Drive B selected */
                    drive_side[1] = side;
            }
            psg_regs[psg_reg_select] = value;
        }
    }
}

int psg_get_drive(void)
{
    /* Hatari-verified: bit 1 = Drive A, bit 2 = Drive B (active low) */
    uint8_t porta = psg_regs[14];
    if (!(porta & 0x02)) return 0;  /* Bit 1 low = Drive A */
    if (!(porta & 0x04)) return 1;  /* Bit 2 low = Drive B */
    return -1;                       /* No drive selected */
}

int psg_get_side(void)
{
    /* Return Drive A's latched side. Our FDC emulation only has Drive A.
     * The latch captures the side when EmuTOS calls select(0, side),
     * and persists even when flopvbl() later toggles PSG for monitoring. */
    return drive_side[0];
}

uint8_t psg_get_port_a(void)
{
    return psg_regs[14];
}
