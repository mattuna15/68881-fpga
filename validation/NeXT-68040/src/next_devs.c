/*
 * next_devs.c
 * NeXT hardware device emulation stubs for 68040LC kernel boot.
 *
 * Emulates:
 *   - SCR1/SCR2 (system control registers)
 *   - Interrupt mask/status
 *   - SCC serial channel A (console TX/RX)
 *   - Timer and event counter
 *   - DMA CSRs (stub: return COMPLETE, accept writes)
 *   - All other I/O: accept writes silently, reads return 0
 */

#include "next_devs.h"
#include "next_hw.h"
#include "next_rtc.h"
#include "next_dsp.h"
#include "xil_printf.h"
#include <string.h>

/* DSP register block at P_DSP (0x02008000 canonical).
 * The NeXT maps the DSP56001 host interface (8 bytes) plus
 * the DSP's external program/data memory space (up to 4K). */
#define P_DSP_BASE  0x02008000
#define P_DSP_SIZE  0x1000  /* 4K covers host regs + mapped memory */

/* ------------------------------------------------------------------ */
/* System control registers                                            */
/* ------------------------------------------------------------------ */
static uint32_t scr1_value;
static uint32_t scr2_value;

/* ------------------------------------------------------------------ */
/* Interrupt controller                                                */
/* ------------------------------------------------------------------ */
static uint32_t intr_mask;   /* writable mask register */
static uint32_t intr_status; /* pending interrupt bits */

/* ------------------------------------------------------------------ */
/* SCC serial (Zilog 8530) — channel A only for console                */
/* ------------------------------------------------------------------ */
#define SCC_RXBUF_SIZE  256
static uint8_t scc_rxbuf[SCC_RXBUF_SIZE];
static volatile int scc_rx_head, scc_rx_tail;
static uint8_t scc_wr_reg_ptr;  /* WR register pointer (set by ctrl write) */

/* ------------------------------------------------------------------ */
/* Timer                                                               */
/* ------------------------------------------------------------------ */
static uint16_t timer_counter;
static uint8_t  timer_csr;
static uint32_t event_counter;  /* microsecond counter */

/* Accumulated fractional cycles for timer (1 MHz from 25 MHz CPU) */
static int timer_accum;
#define TIMER_PRESCALE  25  /* 25 MHz / 25 = 1 MHz timer tick */

/* ------------------------------------------------------------------ */
/* DMA CSR shadow (per-channel, just tracks enable/complete)           */
/* ------------------------------------------------------------------ */
#define NUM_DMA_CHANNELS  16
static uint32_t dma_csr[NUM_DMA_CHANNELS];

/* Map DMA CSR address to channel index (0-15), or -1 if not a DMA CSR */
static int dma_channel_for_addr(uint32_t addr)
{
    /* DMA CSRs are at offsets 0x10, 0x40, 0x50, 0x80, 0x90, 0xC0, 0xD0,
     * 0x110, 0x150, 0x180, 0x1C0, 0x1D0 from 0x02000000 */
    uint32_t off = addr - 0x02000000;
    switch (off) {
    case 0x010: return 0;   /* SCSI */
    case 0x040: return 1;   /* Sound out */
    case 0x050: return 2;   /* Disk */
    case 0x080: return 3;   /* Sound in */
    case 0x090: return 4;   /* Printer */
    case 0x0C0: return 5;   /* SCC */
    case 0x0D0: return 6;   /* DSP */
    case 0x110: return 7;   /* Ethernet TX */
    case 0x150: return 8;   /* Ethernet RX */
    case 0x180: return 9;   /* Video */
    case 0x1C0: return 10;  /* R2M */
    case 0x1D0: return 11;  /* M2R */
    default:    return -1;
    }
}

/* ------------------------------------------------------------------ */
/* Initialisation                                                      */
/* ------------------------------------------------------------------ */

