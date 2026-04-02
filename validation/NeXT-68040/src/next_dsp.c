/*
 * next_dsp.c
 * Motorola DSP56001 host interface register emulation.
 *
 * Register map (from mk-108.1 nextdev/snd_dspreg.h):
 *
 *   Offset 0: ICR — Interface Control Register
 *     bit 7: ICR_INIT  (0x80) — initialise DSP
 *     bit 1: ICR_TREQ  (0x02) — transmit request
 *     bit 0: ICR_RREQ  (0x01) — receive request
 *
 *   Offset 1: CVR — Command Vector Register
 *     bit 7: CVR_HC    (0x80) — host command
 *
 *   Offset 2: ISR — Interface Status Register (read-only)
 *     bit 7: ISR_HREQ  (0x80) — host request
 *     bit 6: ISR_DMA   (0x40) — DMA status
 *     bit 4: ISR_HF3   (0x10) — host flag 3
 *     bit 3: ISR_HF2   (0x08) — host flag 2  ← ROM waits for this
 *     bit 2: ISR_TRDY  (0x04) — transmit ready
 *     bit 1: ISR_TXDE  (0x02) — transmit data empty
 *     bit 0: ISR_RXDF  (0x01) — receive data full
 *
 *   Offset 3: IVR — Interrupt Vector Register
 *
 *   Offset 4-7: Data register (24-bit packed in 32-bit word)
 *
 * The ROM's dsp_probe() sequence:
 *   1. Write ICR_INIT (0x80) to reset the DSP
 *   2. Delay
 *   3. Write ICR_TREQ (0x02) to request transmit
 *   4. Poll ISR for ISR_HF2 (bit 3) — waits for DSP to acknowledge
 *
 * Backend:
 *   QEMU_MODE  — pure software stub, no real DSP
 *   Hardware   — stub is also fine since the real NeXT DSP56001 isn't
 *                on the AXU3EG board; audio would use ZynqMP I2S instead
 */

#include "next_dsp.h"
#include "xil_printf.h"
#include <string.h>

/* DSP host interface registers */
static uint8_t  dsp_icr;   /* Interface Control Register */
static uint8_t  dsp_cvr;   /* Command Vector Register */
static uint8_t  dsp_isr;   /* Interface Status Register */
static uint8_t  dsp_ivr;   /* Interrupt Vector Register */
static uint32_t dsp_data;  /* Data register (24-bit) */

/* DSP mapped memory space (program/data memory visible to host).
 * The NeXT maps DSP56001 memory at offsets 0x000-0xFFF from P_DSP.
 * Offsets 0x000-0x007 are the host interface registers (handled above).
 * Offsets 0x008-0xFFF are the DSP's external memory. */
#define DSP_MEM_SIZE  0x1000
static uint8_t dsp_mem[DSP_MEM_SIZE];

/* ICR bits */
#define ICR_INIT   0x80
#define ICR_HM1    0x40
#define ICR_HM0    0x20
#define ICR_HF1    0x10
#define ICR_HF0    0x08
#define ICR_TREQ   0x02
#define ICR_RREQ   0x01

/* CVR bits */
#define CVR_HC     0x80

/* ISR bits */
#define ISR_HREQ   0x80
#define ISR_DMA    0x40
#define ISR_HF3    0x10
#define ISR_HF2    0x08
#define ISR_TRDY   0x04
#define ISR_TXDE   0x02
#define ISR_RXDF   0x01

void next_dsp_init(void)
{
    dsp_icr  = 0;
    dsp_cvr  = 0;
    /* DSP comes up with all ready bits set */
    dsp_isr  = ISR_HREQ | ISR_TXDE | ISR_TRDY;
    dsp_ivr  = 0x0F;   /* default vector = 15 */
    dsp_data = 0;
    memset(dsp_mem, 0, sizeof(dsp_mem));

    xil_printf("[DSP] DSP56001 stub initialised\r\n");
}

uint8_t next_dsp_read(uint32_t offset)
{
    switch (offset) {
    case 0: return dsp_icr;
    case 1: return dsp_cvr;
    case 2: return dsp_isr;
    case 3: return dsp_ivr;
    /* Data register bytes (big-endian 24-bit in 32-bit word) */
    case 4: return 0;                       /* pad */
    case 5: return (dsp_data >> 16) & 0xFF; /* high */
    case 6: return (dsp_data >>  8) & 0xFF; /* mid */
    case 7: return (dsp_data >>  0) & 0xFF; /* low */
    default:
        /* DSP mapped memory space */
        if (offset < DSP_MEM_SIZE)
            return dsp_mem[offset];
        return 0;
    }
}

