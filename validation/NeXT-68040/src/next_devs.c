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
#include "next_kms.h"
#include "next_esp.h"
#include "next_scsi_dma.h"
#include "xil_printf.h"
#include "xiltimer.h"
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

/* P_MON register: the ROM stores its mon_global pointer here */
static uint32_t p_mon_value;

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
/* Hardclock timer (matches Previous's sysReg.c model)                 */
/* ------------------------------------------------------------------ */
static uint8_t  hardclock0;         /* staging high byte (written at P_TIMER)   */
static uint8_t  hardclock1;         /* staging low byte  (written at P_TIMER+1) */
static uint8_t  hardclock_csr;      /* CSR: bit 7=ENABLE, bit 6=LATCH          */
static int      latch_hardclock;    /* latched period in microseconds           */
static int      hardclock_accum;    /* accumulated microseconds toward next IRQ */

/* Accumulated fractional cycles for hardclock (1 MHz from 25 MHz CPU) */
static int timer_accum;
#define TIMER_PRESCALE  25  /* 25 MHz / 25 = 1 MHz timer tick */

#define HARDCLOCK_ENABLE 0x80
#define HARDCLOCK_LATCH  0x40

/* Event counter — real-time microseconds via ARM hardware timer.
 * Like Previous's host_time_us(), this advances continuously
 * regardless of emulation batch boundaries. */
static XTime eventc_epoch;          /* ARM timer value at emulator start        */
static uint32_t event_latch;        /* snapshot taken when eventc_latch is read */

static uint32_t host_time_us(void)
{
    XTime now;
    XTime_GetTime(&now);
    /* COUNTS_PER_SECOND = 33333000, so divide by ~33.333 for microseconds */
    return (uint32_t)((now - eventc_epoch) / (COUNTS_PER_SECOND / 1000000));
}

/* ------------------------------------------------------------------ */
/* DMA register scratchpad — generic read/write backing for all DMA    */
/* channel registers (0x02004000-0x020043FF).  The kernel's DMA_W      */
/* macro retries writes until readback matches, so all DMA addresses   */
/* must be read/write.  SCSI channel (0x0200400x-0x0200421x) has       */
/* dedicated handling; all others use this scratchpad.                  */
/* ------------------------------------------------------------------ */
#define DMA_SCRATCH_SIZE  0x400  /* covers 0x02004000-0x020043FF */
static uint32_t dma_scratch[DMA_SCRATCH_SIZE / 4];

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

    /* P_MON: ROM stores mon_global pointer here */
    p_mon_value = 0;

    /* Interrupts: all masked */
    intr_mask = 0;
    intr_status = 0;

    /* SCC */
    scc_rx_head = scc_rx_tail = 0;
    scc_wr_reg_ptr = 0;

    /* Hardclock timer */
    hardclock0 = 0;
    hardclock1 = 0;
    hardclock_csr = 0;
    latch_hardclock = 0;
    hardclock_accum = 0;
    timer_accum = 0;

    /* Event counter: capture ARM timer epoch */
    XTime_GetTime(&eventc_epoch);
    event_latch = 0;

    /* DMA: all channels idle + complete */
    memset(dma_csr, 0, sizeof(dma_csr));
    for (int i = 0; i < NUM_DMA_CHANNELS; i++)
        dma_csr[i] = DMACSR_COMPLETE;

    /* ESP (NCR53C90) SCSI controller */
    next_esp_init();
    next_scsi_dma_init();
}

/* ------------------------------------------------------------------ */
/* SCC serial helpers                                                  */
/* ------------------------------------------------------------------ */

int next_scc_rx_push(uint8_t ch)
{
    int next = (scc_rx_head + 1) % SCC_RXBUF_SIZE;
    if (next == scc_rx_tail) {
        static int drop_count = 0;
        if (drop_count < 5)
            xil_printf("[SCC] WARNING: RX buffer full, byte $%02X dropped\r\n", ch);
        drop_count++;
        return -1;
    }
    scc_rxbuf[scc_rx_head] = ch;
    scc_rx_head = next;
    return 0;
}