void next_devs_init(void)
{
    /* SCR1: NeXT_WARP9 (68040 NeXTstation), board rev 0, 25 MHz */
    scr1_value = SCR1_VALUE(NeXT_WARP9, 0);

    /* SCR2: zeroed at power-on, 4x1M DRAM banks */
    scr2_value = (0x0F << 16);  /* s_dram_1M = 4 banks */

    /* Interrupts: all masked */
    intr_mask = 0;
    intr_status = 0;

    /* SCC */
    scc_rx_head = scc_rx_tail = 0;
    scc_wr_reg_ptr = 0;

    /* Timer */
    timer_counter = 0;
    timer_csr = 0;
    timer_accum = 0;
    event_counter = 0;

    /* DMA: all channels idle + complete */
    memset(dma_csr, 0, sizeof(dma_csr));
    for (int i = 0; i < NUM_DMA_CHANNELS; i++)
        dma_csr[i] = DMACSR_COMPLETE;
}

/* ------------------------------------------------------------------ */
/* SCC serial helpers                                                  */
/* ------------------------------------------------------------------ */

int next_scc_rx_push(uint8_t ch)
{
    int next = (scc_rx_head + 1) % SCC_RXBUF_SIZE;
    if (next == scc_rx_tail)
        return -1;  /* buffer full */
    scc_rxbuf[scc_rx_head] = ch;
    scc_rx_head = next;
    return 0;
}

static int scc_rx_available(void)
{
    return scc_rx_head != scc_rx_tail;
}

static uint8_t scc_rx_pop(void)
{
    if (!scc_rx_available())
        return 0;
    uint8_t ch = scc_rxbuf[scc_rx_tail];
    scc_rx_tail = (scc_rx_tail + 1) % SCC_RXBUF_SIZE;
    return ch;
}

/* ------------------------------------------------------------------ */
/* Timer                                                               */
/* ------------------------------------------------------------------ */

int next_timer_tick(int cycles)
{
    /* Advance event counter (microseconds at 25 MHz) */
    event_counter += cycles / 25;

    if (!(timer_csr & TIMER_ENABLE))
        return 0;

    timer_accum += cycles;
    int fired = 0;
    while (timer_accum >= TIMER_PRESCALE) {
        timer_accum -= TIMER_PRESCALE;
        if (timer_counter == 0) {
            timer_counter = TIMER_MAX;
            fired = 1;
            intr_status |= I_IPL6_TIMER;
        } else {
            timer_counter--;
        }
    }
    return fired;
}

/* ------------------------------------------------------------------ */
/* Interrupt controller                                                */
/* ------------------------------------------------------------------ */

int next_intr_pending_ipl(void)
{
    uint32_t pending = intr_status & intr_mask;
    if (!pending)
        return 0;

    /* IPL7: NMI, power fail, timer (if SCR2 TIMERIPL7 set) */
    if (pending & (I_IPL7_NMI | I_IPL7_PFAIL))
        return 7;
    if ((scr2_value & SCR2_TIMERIPL7) && (pending & I_IPL6_TIMER))
        return 7;

    /* IPL6: DMA completions, timer */
    if (pending & 0x3FFC0000)  /* bits 29-18 */
        return 6;

    /* IPL5: SCC, remote, bus */
    if (pending & (I_IPL5_SCC | I_IPL5_REMOTE | I_IPL5_BUS))
        return 5;

    /* IPL4: DSP */
    if (pending & I_IPL4_DSP)
        return 4;

    /* IPL3: devices */
    if (pending & 0x00003FFC)  /* bits 13-2 */
        return 3;

    /* IPL2: softint1 */
    if (pending & I_IPL2_SOFTINT1)
        return 2;

    /* IPL1: softint0 */
    if (pending & I_IPL1_SOFTINT0)
        return 1;

    return 0;
}

int next_intr_acknowledge(int level)
{
    (void)level;
    return -1;  /* autovector */
}

/* ------------------------------------------------------------------ */
/* I/O read handlers                                                   */
/* ------------------------------------------------------------------ */