void next_dsp_write(uint32_t offset, uint8_t value)
{
    switch (offset) {
    case 0: /* ICR */
        if ((value & ICR_INIT) && !(dsp_icr & ICR_INIT)) {
            /* ICR_INIT rising edge: reset DSP, set all ready/request bits.
             * The real DSP56001 auto-clears ICR_INIT when reset completes.
             * dsp_probe() spins: while (regs->icr & ICR_INIT) DELAY(1);
             * so we must NOT leave ICR_INIT set. */
            dsp_isr = ISR_HREQ | ISR_TXDE | ISR_TRDY | ISR_HF2 | ISR_HF3;
            dsp_cvr = 0;
            dsp_data = 0;
            value &= ~ICR_INIT;  /* auto-clear: reset is "instant" */
        }
        dsp_icr = value;
        break;

    case 1: /* CVR */
        dsp_cvr = value;
        if (value & CVR_HC) {
            /* Host command: auto-clear HC bit after "processing" */
            dsp_cvr &= ~CVR_HC;
        }
        break;

    case 2: break; /* ISR — read-only, ignore writes */

    case 3: /* IVR */
        dsp_ivr = value | 0x04;  /* keep bit 2 set — ROM polls this */
        break;

    /* Data register bytes (write to TX) */
    case 4: break; /* pad byte */
    case 5: dsp_data = (dsp_data & 0x0000FFFF) | ((uint32_t)value << 16); break;
    case 6: dsp_data = (dsp_data & 0x00FF00FF) | ((uint32_t)value <<  8); break;
    case 7:
        dsp_data = (dsp_data & 0x00FFFF00) | (uint32_t)value;
        /* Writing the low byte completes the TX word — keep TXDE set
         * (we consume it instantly since there's no real DSP) */
        dsp_isr |= ISR_TXDE | ISR_TRDY;
        break;

    default:
        /* DSP mapped memory space */
        if (offset < DSP_MEM_SIZE)
            dsp_mem[offset] = value;
        break;
    }
}

uint32_t next_dsp_read32(uint32_t offset)
{
    if (offset == 4)
        return dsp_data;
    /* Fall back to byte-assembled read */
    uint32_t val = ((uint32_t)next_dsp_read(offset)     << 24) |
                   ((uint32_t)next_dsp_read(offset + 1) << 16) |
                   ((uint32_t)next_dsp_read(offset + 2) <<  8) |
                    (uint32_t)next_dsp_read(offset + 3);
#ifdef NEXT_IO_DEBUG
    static uint32_t last_dsp_r32 = 0xDEAD;
    if (offset == 0 && val != last_dsp_r32) {
        xil_printf("[DSP] R32 @+0 → $%08X (ICR=%02X CVR=%02X ISR=%02X IVR=%02X)\r\n",
                   val, dsp_icr, dsp_cvr, dsp_isr, dsp_ivr);
        last_dsp_r32 = val;
    }
#endif
    return val;
}

void next_dsp_write32(uint32_t offset, uint32_t value)
{
    if (offset == 4) {
        dsp_data = value & 0x00FFFFFF;
        dsp_isr |= ISR_TXDE | ISR_TRDY;
        return;
    }
    if (offset < 8) {
        /* Host interface register block — only write to valid R/W registers.
         * ISR (offset 2) is read-only on the real DSP56001. */
        next_dsp_write(offset, (value >> 24) & 0xFF);       /* ICR */
        if (offset + 1 < 8)
            next_dsp_write(offset + 1, (value >> 16) & 0xFF); /* CVR */
        /* Skip ISR (read-only) and preserve IVR write */
        if (offset + 3 < 8)
            next_dsp_write(offset + 3, (value >> 0) & 0xFF);  /* IVR */
        return;
    }
    /* DSP memory space: full 32-bit write */
    next_dsp_write(offset,     (value >> 24) & 0xFF);
    next_dsp_write(offset + 1, (value >> 16) & 0xFF);
    next_dsp_write(offset + 2, (value >>  8) & 0xFF);
    next_dsp_write(offset + 3, (value >>  0) & 0xFF);
}