int next_scc_rx_available(void)
{
    return scc_rx_head != scc_rx_tail;
}

uint8_t next_scc_rx_pop(void)
{
    if (!next_scc_rx_available())
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
    /* Convert CPU cycles to microseconds (25 MHz → 1 MHz) */
    timer_accum += cycles;
    int usecs = timer_accum / TIMER_PRESCALE;
    timer_accum %= TIMER_PRESCALE;

    if (usecs == 0)
        return 0;

    /* Periodic hardclock interrupt */
    if ((hardclock_csr & HARDCLOCK_ENABLE) && latch_hardclock > 0) {
        hardclock_accum += usecs;
        if (hardclock_accum >= latch_hardclock) {
            hardclock_accum %= latch_hardclock;
            intr_status |= I_IPL6_TIMER;
            return 1;
        }
    }
    return 0;
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
/* Interrupt set/clear (used by ESP and DMA modules)                    */
/* ------------------------------------------------------------------ */

void next_intr_set(uint32_t bit)   { intr_status |= bit; }
void next_intr_clear(uint32_t bit) { intr_status &= ~bit; }
uint32_t next_intr_get_status(void) { return intr_status; }
uint32_t next_intr_get_mask(void) { return intr_mask; }

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
                if (next_scc_rx_available())
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
            return next_scc_rx_pop();
        case SCC_CHAN_B_CTRL:
            return SCC_RR0_TX_EMPTY;  /* channel B: TX ready, no RX */
        case SCC_CHAN_B_DATA:
            return 0;
        }
    }

    /* ESP/SCSI registers (byte-wide): 0x02014000-0x0201400F */
    if (address >= P_SCSI && address < P_SCSI + 0x10)
        return next_esp_read(address - P_SCSI);

    /* ESP DMA control/status: 0x02014020-0x02014021 */
    if (address == 0x02014020)
        return next_esp_dma_ctrl_read();
    if (address == 0x02014021)
        return next_esp_dma_status_read();

    /* Printer (NeXTlaser): 0x0200F000-0x0200F003 (byte CSRs) */
    if (address >= 0x0200F000 && address <= 0x0200F003)
        return 0;

    /* Floppy controller (Intel 82077AA): 0x02014100-0x02014108
     * Return "no floppy, controller ready" so the driver doesn't hang
     * waiting for hardware that doesn't exist. */
    if (address >= 0x02014100 && address <= 0x02014108) {
        static int flp_log = 0;
        if (flp_log < 10) {
            xil_printf("[FLP] R8 @%08X → 0\r\n", address);
            flp_log++;
        }
        if (address == 0x02014104)
            return 0x80;  /* MSR: RQM=1 (ready), no data direction */
        return 0;
    }

    /* DSP registers (byte-wide) */
    if (address >= P_DSP_BASE && address < P_DSP_BASE + P_DSP_SIZE)
        return next_dsp_read(address - P_DSP_BASE);

    /* Brightness (byte-wide) */
    if (address == P_BRIGHTNESS)
        return 0x3D;  /* max brightness */

    /* Hardclock timer byte reads */
    if (address == P_TIMER)
        return hardclock0;
    if (address == P_TIMER + 1)
        return hardclock1;
    if (address == P_TIMER_CSR) {
        /* Reading CSR clears timer interrupt (kernel does this in us_timer_int) */
        uint8_t val = hardclock_csr;
        intr_status &= ~I_IPL6_TIMER;
        return val;
    }

    /* Event counter (byte reads): reading byte 0 latches the counter.
     * Kernel reads: latch=byte0, then (byte1<<16)|(byte2<<8)|byte3.
     *
     * The kernel's event_get() masks to 20 bits (EVENT_MASK=0xFFFFF) and
     * extends to 32 bits via software (event_sync in timer interrupt).
     * At IPL=7 (no timer interrupts), event_sync can't run and the 20-bit
     * counter wrapping after ~1 second causes event_get() to malfunction.
     *
     * Fix: store the full 32-bit microsecond count. Byte 0 gets the top
     * byte (bits 31-24). The kernel's event_get reads bytes 1-3 giving
     * 24 bits, masks to 20. But the kernel's *event_middle variable
     * (updated by event_sync) tracks bits 31-20. When event_sync runs
     * (IPL<7), it reads byte 0 as the latch and sees the hardware advance.
     * When it can't run (IPL=7), the delay is typically short enough
     * (<1 second) that the 20-bit window doesn't wrap.
     *
     * Previous also returns & 0xFFFFF, but on Previous the emulated CPU
     * is fast enough that DELAY loops complete before wrapping. */
    if (address == P_EVENTC) {
        event_latch = host_time_us();
        return (event_latch >> 24) & 0xFF;  /* byte 0: bits 31-24 */
    }
    if (address == P_EVENTC + 1)
        return (event_latch >> 16) & 0xFF;  /* eventc_h: bits 23-16 */
    if (address == P_EVENTC + 2)
        return (event_latch >> 8) & 0xFF;   /* eventc_m: bits 15-8 */
    if (address == P_EVENTC + 3)
        return event_latch & 0xFF;           /* eventc_l: bits 7-0 */

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

    {
        static int unknown8_log = 0;
        if (unknown8_log < 20) {
            xil_printf("[IO] Unknown read8 $%08X\r\n", address);
            unknown8_log++;
        }
    }
    return 0;
}