uint8_t next_io_read_8(uint32_t address)
{
    address = next_io_canon(address);

    /* SCC registers (byte-wide) */
    if (address >= P_SCC && address < P_SCC + 4) {
        uint32_t off = address - P_SCC;
        switch (off) {
        case SCC_CHAN_A_CTRL: {
            /* Read Register selected by scc_wr_reg_ptr (set by prior ctrl write) */
            uint8_t val = 0;
            switch (scc_wr_reg_ptr) {
            case 0: /* RR0: TX/RX status */
                val = SCC_RR0_TX_EMPTY | SCC_RR0_DCD | SCC_RR0_CTS;
                if (scc_rx_available())
                    val |= SCC_RR0_RX_AVAIL;
                break;
            case 1: /* RR1: special receive conditions — all bits clear = OK */
                val = 0x07; /* All Sent + no errors */
                break;
            case 2: /* RR2: interrupt vector (channel B returns modified) */
                val = 0;
                break;
            default:
                val = 0;
                break;
            }
            scc_wr_reg_ptr = 0;  /* auto-reset to RR0 after read */
            return val;
        }
        case SCC_CHAN_A_DATA:
            return scc_rx_pop();
        case SCC_CHAN_B_CTRL:
            return SCC_RR0_TX_EMPTY;  /* channel B: TX ready, no RX */
        case SCC_CHAN_B_DATA:
            return 0;
        }
    }

    /* DSP registers (byte-wide) */
    if (address >= P_DSP_BASE && address < P_DSP_BASE + P_DSP_SIZE)
        return next_dsp_read(address - P_DSP_BASE);

    /* Brightness (byte-wide) */
    if (address == P_BRIGHTNESS)
        return 0x3D;  /* max brightness */

    /* Fall through: decompose wider registers to byte reads */
    if (address >= P_EVENTC && address < P_EVENTC + 4) {
        uint32_t val = event_counter;
        int byte_off = address - P_EVENTC;
        return (val >> (8 * (3 - byte_off))) & 0xFF;
    }

    /* SCR1 (byte-level access) */
    if (address >= P_SCR1 && address < P_SCR1 + 4) {
        int byte_off = address - P_SCR1;
        return (scr1_value >> (8 * (3 - byte_off))) & 0xFF;
    }

    /* SCR2 (byte-level access) */
    if (address >= P_SCR2 && address < P_SCR2 + 4) {
        int byte_off = address - P_SCR2;
        return (scr2_value >> (8 * (3 - byte_off))) & 0xFF;
    }

    return 0;
}

uint16_t next_io_read_16(uint32_t address)
{
    address = next_io_canon(address);

    /* Timer counter (16-bit) */
    if (address == P_TIMER)
        return timer_counter;

    /* SCC: decompose to byte reads */
    if (address >= P_SCC && address < P_SCC + 4)
        return ((uint16_t)next_io_read_8(address) << 8) |
                next_io_read_8(address + 1);

    return 0;
}

uint32_t next_io_read_32(uint32_t address)
{
    address = next_io_canon(address);

    /* SCR1 — the first thing the kernel reads */
    if (address == P_SCR1)
        return scr1_value;

    /* SCR2 — let RTC module inject RTDATA for bit-bang reads */
    if (address == P_SCR2)
        return next_rtc_scr2_read(scr2_value);

    /* Interrupt status */
    if (address == P_INTRSTAT)
        return intr_status;

    /* Interrupt mask */
    if (address == P_INTRMASK)
        return intr_mask;

    /* Slot ID */
    if (address == P_SID)
        return 0;

    /* Event counter (microseconds) */
    if (address == P_EVENTC)
        return event_counter;

    /* DMA CSRs: return idle + complete */
    {
        int ch = dma_channel_for_addr(address);
        if (ch >= 0)
            return dma_csr[ch];
    }

    /* DSP registers (32-bit) */
    if (address >= P_DSP_BASE && address < P_DSP_BASE + P_DSP_SIZE)
        return next_dsp_read32(address - P_DSP_BASE);

    /* Unknown 32-bit I/O read */
#ifdef NEXT_IO_DEBUG
    xil_printf("[NEXT] R32 @%08X → 0\r\n", address);
#endif
    return 0;
}

