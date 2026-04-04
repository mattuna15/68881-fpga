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
#include "musashi/m68k.h"
#include "next_rtc.h"
#include "next_dsp.h"
#include "next_kms.h"
#include "next_esp.h"
#include "next_scsi_dma.h"
#include "xil_printf.h"

/* Debug toggle — toggled by 'D' keypress in main loop */
int next_debug_scsi = 0;
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

/* PC trace (toggled by 'T' key) */
int next_trace_count = 0;
uint32_t next_eventc_read_count = 0;

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

/* Live 16-bit counter: counts up at 1 MHz (1 µs per tick).
 * The ROM reads this during POST calibration to verify the clock works.
 * We derive it from the host timer so it advances in real time. */
static uint16_t timer_counter;      /* current counter value */

/* Accumulated fractional cycles for hardclock (1 MHz from 25 MHz CPU) */
static int timer_accum;
#define TIMER_PRESCALE  25  /* 25 MHz / 25 = 1 MHz timer tick */

#define HARDCLOCK_ENABLE 0x80
#define HARDCLOCK_LATCH  0x40

/* Event counter — emulated microseconds derived from CPU cycles.
 * The kernel's DELAY() and event_get() use this to measure time.
 * Must advance with emulated CPU time (25 MHz → 1 µs per 25 cycles),
 * NOT wall time, because the emulated CPU runs much faster than real time. */
static uint32_t eventc_us;           /* emulated microseconds counter           */
static uint32_t event_latch;         /* snapshot taken when eventc_latch is read */
static int      eventc_accum;        /* fractional cycle accumulator             */
static int      eventc_batch_base;   /* cycles_run snapshot at last sync         */
#define EVENTC_PRESCALE  25          /* 25 MHz / 25 = 1 MHz (1 µs per tick)     */

/* Sync event counter from within m68k_execute() — call before reading eventc.
 * Uses m68k_cycles_run() to account for cycles elapsed within the current batch
 * that next_timer_tick() hasn't seen yet. */