uint16_t next_io_read_16(uint32_t address)
{
    address = next_io_canon(address);

    /* Hardclock timer (16-bit read returns latched period) */
    if (address == P_TIMER)
        return (uint16_t)latch_hardclock;

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

    /* Printer data register (32-bit) */
    if (address == 0x0200F004)
        return 0;

    /* P_MON / KMS: $0200E000-$0200E00F is the keyboard/mouse/sound chip. */
    if (address >= P_MON && address < P_MON + 16) {
        static int pmon_log = 0;
        if (pmon_log < 5)
            xil_printf("[PMON] R32 @%08X → KMS offset %X\r\n", address, address - P_MON);
        pmon_log++;
        return next_kms_read(address - P_MON);
    }

    /* Slot ID */
    if (address == P_SID)
        return 0;

    /* Event counter (microseconds) — 32-bit read latches + returns full value */
    if (address == P_EVENTC)
        return host_time_us();

    /* DMA registers: 0x02004000-0x020043FF — all channels */
    if (address >= 0x02004000 && address < 0x02004400) {
        uint32_t off = address & 0x3FF;
        /* SCSI channel: dedicated handler for active regs + init */
        if (off <= 0x01C || off == 0x210)
            return next_scsi_dma_reg_read(address);
        /* All other channels: generic scratchpad */
        return dma_scratch[off >> 2];
    }

    /* DMA CSRs: return idle + complete */
    {
        int ch = dma_channel_for_addr(address);
        if (ch >= 0) {
            /* SCSI channel: use dedicated DMA module */
            if (ch == 0)
                return next_scsi_dma_csr_read();
            return dma_csr[ch];
        }
    }

    /* DSP registers (32-bit) */
    if (address >= P_DSP_BASE && address < P_DSP_BASE + P_DSP_SIZE)
        return next_dsp_read32(address - P_DSP_BASE);

    /* Unknown 32-bit I/O read */
    {
        static int unk_log = 0;
        if (unk_log < 20)
            xil_printf("[IO?] R32 @%08X → 0\r\n", address);
        unk_log++;
    }
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

    /* ESP/SCSI registers (byte-wide): 0x02014000-0x0201400F */
    if (address >= P_SCSI && address < P_SCSI + 0x10) {
        next_esp_write(address - P_SCSI, value);
        return;
    }

    /* ESP DMA control/status: 0x02014020-0x02014021 */
    if (address == 0x02014020) {
        next_esp_dma_ctrl_write(value);
        return;
    }
    if (address == 0x02014021) {
        next_esp_dma_status_write(value);
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

    /* Hardclock timer byte writes */
    if (address == P_TIMER) {
        hardclock0 = value;
        return;
    }
    if (address == P_TIMER + 1) {
        hardclock1 = value;
        return;
    }
    if (address == P_TIMER_CSR) {
        hardclock_csr = value;
        if (hardclock_csr & HARDCLOCK_LATCH) {
            hardclock_csr &= ~HARDCLOCK_LATCH;
            latch_hardclock = (hardclock0 << 8) | hardclock1;
            hardclock_accum = 0;
        }
        if ((hardclock_csr & HARDCLOCK_ENABLE) && latch_hardclock > 0) {
            xil_printf("[TIMER] enable periodic IRQ every %d us\r\n", latch_hardclock);
        }
        /* Writing CSR clears timer interrupt */
        intr_status &= ~I_IPL6_TIMER;
        return;
    }

#ifdef NEXT_IO_DEBUG
    xil_printf("[NEXT] W8 @%08X = %02X\r\n", address, value);
#endif
}

void next_io_write_16(uint32_t address, uint16_t value)
{
    address = next_io_canon(address);

    /* Hardclock timer (16-bit write: high/low bytes) */
    if (address == P_TIMER) {
        hardclock0 = (value >> 8) & 0xFF;
        hardclock1 = value & 0xFF;
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
        static int scr2_log_count = 0;
        if (scr2_log_count < 3) {
            xil_printf("[SCR2] W32 $%08X (RTCE=%d RTCLK=%d RTDATA=%d)\r\n",
                       value,
                       (value >> 8) & 1,   /* SCR2_RTCE */
                       (value >> 9) & 1,   /* SCR2_RTCLK */
                       (value >> 10) & 1); /* SCR2_RTDATA */
            scr2_log_count++;
        }
        next_rtc_scr2_write(value, scr2_value);
        scr2_value = value;
        return;
    }

    /* Interrupt mask */
    if (address == P_INTRMASK) {
        intr_mask = value;
        return;
    }

    /* DMA registers: 0x02004000-0x020043FF — all channels */
    if (address >= 0x02004000 && address < 0x02004400) {
        uint32_t off = address & 0x3FF;
        /* Non-SCSI channels: generic scratchpad */
        if (off > 0x01C && off != 0x210) {
            dma_scratch[off >> 2] = value;
            return;
        }
        /* SCSI channel: dedicated handler */
        next_scsi_dma_reg_write(address, value);
        return;
    }

    /* DMA CSRs: handle reset + enable commands */
    {
        int ch = dma_channel_for_addr(address);
        if (ch >= 0) {
            /* SCSI channel: use dedicated DMA module */
            if (ch == 0) {
                next_scsi_dma_csr_write(value);
                return;
            }
            if (value & DMACSR_RESET)
                dma_csr[ch] = DMACSR_COMPLETE;
            else if (value & 0x00080000)  /* CLRCOMPLETE */
                dma_csr[ch] &= ~DMACSR_COMPLETE;
            /* Auto-complete: when DMA is enabled on non-SCSI channels,
             * immediately set COMPLETE since no real transfer occurs.
             * Without this, the sound driver polls forever for DMA done. */
            if (value & 0x00010000)  /* SETENABLE */
                dma_csr[ch] |= DMACSR_COMPLETE;
            return;
        }
    }

    /* P_MON / KMS: the ROM uses this for both mon_global storage and
     * KMS commands.  First write is typically the mon_global pointer. */
    if (address >= P_MON && address < P_MON + 16) {
        if (address == P_MON && p_mon_value == 0 && value >= 0x0B000000) {
            /* First write: ROM storing mon_global pointer */
            p_mon_value = value;
            xil_printf("[NEXT] P_MON (mon_global) = $%08X\r\n", value);
        }
        next_kms_write(address - P_MON, value);
        return;
    }

    /* Timer CSR via 32-bit write */
    if (address == P_TIMER_CSR) {
        /* Treat as byte write of high byte */
        next_io_write_8(P_TIMER_CSR, (value >> 24) & 0xFF);
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

uint32_t next_get_mon_global(void) { return p_mon_value; }