/* ------------------------------------------------------------------ */
/* I/O write handlers                                                  */
/* ------------------------------------------------------------------ */

void next_io_write_8(uint32_t address, uint8_t value)
{
    address = next_io_canon(address);

    /* SCC channel A */
    if (address >= P_SCC && address < P_SCC + 4) {
        uint32_t off = address - P_SCC;
        switch (off) {
        case SCC_CHAN_A_CTRL:
            /* First write sets register pointer, subsequent writes go
             * to that register. We only care about accepting writes. */
            scc_wr_reg_ptr = value & 0x07;
            break;
        case SCC_CHAN_A_DATA:
            /* Console TX: send to ARM UART */
            if (value >= 0x20 && value < 0x7F)
                xil_printf("%c", value);
            else if (value == '\r' || value == '\n' ||
                     value == '\t' || value == '\b')
                xil_printf("%c", value);
            else if (value == 0x07)
                { /* BEL: ignore */ }
            else if (value == 0x1B)
                { /* ESC: ignore (part of ANSI sequences) */ }
            else
                xil_printf("[SCC:$%02X]", value);
            break;
        case SCC_CHAN_B_CTRL:
        case SCC_CHAN_B_DATA:
            break;  /* channel B: accept silently */
        }
        return;
    }

    /* DSP registers (byte-wide) */
    if (address >= P_DSP_BASE && address < P_DSP_BASE + P_DSP_SIZE) {
        next_dsp_write(address - P_DSP_BASE, value);
        return;
    }

    /* Brightness: accept silently */
    if (address == P_BRIGHTNESS)
        return;

    /* Timer CSR (byte-wide) */
    if (address == P_TIMER_CSR || address == (P_TIMER_CSR + 1)) {
        timer_csr = value;
        if (value & TIMER_UPDATE) {
            /* Latch → counter update: no-op in emulation */
        }
        return;
    }

#ifdef NEXT_IO_DEBUG
    xil_printf("[NEXT] W8 @%08X = %02X\r\n", address, value);
#endif
}

void next_io_write_16(uint32_t address, uint16_t value)
{
    address = next_io_canon(address);

    /* Timer counter (16-bit) */
    if (address == P_TIMER) {
        timer_counter = value;
        return;
    }

    /* SCC: decompose to byte writes */
    if (address >= P_SCC && address < P_SCC + 4) {
        next_io_write_8(address, (value >> 8) & 0xFF);
        next_io_write_8(address + 1, value & 0xFF);
        return;
    }

#ifdef NEXT_IO_DEBUG
    xil_printf("[NEXT] W16 @%08X = %04X\r\n", address, value);
#endif
}

void next_io_write_32(uint32_t address, uint32_t value)
{
    address = next_io_canon(address);

    /* SCR2 — feed RTC bit-bang state machine before updating */
    if (address == P_SCR2) {
        next_rtc_scr2_write(value, scr2_value);
        scr2_value = value;
        return;
    }

    /* Interrupt mask */
    if (address == P_INTRMASK) {
        intr_mask = value;
        return;
    }

    /* DMA CSRs: handle reset + enable commands */
    {
        int ch = dma_channel_for_addr(address);
        if (ch >= 0) {
            if (value & DMACSR_RESET)
                dma_csr[ch] = DMACSR_COMPLETE;
            else if (value & 0x00080000)  /* CLRCOMPLETE */
                dma_csr[ch] &= ~DMACSR_COMPLETE;
            return;
        }
    }

    /* Timer CSR via 32-bit write */
    if (address == P_TIMER_CSR) {
        timer_csr = (value >> 24) & 0xFF;
        return;
    }

    /* DSP registers (32-bit) */
    if (address >= P_DSP_BASE && address < P_DSP_BASE + P_DSP_SIZE) {
        next_dsp_write32(address - P_DSP_BASE, value);
        return;
    }

#ifdef NEXT_IO_DEBUG
    xil_printf("[NEXT] W32 @%08X = %08X\r\n", address, value);
#endif
}