static uint32_t eventc_synced(void)
{
    int run = m68k_cycles_run();
    int delta = run - eventc_batch_base;
    if (delta < 0) delta = 0;  /* safety: handle batch boundary */
    return eventc_us + (uint32_t)(delta / EVENTC_PRESCALE) * 4096;
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
/* DMA CSR state (per-channel, internal 8-bit state like SCSI DMA)     */
/* ------------------------------------------------------------------ */
#define NUM_DMA_CHANNELS  16
static uint8_t dma_csr[NUM_DMA_CHANNELS];

/* ------------------------------------------------------------------ */
/* ADB (Apple Desktop Bus) stub — Turbo machines use ADB for keyboard  */
/* and mouse via the TMC at $02208xxx.  Without this stub, the kernel  */
/* hangs polling ADB_INTSTATUS waiting for command completion.          */
/* ------------------------------------------------------------------ */
#define ADB_INTSTATUS   0x00
#define ADB_INTMASK     0x08
#define ADB_CMD         0x30
#define ADB_INT_REJECT  0x01  /* no device responded */
static uint32_t adb_intstatus = 0;
static uint32_t adb_intmask = 0;

/* ------------------------------------------------------------------ */
/* Live I/O activity tracker — dump with 'D' to see what CPU accesses  */
/* ------------------------------------------------------------------ */
static struct {
    uint32_t last_addr;
    uint32_t count;
} io_activity[8];
static int io_act_idx = 0;

void io_track(uint32_t addr) {
    for (int i = 0; i < 8; i++) {
        if (io_activity[i].last_addr == addr) {
            io_activity[i].count++;
            return;
        }
    }
    io_activity[io_act_idx].last_addr = addr;
    io_activity[io_act_idx].count = 1;
    io_act_idx = (io_act_idx + 1) % 8;
}

/* Search kernel memory for sf_access_head by finding empty queue_head pattern:
 * two consecutive words where both equal the address of the first word (self-referencing).
 * Then dump the struct following it to show sfah_busy. */
void sfa_dump(void) {
    extern uint8_t next_ram[];
    #define RD32(o) ((uint32_t)((next_ram[o]<<24)|(next_ram[(o)+1]<<16)|(next_ram[(o)+2]<<8)|next_ram[(o)+3]))
    int found = 0;
    /* sf_access_head has: queue_head(8), lock(4), wait_cnt(4), flags(4), last_dev(4), excl_q(4), busy(4)
     * For an empty queue: q.next == q.prev == &q (self-pointer)
     * For a non-empty queue: q.next and q.prev are different kernel pointers */
    for (uint32_t off = 0; off < 0x00200000 && found < 5; off += 4) {
        uint32_t addr = 0x04000000 + off;
        uint32_t w0 = RD32(off);
        uint32_t w1 = RD32(off+4);
        /* Check for self-referencing queue (empty) or two valid kernel pointers */
        if (w0 == addr && w1 == addr) {
            /* Empty queue — both next and prev point to queue head itself.
             * Check that following fields look like sfah (small integers). */
            uint32_t wait_cnt = RD32(off+0x0C);
            uint32_t flags = RD32(off+0x10);
            uint32_t last_dev = RD32(off+0x14);
            uint32_t excl_q = RD32(off+0x18);
            uint32_t busy = RD32(off+0x1C);
            if (wait_cnt < 100 && flags < 100 && last_dev < 100 && excl_q < 100 && busy < 100) {
                xil_printf("[SFA-HEAD] @$%08X: q={self,self} lock=%d wait=%d flags=%d last=%d excl=%d BUSY=%d\r\n",
                           addr, RD32(off+8), wait_cnt, flags, last_dev, excl_q, busy);
                found++;
            }
        }
        /* Also check non-empty queue: two different kernel ptrs, followed by small ints */
        else if (w0 >= 0x04000000 && w0 < 0x04200000 &&
                 w1 >= 0x04000000 && w1 < 0x04200000 && w0 != w1) {
            uint32_t lock = RD32(off+8);
            uint32_t wait_cnt = RD32(off+0x0C);
            uint32_t flags = RD32(off+0x10);
            uint32_t last_dev = RD32(off+0x14);
            uint32_t excl_q = RD32(off+0x18);
            uint32_t busy = RD32(off+0x1C);
            if (lock == 0 && wait_cnt > 0 && wait_cnt < 10 &&
                flags < 10 && last_dev < 10 && excl_q < 10 && busy > 0 && busy < 10) {
                xil_printf("[SFA-HEAD] @$%08X: q={$%08X,$%08X} lock=%d wait=%d flags=%d last=%d excl=%d BUSY=%d\r\n",
                           addr, w0, w1, lock, wait_cnt, flags, last_dev, excl_q, busy);
                found++;
            }
        }
    }
    if (!found)
        xil_printf("[SFA-HEAD] No sf_access_head found in kernel RAM!\r\n");
    #undef RD32
}

void io_activity_dump(void) {
    xil_printf("[IO-ACT] Recent I/O addresses:\r\n");
    for (int i = 0; i < 8; i++) {
        if (io_activity[i].count > 0)
            xil_printf("  $%08X  (%u times)\r\n",
                       io_activity[i].last_addr, io_activity[i].count);
    }
    /* Reset after dump */
    for (int i = 0; i < 8; i++) {
        io_activity[i].last_addr = 0;
        io_activity[i].count = 0;
    }
}

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
/* BMAP chip — 16-register array at P_BMAP (0x020C0000)               */
/* Used for ethernet transceiver control.  The ROM reads several       */
/* registers during POST; returning 0 for all causes a test failure.   */
/* ------------------------------------------------------------------ */
#define BMAP_REG_COUNT      16
static uint32_t bmap_regs[BMAP_REG_COUNT];

#define BMAP_DATA_RW        0xD     /* register index for ethernet data */
#define BMAP_HEARTBEAT      0x20000000

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
    timer_counter = 0;

    /* Event counter */
    eventc_us = 0;
    eventc_accum = 0;
    event_latch = 0;

    /* DMA: all channels idle + complete (internal 8-bit state) */
    memset(dma_csr, 0, sizeof(dma_csr));
    for (int i = 0; i < NUM_DMA_CHANNELS; i++)
        dma_csr[i] = 0x08;  /* DMA_COMPLETE */

    /* BMAP chip */
    memset(bmap_regs, 0, sizeof(bmap_regs));
    /* Set HEARTBEAT in data register — indicates thin-wire ethernet
     * is connected (no twisted pair). Without this, ROM POST fails. */
    bmap_regs[BMAP_DATA_RW] = BMAP_HEARTBEAT;

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

    /* Advance the live 16-bit counter (1 µs per tick) */
    timer_counter += (uint16_t)usecs;

    /* Advance the event counter (used by kernel DELAY/event_get).
     * Multiplied by 4096 to speed up the bit-19 boundary check used by
     * this kernel's event_timeout(). Without this, each scsi_pollcmd
     * timeout takes ~500 seconds (bit-19 = 524288 µs per check).
     * With 4096x speedup, it takes ~0.13 seconds. The timer (hardclock)
     * uses a separate counter and is NOT affected. */
    eventc_us += usecs * 4096;
    eventc_batch_base = 0;  /* reset: next batch starts from 0 */

    /* Periodic hardclock interrupt */
    if ((hardclock_csr & HARDCLOCK_ENABLE) && latch_hardclock > 0) {
        hardclock_accum += usecs;
        if (hardclock_accum >= latch_hardclock) {
            hardclock_accum %= latch_hardclock;
            next_intr_set(I_IPL6_TIMER);
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
    return -1;  /* autovector */
}

/* ------------------------------------------------------------------ */
/* Interrupt set/clear (used by ESP and DMA modules)                    */
/* ------------------------------------------------------------------ */

void next_intr_set(uint32_t bit)
{
    extern int next_debug_scsi;
    intr_status |= bit;
    /* For SCSI interrupts: defer m68k_set_irq to the main loop tick.
     * Our synchronous ESP model completes commands instantly during the
     * register write instruction. If we deliver the interrupt immediately,
     * it fires during splx() BEFORE the kernel sets its polling flags
     * (e.g., STF_POLL_IP in the tape driver). This causes a race where
     * stdone clears the flag, then the kernel re-sets it, and the polling
     * loop never exits. Deferring lets at least one instruction execute
     * between the ESP write and the interrupt delivery.
     * The kernel's scintr goto-again loop still works because it checks
     * *intrstat (which reads intr_status directly, not m68k IRQ level). */
    if (bit == I_IPL3_SCSI) {
        if (next_debug_scsi)
            xil_printf("[IRQ+] set $%08X → status=$%08X (DEFERRED)\r\n",
                       bit, intr_status);
        return;  /* don't call m68k_set_irq — main loop will pick it up */
    }
    int ipl = next_intr_pending_ipl();
    if (next_debug_scsi && bit != I_IPL6_TIMER)
        xil_printf("[IRQ+] set $%08X → status=$%08X ipl=%d\r\n",
                   bit, intr_status, ipl);
    m68k_set_irq(ipl);
}

void next_intr_clear(uint32_t bit)
{
    extern int next_debug_scsi;
    intr_status &= ~bit;
    int ipl = next_intr_pending_ipl();
    if (next_debug_scsi && bit != I_IPL6_TIMER)
        xil_printf("[IRQ-] clr $%08X → status=$%08X ipl=%d\r\n",
                   bit, intr_status, ipl);
    m68k_set_irq(ipl);
}
uint32_t next_intr_get_status(void) { return intr_status; }
uint32_t next_intr_get_mask(void) { return intr_mask; }

/* ------------------------------------------------------------------ */
/* I/O read handlers                                                   */
/* ------------------------------------------------------------------ */

uint8_t next_io_read_8(uint32_t address)
{
    address = next_io_canon(address);

    /* Device probe detection (byte reads) — phase-aware */
    {
        static uint8_t probed8[2] = {0, 0};
        static int phase8 = 0;
        if (!phase8 && address >= 0x02014000 && address < 0x02014020) {
            static int esp_byte_count = 0;
            if (++esp_byte_count > 30) phase8 = 1;  /* kernel re-accesses ESP */
        }
        uint8_t *p = &probed8[phase8];
        if (!((*p) & 0x01) && address >= 0x02014000 && address < 0x02014020) {
            *p |= 0x01; xil_printf("[PROBE%d] ESP (byte) at $%08X\r\n", phase8, address);
        }
        if (!((*p) & 0x02) && address >= 0x02014100 && address <= 0x02014108) {
            *p |= 0x02; xil_printf("[PROBE%d] Floppy (byte) at $%08X\r\n", phase8, address);
        }
        if (!((*p) & 0x04) && address >= 0x02006000 && address < 0x02006010) {
            *p |= 0x04; xil_printf("[PROBE%d] Ethernet (byte) at $%08X\r\n", phase8, address);
        }
        if (!((*p) & 0x08) && address >= P_DSP_BASE && address < P_DSP_BASE + P_DSP_SIZE) {
            *p |= 0x08; xil_printf("[PROBE%d] DSP (byte) at $%08X\r\n", phase8, address);
        }
        if (!((*p) & 0x10) && address >= 0x02018000 && address < 0x02018004) {
            *p |= 0x10; xil_printf("[PROBE%d] SCC (byte) at $%08X\r\n", phase8, address);
        }
    }

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

    /* Ethernet (MB8795): 0x02006000-0x0200600F — return 0 (no ethernet) */
    if (address >= 0x02006000 && address < 0x02006010)
        return 0;

    /* Printer (NeXTlaser): 0x0200F000-0x0200F003 (byte CSRs) */
    if (address >= 0x0200F000 && address <= 0x0200F003)
        return 0;

    /* Floppy controller (Intel 82077AA): 0x02014100-0x02014108 */
    if (address >= 0x02014100 && address <= 0x02014108) {
        static int flp_log = 0;
        if (flp_log < 10) {
            xil_printf("[FLP] R8 @%08X → 0\r\n", address);
            flp_log++;
        }
        if (address == 0x02014104)
            return 0x80;  /* MSR: RQM=1 (ready), no data direction */
        if (address == 0x02014108)
            return 0;     /* FLPCTL: bit 6 clear = SCSI selected */
        return 0;
    }

    /* DSP registers (byte-wide) */
    if (address >= P_DSP_BASE && address < P_DSP_BASE + P_DSP_SIZE)
        return next_dsp_read(address - P_DSP_BASE);

    /* P_MON / KMS byte reads — monitor.s reads individual bytes of mon_csr.
     * Byte 0 = bits 31-24 (dmaout/dmain enables, dav, ovr)
     * Byte 1 = bits 23-16 (km_int/dav, control_int/dav)
     * Byte 2 = bits 15-8  (dtx_pend, dtx, ctx_pend, ctx, rtx_pend, rtx, reset, txloop)
     * Byte 3 = bits 7-0   (cmd) */
    if (address >= P_MON && address < P_MON + 16) {
        uint32_t val32 = next_kms_read((address - P_MON) & ~3);
        int shift = (3 - (int)(address & 3)) * 8;
        return (val32 >> shift) & 0xFF;
    }

    /* Brightness (byte-wide) */
    if (address == P_BRIGHTNESS)
        return 0x3D;  /* max brightness */

    /* Hardclock timer byte reads — return live counter value.
     * The 16-bit counter counts up at 1 MHz. The ROM reads this
     * during POST calibration to verify the timer is running. */
    if (address == P_TIMER)
        return (timer_counter >> 8) & 0xFF;
    if (address == P_TIMER + 1)
        return timer_counter & 0xFF;
    if (address == P_TIMER_CSR) {
        /* Reading CSR clears timer interrupt (kernel does this in us_timer_int) */
        uint8_t val = hardclock_csr;
        next_intr_clear(I_IPL6_TIMER);
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
        next_eventc_read_count++;
        event_latch = eventc_synced();
        /* Log every 1000th read to see if value advances */
        if ((next_eventc_read_count % 50000) == 0)
            xil_printf("[EVENTC] #%u val=$%08X (us=%u run=%d base=%d)\r\n",
                       next_eventc_read_count, event_latch,
                       eventc_us, m68k_cycles_run(), eventc_batch_base);
        return (event_latch >> 24) & 0xFF;  /* byte 0: bits 31-24 */
    }
    if (address == P_EVENTC + 1)
        return (event_latch >> 16) & 0xFF;  /* eventc_h: bits 23-16 */
    if (address == P_EVENTC + 2)
        return (event_latch >> 8) & 0xFF;   /* eventc_m: bits 15-8 */
    if (address == P_EVENTC + 3)
        return event_latch & 0xFF;           /* eventc_l: bits 7-0 */

    /* BMAP chip (byte-level access) */
    if (address >= P_BMAP && address < P_BMAP + BMAP_REG_COUNT * 4) {
        uint32_t reg = (address - P_BMAP) >> 2;
        int shift = (3 - (int)((address - P_BMAP) & 3)) * 8;
        return (bmap_regs[reg] >> shift) & 0xFF;
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

    /* Hardclock timer (16-bit read returns live counter value) */
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
    io_track(address);

    /* Device probe detection — fires once per phase (ROM=phase 0, kernel=phase 1) */
    {
        static uint8_t probed[2] = {0, 0};
        static int phase = 0;
        /* Detect kernel phase: timer CSR is written during kernel init */
        if (!phase && address == P_SCR1) {
            static int scr1_count = 0;
            if (++scr1_count > 10) phase = 1;  /* kernel re-reads SCR1 */
        }
        uint8_t *p = &probed[phase];
        if (!((*p) & 0x01) && address >= 0x02014000 && address < 0x02014020) {
            *p |= 0x01; xil_printf("[PROBE%d] SCSI (ESP) at $%08X\r\n", phase, address);
        }
        if (!((*p) & 0x02) && address >= 0x02006000 && address < 0x02006010) {
            *p |= 0x02; xil_printf("[PROBE%d] Ethernet at $%08X\r\n", phase, address);
        }
        if (!((*p) & 0x04) && address >= P_DSP_BASE && address < P_DSP_BASE + P_DSP_SIZE) {
            *p |= 0x04; xil_printf("[PROBE%d] DSP at $%08X\r\n", phase, address);
        }
        if (!((*p) & 0x08) && address >= 0x02200000 && address < 0x02210000) {
            *p |= 0x08; xil_printf("[PROBE%d] TMC/ADB at $%08X\r\n", phase, address);
        }
        if (!((*p) & 0x10) && address == 0x02010000) {
            *p |= 0x10; xil_printf("[PROBE%d] Brightness at $%08X\r\n", phase, address);
        }
        if (!((*p) & 0x20) && address >= 0x0200E000 && address < 0x0200E010) {
            *p |= 0x20; xil_printf("[PROBE%d] KMS at $%08X\r\n", phase, address);
        }
    }

    /* SCR1 — the first thing the kernel reads */
    if (address == P_SCR1)
        return scr1_value;

    /* SCR2 — let RTC module inject RTDATA for bit-bang reads */
    if (address == P_SCR2)
        return next_rtc_scr2_read(scr2_value);

    /* Interrupt status */
    if (address == P_INTRSTAT) {
        /* Log scintr's goto-again check at line 1325 */
        static int intrstat_total = 0;
        if (++intrstat_total > 500) {
            uint32_t pc = m68k_get_reg(NULL, M68K_REG_PC);
            if (pc == 0x0408A45E)  /* scintr *intrstat check */
                xil_printf("[SCINTR-CHK] status=$%08X scsi=%d\r\n",
                           intr_status, !!(intr_status & I_IPL3_SCSI));
        }
        return intr_status;
    }

    /* Interrupt mask */
    if (address == P_INTRMASK)
        return intr_mask;

    /* Printer data register (32-bit) */
    if (address == 0x0200F004)
        return 0;

    /* P_MON / KMS: $0200E000-$0200E00F is the keyboard/mouse/sound chip. */
    if (address >= P_MON && address < P_MON + 16) {
        static int pmon_log = 0;
        static int pmon_late = 0;
        if (pmon_log < 5)
            xil_printf("[PMON] R32 @%08X → KMS offset %X\r\n", address, address - P_MON);
        pmon_log++;
        /* Detect kernel phase polling (console input wait) */
        if (pmon_log > 100 && !pmon_late) {
            pmon_late = 1;
            xil_printf("[KMS-POLL] Kernel polling KMS — likely waiting for console input!\r\n");
        }
        return next_kms_read(address - P_MON);
    }

    /* Slot ID */
    if (address == P_SID)
        return 0;

    /* Event counter (microseconds) — 32-bit read latches + returns full value */
    if (address == P_EVENTC)
        return eventc_synced();

    /* DMA registers: 0x02004000-0x020043FF — all channels */
    if (address >= 0x02004000 && address < 0x02004400) {
        uint32_t off = address & 0x3FF;
        /* SCSI channel: dedicated handler for active regs + init */
        if (off <= 0x01C || off == 0x210)
            return next_scsi_dma_reg_read(address);
        /* All other channels: generic scratchpad */
        return dma_scratch[off >> 2];
    }

    /* DMA CSRs: return state in Turbo read format (bits 24-31) */
    {
        int ch = dma_channel_for_addr(address);
        if (ch >= 0) {
            /* SCSI channel: use dedicated DMA module */
            if (ch == 0)
                return next_scsi_dma_csr_read();
            return (uint32_t)dma_csr[ch] << 24;
        }
    }

    /* DSP registers (32-bit) */
    if (address >= P_DSP_BASE && address < P_DSP_BASE + P_DSP_SIZE)
        return next_dsp_read32(address - P_DSP_BASE);

    /* BMAP chip (32-bit register array) */
    if (address >= P_BMAP && address < P_BMAP + BMAP_REG_COUNT * 4) {
        uint32_t reg = (address - P_BMAP) >> 2;
        return bmap_regs[reg];
    }

    /* TMC space: $02200000-$0220FFFF */
    if (address >= 0x02200000 && address < 0x02210000) {
        uint32_t tmc_off = address - 0x02200000;
        /* TMC SCR1 at $02200000 — same as P_SCR1 */
        if (tmc_off < 4)
            return scr1_value;
        /* ADB registers at TMC+$8000-$803F (mapped via $02208xxx) */
        if (tmc_off >= 0x8000 && tmc_off < 0x8040) {
            uint32_t adb_reg = tmc_off - 0x8000;
            switch (adb_reg) {
            case ADB_INTSTATUS:
                return adb_intstatus;
            case ADB_INTMASK:
                return adb_intmask;
            default:
                return 0;
            }
        }
        return 0;  /* other TMC registers */
    }

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

    /* Floppy controller (82077): 0x02014100-0x02014108 */
    if (address >= 0x02014100 && address <= 0x02014108) {
        xil_printf("[FLP-W] @%08X = $%02X\r\n", address, value);
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

    /* P_MON / KMS byte writes — mon_csr_and/mon_csr_or in monitor.s do
     * byte read-modify-write at P_MON+0 (sound DMA enable/ovr bits). */
    if (address >= P_MON && address < P_MON + 16) {
        next_kms_write((address - P_MON) & ~3, (uint32_t)value);
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
        next_intr_clear(I_IPL6_TIMER);
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
        uint32_t old_mask = intr_mask;
        intr_mask = value;
        if (value != old_mask) {
            uint32_t delta = value ^ old_mask;
            /* Always log SCSI-related mask changes */
            if (delta & I_IPL3_SCSI)
                xil_printf("[IRQ-MASK] SCSI bit %s: $%08X → $%08X\r\n",
                           (value & I_IPL3_SCSI) ? "SET" : "CLEARED",
                           old_mask, value);
            else if (next_debug_scsi)
                xil_printf("[IRQ] mask $%08X → $%08X (delta=$%08X)\r\n",
                           old_mask, value, delta);
        }
        /* Recalculate pending IPL — an unmasked pending interrupt must fire */
        int ipl = next_intr_pending_ipl();
        m68k_set_irq(ipl);
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
            /* Decode Turbo write bits and update internal state,
             * same logic as SCSI DMA CSR write */
            if (value & 0x00100000)  /* TDMA_RESET */
                dma_csr[ch] &= ~(0x08 | 0x02 | 0x01);
            if (value & 0x00020000)  /* TDMA_SETSUPDATE */
                dma_csr[ch] |= 0x02;
            if (value & 0x00010000)  /* TDMA_SETENABLE */
                dma_csr[ch] |= 0x01;
            if (value & 0x00080000)  /* TDMA_CLRCOMPLETE */
                dma_csr[ch] &= ~0x08;
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

    /* BMAP chip (32-bit register array) */
    if (address >= P_BMAP && address < P_BMAP + BMAP_REG_COUNT * 4) {
        uint32_t reg = (address - P_BMAP) >> 2;
        bmap_regs[reg] = value;
        return;
    }

    /* TMC space: $02200000-$0220FFFF */
    if (address >= 0x02200000 && address < 0x02210000) {
        uint32_t tmc_off = address - 0x02200000;
        /* ADB registers at TMC+$8000-$803F */
        if (tmc_off >= 0x8000 && tmc_off < 0x8040) {
            uint32_t adb_reg = tmc_off - 0x8000;
            switch (adb_reg) {
            case ADB_INTSTATUS:
                adb_intstatus &= ~value;  /* write-1-to-clear */
                break;
            case ADB_INTMASK:
                adb_intmask = value;
                break;
            case ADB_CMD:
                /* Any ADB command → immediately reject (no devices) */
                adb_intstatus |= ADB_INT_REJECT;
                break;
            default:
                break;
            }
        }
        return;
    }

#ifdef NEXT_IO_DEBUG
    xil_printf("[NEXT] W32 @%08X = %08X\r\n", address, value);
#endif
}

uint32_t next_get_mon_global(void) { return p_mon_value; }
