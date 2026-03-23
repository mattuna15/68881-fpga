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

void psg_init(void)
{
    for (int i = 0; i < PSG_NUM_REGS; i++)
        psg_regs[i] = 0;
    /* Port A defaults: all drives deselected (bits 0-1 high) */
    psg_regs[14] = 0xFF;
    psg_reg_select = 0;
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
            if (psg_reg_select == 14 && (psg_regs[14] ^ value) & 0x07) {
                xil_printf("[PSG] PortA: %02X→%02X drv=%c side=%d\r\n",
                           psg_regs[14], value,
                           !(value & 1) ? 'A' : (!(value & 2) ? 'B' : '-'),
                           (value & 4) ? 0 : 1);
            }
            psg_regs[psg_reg_select] = value;
        }
    }
}

int psg_get_drive(void)
{
    uint8_t porta = psg_regs[14];
    if (!(porta & 0x01)) return 0;  /* Drive A selected (active low) */
    if (!(porta & 0x02)) return 1;  /* Drive B selected (active low) */
    return -1;                       /* No drive selected */
}

int psg_get_side(void)
{
    /* Bit 2: 0 = side 1, 1 = side 0 */
    return (psg_regs[14] & 0x04) ? 0 : 1;
}
