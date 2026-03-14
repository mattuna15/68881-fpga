/*
 * mfp_emu.c
 * MC68901 MFP emulation — USART redirects to text framebuffer.
 *
 * The BIOS ROM polls MFPTSR bit 7 (TX buffer empty) then writes
 * a character to MFPUDR.  We always report TX ready and redirect
 * written characters to text_fb_putc().
 *
 * For RX, characters pushed via mfp_rx_push() (from ARM UART)
 * are buffered in a circular queue.  MFPRSR bit 7 indicates data
 * available; reading MFPUDR dequeues a byte.
 */

#include "mfp_emu.h"
#include "text_fb.h"
#include "xil_printf.h"
#include "xiltimer.h"

/* Shadow registers — most are don't-care, just store writes */
static uint8_t mfp_regs[MFP_SIZE];

/* Millisecond tick counter baseline */
static XTime mfp_time_base;

/* UART RX circular buffer */
#define RX_BUF_SIZE 256
static uint8_t rx_buf[RX_BUF_SIZE];
static volatile unsigned int rx_head;   /* write index */
static volatile unsigned int rx_tail;   /* read index */

void mfp_init(void)
{
    int i;
    for (i = 0; i < MFP_SIZE; i++)
        mfp_regs[i] = 0;

    rx_head = 0;
    rx_tail = 0;

    /* TSR: bit 7 (buffer empty) always starts set */
    mfp_regs[MFP_OFF_TSR] = 0x80;

    /* Latch ARM timer baseline for ms tick counter */
    XTime_GetTime(&mfp_time_base);
}

int mfp_rx_has_data(void)
{
    return rx_head != rx_tail;
}

int mfp_rx_push(uint8_t ch)
{
    unsigned int next = (rx_head + 1) % RX_BUF_SIZE;
    if (next == rx_tail)
        return -1;  /* full */
    rx_buf[rx_head] = ch;
    rx_head = next;
    return 0;
}

static uint8_t rx_pop(void)
{
    if (rx_head == rx_tail)
        return 0;
    uint8_t ch = rx_buf[rx_tail];
    rx_tail = (rx_tail + 1) % RX_BUF_SIZE;
    return ch;
}

uint8_t mfp_read(uint32_t offset)
{
    if (offset >= MFP_SIZE) {
        xil_printf("[MFP] BUG: read offset 0x%02X out of range\r\n", offset);
        return 0;
    }

    switch (offset) {
    case MFP_OFF_TSR:
        /* Transmit buffer is always empty (instant TX) */
        return 0x80;

    case MFP_OFF_RSR:
        /* Bit 7: buffer full (data available) */
        return mfp_rx_has_data() ? 0x80 : 0x00;

    case MFP_OFF_UDR:
        /* Read = dequeue from RX buffer */
        return rx_pop();

    case MFP_OFF_TICK:
    case MFP_OFF_TICK + 1:
    case MFP_OFF_TICK + 2:
    case MFP_OFF_TICK + 3: {
        /* 32-bit ms tick counter (big-endian), derived from ARM physical timer */
        XTime now;
        XTime_GetTime(&now);
        uint32_t ms = (uint32_t)((now - mfp_time_base) / (COUNTS_PER_SECOND / 1000));
        int shift = (3 - (offset - MFP_OFF_TICK)) * 8;
        return (ms >> shift) & 0xFF;
    }

    default:
        return mfp_regs[offset];
    }
}

void mfp_write(uint32_t offset, uint8_t value)
{
    if (offset >= MFP_SIZE) {
        xil_printf("[MFP] BUG: write offset 0x%02X out of range\r\n", offset);
        return;
    }

    switch (offset) {
    case MFP_OFF_UDR:
        /* Character output — redirect to text framebuffer */
        text_fb_putc((char)value);
        /* Also echo to ARM UART for debug */
        outbyte(value);
        break;

    default:
        /* Store silently for any register the BIOS configures */
        mfp_regs[offset] = value;
        break;
    }
}
