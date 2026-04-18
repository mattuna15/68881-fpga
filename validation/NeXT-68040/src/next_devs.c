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
#include "next_debug.h"
#include "xil_printf.h"

/* Debug toggle — toggled by 'D' keypress in main loop */
int next_debug_scsi = 0;

/* Verbose I/O logging — toggled by 'I' keypress.
 * Logs every device register read/write with address, value, size, and PC.
 * Filters out timer reads (0x02016000-0x02016004) to avoid flooding. */
int next_debug_io = 0;
int io_log_count = 0;
#define IO_LOG_LIMIT 500  /* auto-stop after this many lines */

static void io_log(const char *rw, uint32_t addr, uint32_t val, int size)
{
    if (!next_debug_io) return;
    /* Filter out high-frequency polling that would flood the log */
    if (addr >= P_TIMER && addr <= P_TIMER_CSR + 3) return;  /* timer */
    if (addr >= P_EVENTC && addr <= P_EVENTC + 3) return;      /* event counter */
    if (addr >= P_SCR2 && addr < P_SCR2 + 4) return;           /* RTC bit-bang */
    if (addr == P_INTRSTAT) return;                             /* idle loop polls */
    uint32_t pc  = m68k_get_reg(NULL, M68K_REG_PC);
    uint32_t ppc = m68k_get_reg(NULL, M68K_REG_PPC);
    if (rw[0] == 'R')
        xil_printf("[IO] R%d $%08X  PC=$%08X PPC=$%08X\r\n",
                   size*8, addr, pc, ppc);
    else
        xil_printf("[IO] W%d $%08X = $%08X  PC=$%08X PPC=$%08X\r\n",
                   size*8, addr, val, pc, ppc);
    if (++io_log_count >= IO_LOG_LIMIT) {
        next_debug_io = 0;
        xil_printf("[IO] auto-stop after %d entries\r\n", IO_LOG_LIMIT);
    }
}
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
static uint32_t tmc_scr1_value;  /* Turbo-only, separate from system SCR1 */

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
uint32_t timer_fires_total = 0;
uint32_t timer_acks_total = 0;
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

/* ------------------------------------------------------------------ */
/* TMC Video Vertical Blank (VBL) interrupt — 68 Hz                    */
/* On Turbo systems the TMC VIR (Video Interrupt Register) at offset   */
/* $80 controls VBL: bit 0 = status (write-1-to-clear), bit 1 = mask. */
/* The interrupt fires through I_IPL3_DISK, matching Previous.         */
/* ------------------------------------------------------------------ */
#define VBL_PERIOD_US   14705   /* 1000000/68 ≈ 14705 µs */
#define TMC_VI_INTERRUPT 0x01
#define TMC_VI_INT_MASK  0x02
static int     vbl_accum;       /* accumulated µs toward next VBL */
static uint8_t tmc_vir;         /* VIR register (bits 0-1) */

/* Softint delivery.  Originally gated to avoid perturbing timer
 * calibration, but calibration runs during ROM init — long before the
 * kernel's SCSI DMA completion path calls softint_sched.  Disabling
 * softints during device init prevented scdmaintr from firing, causing
 * the DMA reset loop.  Now always enabled. */
static int softint_enabled = 1;

void next_softint_enable(void)
{
    softint_enabled = 1;
}

/* Event counter — emulated microseconds derived from CPU cycles.
 * The kernel's DELAY() and event_get() use this to measure time.
 * Must advance with emulated CPU time (25 MHz → 1 µs per 25 cycles),
 * NOT wall time, because the emulated CPU runs much faster than real time.
 *
 * Speedup multipliers (see TIMER_COUNTER_BOOST / EVENTC_BOOST):
 * We lack Previous's cycle-accurate cycInt scheduler, so both the 16-bit
 * live timer counter (used by ROM POST calibration) and the 32-bit event
 * counter (used by the kernel's event_timeout / scsi_pollcmd) need to
 * "advance faster than real emulated cycles" or the ROM POST takes minutes
 * and kernel timeouts take ~500 real seconds. The boosts are applied
 * uniformly to keep the counters' ratio internally consistent even though
 * it diverges from the real NeXT rate.
 *
 * Proper fix: port a cycInt-equivalent scheduler so real emulated time
 * progresses via scheduled events rather than raw CPU cycle counts.
 * Until then, any code that cross-references these counters against
 * the hardclock (I_IPL6_TIMER) or wall-clock time will skew. */
#define EVENTC_PRESCALE      25  /* 25 MHz / 25 = 1 MHz (1 µs per tick) */
#define EVENTC_BOOST       4096  /* multiply emulated µs progress; without
                                  * this, kernel's event_timeout bit-19
                                  * check takes ~500 real seconds. */
#define TIMER_COUNTER_BOOST 1024 /* multiply 16-bit live-counter progress;
                                  * without this, ROM POST calibration
                                  * outer DBEQ retries for tens of seconds. */

static uint32_t eventc_us;           /* emulated microseconds counter           */
static uint32_t event_latch;         /* snapshot taken when eventc_latch is read */
static int      eventc_accum;        /* fractional cycle accumulator             */
static int      eventc_batch_base;   /* cycles_run snapshot at last sync         */

/* Sync event counter from within m68k_execute() — call before reading eventc.
 * Uses m68k_cycles_run() to account for cycles elapsed within the current batch
 * that next_timer_tick() hasn't seen yet. */
static uint32_t eventc_synced(void)
{
    int run = m68k_cycles_run();
    int delta = run - eventc_batch_base;
    if (delta < 0) delta = 0;  /* safety: handle batch boundary */
    return eventc_us + (uint32_t)(delta / EVENTC_PRESCALE) * EVENTC_BOOST;
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
/* and mouse via the TMC at $02208xxx.  Matches Previous emulator's    */
/* register layout and command handling so the ROM/kernel probe         */
/* completes correctly (all commands timeout → no devices found).      */
/* ------------------------------------------------------------------ */
#define ADB_REG_INTSTATUS   0x00  /* rw (write-1-to-clear) */
#define ADB_REG_INTMASK     0x08  /* rw */
#define ADB_REG_SETINT      0x10  /* w */
#define ADB_REG_CONFIG      0x18  /* rw */
#define ADB_REG_CTRL        0x20  /* w */
#define ADB_REG_STATUS      0x28  /* r */
#define ADB_REG_CMD         0x30  /* rw */
#define ADB_REG_COUNT       0x38  /* rw */
#define ADB_REG_DATA0       0x80  /* rw */
#define ADB_REG_DATA1       0x88  /* rw */

/* Interrupt status/mask bits */
#define ADB_INT_REJECT      0x01
#define ADB_INT_POLLSTOP    0x02
#define ADB_INT_ACCESS      0x04
#define ADB_INT_RESET       0x08

/* Control register bits */
#define ADB_CTRL_EN_POLL    0x01
#define ADB_CTRL_DIS_POLL   0x02
#define ADB_CTRL_XMIT_CMD  0x04
#define ADB_CTRL_RESET_ADB  0x08

/* Status register bits */
#define ADB_STAT_TIMEOUT    0x04
#define ADB_STAT_RESET      0x10
#define ADB_STAT_ACCESS     0x20
#define ADB_STAT_POLL_EN    0x40

static struct {
    uint32_t intstatus;
    uint32_t intmask;
    uint32_t config;
    uint32_t status;
    uint32_t command;
    uint32_t bitcount;
    uint32_t data0;
    uint32_t data1;
} adb;

/* ------------------------------------------------------------------ */
/* MB8795 / AT&T 7213 Ethernet controller stub (Turbo variant)         */
/* Base: $02006000.  Matches Previous's ethernet.c register layout so  */
/* POST and kernel probe both succeed.  No real packet transfer — we   */
/* report the link as disconnected so the driver gives up politely.   */
/* ------------------------------------------------------------------ */
#define EN_REG_TX_STATUS    0x0
#define EN_REG_TX_MASK      0x1
#define EN_REG_RX_STATUS    0x2
#define EN_REG_RX_MASK      0x3
#define EN_REG_TX_MODE      0x4
#define EN_REG_RX_MODE      0x5
#define EN_REG_CONTROL      0x6   /* Turbo Control reg (was Reset on classic) */
#define EN_REG_COUNTER_LO   0x7
#define EN_REG_MAC0         0x8
#define EN_REG_MAC1         0x9
#define EN_REG_MAC2         0xA
#define EN_REG_MAC3         0xB
#define EN_REG_MAC4         0xC
#define EN_REG_MAC5         0xD
#define EN_REG_COUNTER_HI   0xF

/* Status bits (from Previous) */
#define EN_TXSTAT_READY     0x80
#define EN_RESET            0x80
#define EN_ENCTRL_TPE       0x40

static struct {
    uint8_t tx_status;
    uint8_t tx_mask;
    uint8_t rx_status;
    uint8_t rx_mask;
    uint8_t tx_mode;
    uint8_t rx_mode;
    uint8_t control;   /* reset on classic, control on Turbo */
    uint8_t mac[6];
} enet_stub = {
    /* tx_status starts ready on classic, 0 on Turbo — we are Turbo */
    .tx_status = 0,
    .tx_mask   = 0,
    .rx_status = 0,
    .rx_mask   = 0,
    .tx_mode   = 0,
    .rx_mode   = 0,
    .control   = EN_RESET,   /* held in reset until kernel clears */
    /* NeXT OUI 00:00:0F, rest arbitrary */
    .mac       = { 0x00, 0x00, 0x0F, 0x12, 0x34, 0x56 },
};

static uint8_t enet_reg_read(uint32_t reg)
{
    switch (reg) {
    case EN_REG_TX_STATUS:  return enet_stub.tx_status;
    case EN_REG_TX_MASK:    return enet_stub.tx_mask & 0xAF;
    case EN_REG_RX_STATUS:  return enet_stub.rx_status;
    case EN_REG_RX_MASK:    return enet_stub.rx_mask & 0x9F;
    case EN_REG_TX_MODE:    return enet_stub.tx_mode;
    case EN_REG_RX_MODE:    return enet_stub.rx_mode;
    case EN_REG_CONTROL:
        /* Turbo Control read: report TPE set (disconnected) + current reset */
        return enet_stub.control | EN_ENCTRL_TPE;
    case EN_REG_MAC0:       return enet_stub.mac[0];
    case EN_REG_MAC1:       return enet_stub.mac[1];
    case EN_REG_MAC2:       return enet_stub.mac[2];
    case EN_REG_MAC3:       return enet_stub.mac[3];
    case EN_REG_MAC4:       return enet_stub.mac[4];
    case EN_REG_MAC5:       return enet_stub.mac[5];
    case EN_REG_COUNTER_LO:
    case EN_REG_COUNTER_HI: return 0;   /* TX buffer empty */
    default:                return 0;
    }
}

static void enet_reg_write(uint32_t reg, uint8_t val)
{
    switch (reg) {
    case EN_REG_TX_STATUS:
        /* Turbo: write-1-to-clear */
        enet_stub.tx_status &= ~val;
        break;
    case EN_REG_TX_MASK:
        enet_stub.tx_mask = val;
        break;
    case EN_REG_RX_STATUS:
        enet_stub.rx_status &= ~(val & 0x8F);
        break;
    case EN_REG_RX_MASK:
        enet_stub.rx_mask = val;
        break;
    case EN_REG_TX_MODE:
        enet_stub.tx_mode = val;
        break;
    case EN_REG_RX_MODE:
        enet_stub.rx_mode = val;
        break;
    case EN_REG_CONTROL:
        /* Turbo: bit 7 is reset.  When kernel clears reset and starts the
         * controller, stay "ready to transmit" so it doesn't spin. */
        enet_stub.control = val & EN_RESET;
        if (val & EN_RESET) {
            enet_stub.tx_status = 0;   /* Turbo: cleared on reset */
            enet_stub.rx_status = 0;
        }
        break;
    case EN_REG_MAC0:       enet_stub.mac[0] = val; break;
    case EN_REG_MAC1:       enet_stub.mac[1] = val; break;
    case EN_REG_MAC2:       enet_stub.mac[2] = val; break;
    case EN_REG_MAC3:       enet_stub.mac[3] = val; break;
    case EN_REG_MAC4:       enet_stub.mac[4] = val; break;
    case EN_REG_MAC5:       enet_stub.mac[5] = val; break;
    default: break;
    }
}

/* Raise or release the ADB interrupt (shared with disk on I_IPL3_DISK)
 * based on whether any unmasked status bit is asserted.  Matches
 * Previous's adb_interrupt()/adb_intstatus_write() behaviour. */
static void adb_update_irq(void)
{
    if (adb.intstatus & adb.intmask) {
        next_intr_set(I_IPL3_DISK);
    } else if (!(tmc_vir & TMC_VI_INTERRUPT)) {
        /* Only release the shared IPL3 disk line if VBL isn't also pending */
        next_intr_clear(I_IPL3_DISK);
    }
}

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
    /* Virtual-address indexer — applies the bank-mask offset used by
     * the main memory accessors in next_memory.c.  Required because
     * VA $04xxxxxx doesn't map to next_ram[$00xxxxxx] anymore; it maps
     * to next_ram[$04xxxxxx]. */
    #define RDVA32(va) ((uint32_t)(                                             \
        (next_ram[(va)   & 0x07FFFFFFu] << 24) |                                \
        (next_ram[((va)+1) & 0x07FFFFFFu] << 16) |                              \
        (next_ram[((va)+2) & 0x07FFFFFFu] <<  8) |                              \
         next_ram[((va)+3) & 0x07FFFFFFu]))
    int found = 0;
    /* sf_access_head has: queue_head(8), lock(4), wait_cnt(4), flags(4), last_dev(4), excl_q(4), busy(4)
     * For an empty queue: q.next == q.prev == &q (self-pointer)
     * For a non-empty queue: q.next and q.prev are different kernel pointers */
    for (uint32_t va = 0x04000000;
         va < 0x04000000 + 0x00200000 && found < 5; va += 4) {
        uint32_t addr = va;
        uint32_t w0 = RDVA32(va);
        uint32_t w1 = RDVA32(va+4);
        /* Check for self-referencing queue (empty) or two valid kernel pointers */
        if (w0 == addr && w1 == addr) {
            /* Empty queue — both next and prev point to queue head itself.
             * Check that following fields look like sfah (small integers). */
            uint32_t wait_cnt = RDVA32(va+0x0C);
            uint32_t flags = RDVA32(va+0x10);
            uint32_t last_dev = RDVA32(va+0x14);
            uint32_t excl_q = RDVA32(va+0x18);
            uint32_t busy = RDVA32(va+0x1C);
            if (wait_cnt < 100 && flags < 100 && last_dev < 100 && excl_q < 100 && busy < 100) {
                xil_printf("[SFA-HEAD] @$%08X: q={self,self} lock=%d wait=%d flags=%d last=%d excl=%d BUSY=%d\r\n",
                           addr, RDVA32(va+8), wait_cnt, flags, last_dev, excl_q, busy);
                found++;
            }
        }
        /* Also check non-empty queue: two different kernel ptrs, followed by small ints */
        else if (w0 >= 0x04000000 && w0 < 0x04200000 &&
                 w1 >= 0x04000000 && w1 < 0x04200000 && w0 != w1) {
            uint32_t lock = RDVA32(va+8);
            uint32_t wait_cnt = RDVA32(va+0x0C);
            uint32_t flags = RDVA32(va+0x10);
            uint32_t last_dev = RDVA32(va+0x14);
            uint32_t excl_q = RDVA32(va+0x18);
            uint32_t busy = RDVA32(va+0x1C);
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
    #undef RDVA32
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
    /* On Turbo there are TWO distinct SCR1 registers (Previous keeps
     * them in sysReg.c and tmc.c respectively):
     *
     *   $0200C000 (P_SCR1)    : "system SCR1"
     *      = SCR1_TURBO | 0xF0000000   (slot id F for non-cube)
     *      = $F0004000
     *
     *   $02200000 (TMC reg 0) : "Turbo SCR1"  — encodes cpu/mem speeds,
     *      cpu type, FMASK always-on bits.  The early ROM code at
     *      $00CC reads this register and feeds it into ISP/MSP setup.
     *      = TURBOSCR_FMASK ($0FFF0F08) | $4000 (Turbo mono)
     *        | $A0 (mem 80ns) | $07 (cpu 33 MHz)
     *      = $0FFF4FAF
     *
     * The two values must be different and live in different registers. */
    scr1_value = 0xF0004000;       /* P_SCR1 at $0200C000 */
    tmc_scr1_value = 0x0FFF4FAF;   /* TMC SCR1 at $02200000 (Turbo mono, 33 MHz, 80ns) */

    /* SCR2: Turbo init values from Previous (scr2_2=0x10, scr2_3=0x80) |
     * 4x1M DRAM banks in the high word. */
    scr2_value = (0x0F << 16) | 0x00001080;

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

    /* ADB: all zeroed (no devices) */
    memset(&adb, 0, sizeof(adb));

    /* DMA: all channels fully zeroed.
     * Previous inits dma[ch].csr = 0 (no bits set).  We previously set
     * DMA_COMPLETE (bit 3) here but that causes the Turbo ROM's early
     * POST to see channel 0/whatever channel it probes as "completion
     * pending", branch into an error-handling path, and eventually
     * take a bus error that lands in the $010005AE panic handler. */
    memset(dma_csr, 0, sizeof(dma_csr));

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

    /* Advance the live 16-bit counter.  See TIMER_COUNTER_BOOST above —
     * on real hardware this ticks at 1 MHz (1 µs per tick), but ROM POST
     * calibration at $010040F0..$0100413C would spin for tens of seconds
     * if driven at true rate given our emulator throughput. Downstream
     * code that uses P_TIMER only reads deltas, so the absolute rate
     * doesn't matter. */
    timer_counter += (uint16_t)(usecs * TIMER_COUNTER_BOOST);

    /* Advance the event counter. See EVENTC_BOOST above — kernel's
     * event_timeout() bit-19 boundary check would take ~500 real
     * seconds per scsi_pollcmd without the boost. Hardclock uses a
     * separate counter and is NOT affected. */
    eventc_us += usecs * EVENTC_BOOST;
    eventc_batch_base = 0;  /* reset: next batch starts from 0 */

    /* Periodic hardclock interrupt.
     *
     * Previous schedules a one-shot per period via CycInt; we accumulate.
     * The critical bit: if multiple periods elapsed in a single tick batch
     * (long idle slice), we must still raise the interrupt — any lost tick
     * means a callout gets skipped which breaks alarm()/setitimer() and
     * stalls wait loops that rely on periodic wakeups.
     *
     * We only raise once per tick_batch even if several periods elapsed,
     * because the kernel handler is level-sensitive and runs the callout
     * wheel once per entry, but we make sure a pending fire is never
     * dropped: if accum >= latch_hardclock, set the interrupt and keep
     * the remainder — the next tick_batch will evaluate again. */
    if ((hardclock_csr & HARDCLOCK_ENABLE) && latch_hardclock > 0) {
        hardclock_accum += usecs;
        if (hardclock_accum >= latch_hardclock) {
            hardclock_accum %= latch_hardclock;
            next_intr_set(I_IPL6_TIMER);
            extern uint32_t timer_fires_total;
            timer_fires_total++;
        }
    }

    /* VBL interrupt — 68 Hz via TMC, was firing through I_IPL3_DISK.
     *
     * DISABLED: I_IPL3_DISK is the optical-disk / floppy line, and the
     * kernel's IRQ dispatcher handles it through a driver path that
     * does NOT write to TMC VIR to clear the VBL bit — so once we
     * assert I_IPL3_DISK, the kernel's ISR reads P_INTRSTAT, sees it
     * set, fails to clear, returns, and the CPU immediately re-enters
     * the ISR. Interrupt storm: the kernel polls P_INTRSTAT hundreds of
     * times per sample window and `idle_thread` appears to spin at
     * $04067xxx because every instruction is interrupted by a spurious
     * IRQ. VBL is only needed for cosmetic things (cursor blink,
     * screen saver), so we skip it entirely. When/if the kernel
     * actually enables and handles VBL with the correct clear path,
     * we can route it through a dedicated bit instead of sharing
     * I_IPL3_DISK. */
    (void)vbl_accum;
#if 0
    vbl_accum += usecs;
    if (vbl_accum >= VBL_PERIOD_US) {
        vbl_accum -= VBL_PERIOD_US;
        if (tmc_vir & TMC_VI_INT_MASK) {
            tmc_vir |= TMC_VI_INTERRUPT;
            next_intr_set(I_IPL3_DISK);
        }
    }
#endif

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

    /* IPL2: softint1 — level-sensitive, cleared when kernel writes SCR2 */
    if (pending & I_IPL2_SOFTINT1)
        return 2;

    /* IPL1: softint0 — level-sensitive, cleared when kernel writes SCR2 */
    if (pending & I_IPL1_SOFTINT0)
        return 1;

    return 0;
}

int next_intr_acknowledge(int level)
{
    /* Auto-clear softint on acknowledge — edge-triggered behavior.
     * When the CPU enters the ISR, the pending bit clears so the
     * interrupt doesn't re-fire immediately when the handler returns.
     * The kernel re-triggers by writing SCR2 again if needed. */
    if (level == 1)
        intr_status &= ~I_IPL1_SOFTINT0;
    else if (level == 2)
        intr_status &= ~I_IPL2_SOFTINT1;
    return -1;  /* autovector */
}

/* ------------------------------------------------------------------ */
/* Interrupt set/clear (used by ESP and DMA modules)                    */
/* ------------------------------------------------------------------ */

#if NEXT_DEBUG_DMA
/* Last-clear timestamp for DMA IPL6 — lets next_intr_set print Δ-instr
 * between a clear and the next assertion.  A short delta means the IRQ
 * is being re-raised immediately, which is the candidate fault mode. */
static uint64_t dma_irq_last_clear_instr;
#endif

void next_intr_set(uint32_t bit)
{
    extern int next_debug_scsi;
    {
        static int irq_set_log = 0;
        if (irq_set_log < 40) {
            xil_printf("[IRQ+] set $%08X PC=$%08X SR=$%04X (prev status=$%08X)\r\n",
                       bit,
                       m68k_get_reg(NULL, M68K_REG_PC),
                       m68k_get_reg(NULL, M68K_REG_SR) & 0xFFFF,
                       intr_status);
            irq_set_log++;
        }
    }

#if NEXT_DEBUG_DMA
    /* Extra diagnostic for DMA IPL6: correlate the set with our deferred
     * state and the elapsed instructions since the previous clear. */
    if (bit == I_IPL6_SCSI_DMA) {
        static int dma_set_log = 0;
        if (dma_set_log < 60 || (dma_set_log % 100) == 0) {
            uint32_t pc = m68k_get_reg(NULL, M68K_REG_PC);
            uint32_t sr = m68k_get_reg(NULL, M68K_REG_SR);
            uint64_t dt = emu_instr_count - dma_irq_last_clear_instr;
            xil_printf("[DMA-IRQ+] #%d PC=$%08X SR=$%04X csr=$%02X "
                       "pending=%d cd=%d instr=%u Δclr=%u\r\n",
                       dma_set_log, pc, sr & 0xFFFF,
                       next_scsi_dma_get_csr(),
                       next_scsi_dma_get_pending(),
                       next_scsi_dma_get_countdown(),
                       (uint32_t)emu_instr_count,
                       (uint32_t)dt);
        }
        dma_set_log++;
    }
#endif /* NEXT_DEBUG_DMA */

    intr_status |= bit;
    /* SCSI interrupts: do NOT call m68k_set_irq here.  The I/O callback
     * fires mid-instruction during the ESP register write.  If we deliver
     * immediately, it races with the tape driver's STF_POLL_IP flag setup
     * (set AFTER splx, but the interrupt fires DURING splx).
     *
     * Instead, set a flag that emu_instr_hook checks on the NEXT instruction.
     * This gives exactly 1-instruction deferral — enough for splx to
     * complete, but not the 10,000-instruction deferral that caused the
     * biowait deadlock on open("/dev/console"). */
    if (bit == I_IPL3_SCSI) {
        extern volatile int next_irq_pending_update;
        next_irq_pending_update = 10;  /* deliver after ~10 instructions */
        return;
    }
    /* DMA completion (IPL6) must be delivered immediately — the kernel's
     * dma_start writes RESET to DMA CSR as its first step, which clears
     * the DMA interrupt bit.  If delivery is deferred even 10 instructions,
     * the RESET fires before the CPU takes the interrupt, and dma_intr
     * never runs → scdmaintr never fires → SCSI state machine stalls. */
    int ipl = next_intr_pending_ipl();
    if (next_debug_scsi && bit != I_IPL6_TIMER)
        xil_printf("[IRQ+] set $%08X → status=$%08X ipl=%d\r\n",
                   bit, intr_status, ipl);
    m68k_set_irq(ipl);
}

void next_intr_clear(uint32_t bit)
{
    extern int next_debug_scsi;
#if NEXT_DEBUG_DMA
    /* Track DMA interrupt clears to diagnose lost interrupts */
    if (bit == I_IPL6_SCSI_DMA && (intr_status & I_IPL6_SCSI_DMA)) {
        static int dma_clr_log = 0;
        if (dma_clr_log < 30 || (dma_clr_log % 100) == 0) {
            uint32_t pc = m68k_get_reg(NULL, M68K_REG_PC);
            uint32_t sr = m68k_get_reg(NULL, M68K_REG_SR);
            xil_printf("[DMA-CLR] #%d PC=$%08X SR=$%04X status=$%08X instr=%u\r\n",
                       dma_clr_log, pc, sr & 0xFFFF, intr_status,
                       (uint32_t)emu_instr_count);
        }
        dma_clr_log++;
        dma_irq_last_clear_instr = emu_instr_count;
    }
#endif /* NEXT_DEBUG_DMA */
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
    if (next_debug_io) io_log("R", address, 0, 1);

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

    /* Ethernet (MB8795 / AT&T 7213): 0x02006000-0x0200600F */
    if (address >= 0x02006000 && address < 0x02006010) {
        uint32_t reg = address - 0x02006000;
        uint8_t val = enet_reg_read(reg);
        static int en_r_log = 0;
        if (en_r_log < 40) {
            xil_printf("[ENET] R8 @%08X reg=$%X val=$%02X PC=$%08X\r\n",
                       address, reg, val,
                       m68k_get_reg(NULL, M68K_REG_PC));
            en_r_log++;
        }
        return val;
    }

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
        if (intr_status & I_IPL6_TIMER)
            timer_acks_total++;
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

    /* TMC/ADB byte reads — route through 32-bit and extract byte */
    if (address >= 0x02200000 && address < 0x02210000) {
        uint32_t aligned = address & ~3u;
        uint32_t val32 = next_io_read_32(aligned);
        int shift = 8 * (3 - (address & 3));
        if (address >= 0x02208000 && address < 0x02208100)
            xil_printf("[ADB] R8  @%08X val=$%02X PC=$%08X\r\n",
                       address, (val32 >> shift) & 0xFF,
                       m68k_get_reg(NULL, M68K_REG_PC));
        return (val32 >> shift) & 0xFF;
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
    if (next_debug_io) io_log("R", address, 0, 2);

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
    if (next_debug_io) io_log("R", address, 0, 4);
    /* VBR / A7 change sentinel: sampled on I/O accesses (hot path).
     * Logs whenever VBR changes value so we can see when the vector
     * table gets relocated. */
    {
        static uint32_t last_vbr = 0xDEADBEEF;
        static int vbr_log = 0;
        uint32_t vbr = m68k_get_reg(NULL, M68K_REG_VBR);
        if (vbr != last_vbr && vbr_log < 15) {
            uint32_t pc = m68k_get_reg(NULL, M68K_REG_PC);
            uint32_t sp = m68k_get_reg(NULL, M68K_REG_A7);
            xil_printf("[VBR] change $%08X -> $%08X at PC=$%08X A7=$%08X\r\n",
                       last_vbr, vbr, pc, sp);
            last_vbr = vbr;
            vbr_log++;
        }
    }

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
        static int pmon_late = 0;
        static uint32_t pmon_last_pc = 0;
        static int pmon_same_pc = 0;
        uint32_t pc = m68k_get_reg(NULL, M68K_REG_PC);
        if (pmon_log < 5)
            xil_printf("[PMON] R32 @%08X → KMS off %X PC=$%08X\r\n",
                       address, address - P_MON, pc);
        pmon_log++;
        if (pc == pmon_last_pc) {
            pmon_same_pc++;
            /* Fire synthetic response very early — the ROM's KMS command
             * latency on real hardware is tiny, and polling here wastes
             * emulator cycles on every command cycle. */
            if (pmon_same_pc == 8)
                next_kms_force_response();
            if (pmon_same_pc == 5000)
                xil_printf("[KMS-LOOP] PC=$%08X still spinning on KMS off %X\r\n",
                           pc, address - P_MON);
        } else {
            pmon_last_pc = pc;
            pmon_same_pc = 0;
        }
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
        if (off <= 0x01C || off == 0x210) {
            uint32_t val = next_scsi_dma_reg_read(address);
#if NEXT_DEBUG_DMA
            static int dma_reg_rd_log = 0;
            if (dma_reg_rd_log < 20) {
                xil_printf("[DMA-REG] R @$%08X off=$%03X → $%08X PC=$%08X\r\n",
                           address, off, val, m68k_get_reg(NULL, M68K_REG_PC));
                dma_reg_rd_log++;
            }
#endif
            return val;
        }
        /* All other channels: generic scratchpad */
        return dma_scratch[off >> 2];
    }

    /* DMA CSRs: return state in Turbo read format (bits 24-31) */
    {
        int ch = dma_channel_for_addr(address);
        if (ch >= 0) {
            /* SCSI channel: use dedicated DMA module */
            if (ch == 0) {
                uint32_t val = next_scsi_dma_csr_read();
#if NEXT_DEBUG_DMA
                static int dma_rd_log = 0;
                uint32_t pc = m68k_get_reg(NULL, M68K_REG_PC);
                /* Log first 20 kernel reads */
                if (pc >= 0x04000000 && dma_rd_log < 20) {
                    xil_printf("[DMA-RD] ch0 CSR→$%08X PC=$%08X\r\n",
                               val, pc);
                    dma_rd_log++;
                }
#endif
                return val;
            }
            if (ch == 7 || ch == 8)
                xil_printf("[ENET-DMA] R32 @%08X ch=%d csr=$%02X PC=$%08X\r\n",
                           address, ch, dma_csr[ch],
                           m68k_get_reg(NULL, M68K_REG_PC));
            return ((uint32_t)dma_csr[ch] << 24) | 0x00000040;
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
        /* TMC SCR1 at $02200000 — Turbo-specific value, NOT P_SCR1.
         * The early ROM stack-pointer init at $00CC reads this and
         * feeds it into MOVEC ISP/MSP, so the value must encode the
         * Turbo cpu type / speeds / FMASK bits exactly. */
        if (tmc_off < 4)
            return tmc_scr1_value;
        /* TMC Control at $02200010 — Turbo memory controller config.
         * Previous returns $0D17038F. Kernel reads this during device init.
         * Bits: parity, burst mode, memory config. */
        if (tmc_off >= 0x10 && tmc_off < 0x14)
            return 0x0D17038F;
        /* TMC Video registers at $02200080-$0220008F (16-byte block).
         * Previous layout: byte 0=VIR, 1-3=void, 4-7=unimpl,
         * bytes 8-11=HCR (horizontal), bytes 12-15=VCR (vertical).
         * 32-bit read at $80 gets VIR in high byte + void.
         * 32-bit read at $88 gets HCR. 32-bit read at $8C gets VCR. */
        if (tmc_off >= 0x80 && tmc_off < 0x84)
            return (uint32_t)tmc_vir << 24;  /* VIR in high byte */
        if (tmc_off >= 0x84 && tmc_off < 0x88)
            return 0;  /* unimplemented */
        if (tmc_off >= 0x88 && tmc_off < 0x8C)
            return (0x18 << 25) | (0x20 << 19) | (0x48 << 12) | 0x118; /* HCR */
        if (tmc_off >= 0x8C && tmc_off < 0x90)
            return (0x08 << 25) | (0x08 << 19) | (0x30 << 12) | 0x340; /* VCR */
        /* ADB registers at TMC+$8000-$80FF (mapped via $02208xxx) */
        if (tmc_off >= 0x8000 && tmc_off < 0x8100) {
            uint32_t adb_reg = tmc_off - 0x8000;
            uint32_t val = 0;
            switch (adb_reg) {
            case ADB_REG_INTSTATUS: val = adb.intstatus; break;
            case ADB_REG_INTMASK:   val = adb.intmask;   break;
            case ADB_REG_CONFIG:    val = adb.config;    break;
            case ADB_REG_STATUS:    val = adb.status;    break;
            case ADB_REG_CMD:       val = adb.command;   break;
            case ADB_REG_COUNT:     val = adb.bitcount;  break;
            case ADB_REG_DATA0:     val = adb.data0;     break;
            case ADB_REG_DATA1:     val = adb.data1;     break;
            default:                val = 0;             break;
            }
            xil_printf("[ADB] R32 @%08X reg=$%02X val=$%08X PC=$%08X\r\n",
                       address, adb_reg, val, m68k_get_reg(NULL, M68K_REG_PC));
            return val;
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
    if (next_debug_io) io_log("W", address, value, 1);

    /* SCC channel A */
    if (address >= P_SCC && address < P_SCC + 4) {
        uint32_t off = address - P_SCC;
        switch (off) {
        case SCC_CHAN_A_CTRL:
            /* Z8530 two-write protocol: first write selects the register
             * (bits 0-2 = reg, bits 3-5 = command, with "point high"
             * command 001 setting bit 3 of the reg pointer for regs 8-15).
             * Second write is the data for that register.  We only track
             * the pointer; register data is accepted and discarded. */
            if (scc_wr_reg_ptr == 0) {
                /* First write: extract register pointer */
                scc_wr_reg_ptr = (value & 0x07)
                    | (((value & 0x38) == 0x08) ? 0x08 : 0x00);
            } else {
                /* Second write: data for the selected register — accept
                 * and reset pointer to 0 (auto-return to RR0/WR0). */
                scc_wr_reg_ptr = 0;
            }
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
    if (address >= 0x02014100 && address <= 0x02014108)
        return;

    /* Ethernet (MB8795 / AT&T 7213): 0x02006000-0x0200600F */
    if (address >= 0x02006000 && address < 0x02006010) {
        uint32_t reg = address - 0x02006000;
        static int en_w_log = 0;
        if (en_w_log < 40) {
            xil_printf("[ENET] W8 @%08X reg=$%X val=$%02X PC=$%08X\r\n",
                       address, reg, value,
                       m68k_get_reg(NULL, M68K_REG_PC));
            en_w_log++;
        }
        enet_reg_write(reg, value);
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

    /* P_MON / KMS byte writes — monitor.s does byte read-modify-write
     * on individual fields of mon_csr.  Reconstruct the 32-bit value
     * with the byte updated in the correct position, then hand to
     * next_kms_write so its per-field semantics are preserved. */
    if (address >= P_MON && address < P_MON + 16) {
        uint32_t aligned = (address - P_MON) & ~3;
        int byte_off = (address - P_MON) & 3;
        int shift = 8 * (3 - byte_off);
        uint32_t cur = next_kms_read(aligned);
        uint32_t newv = (cur & ~(0xFFu << shift)) | ((uint32_t)value << shift);
        next_kms_write(aligned, newv);
        return;
    }

    /* DSP registers (byte-wide) */
    if (address >= P_DSP_BASE && address < P_DSP_BASE + P_DSP_SIZE) {
        next_dsp_write(address - P_DSP_BASE, value);
        return;
    }

    /* SCR2 byte writes — kernel clears softint via byte write to SCR2+0.
     * Reconstruct 32-bit value with the changed byte and process as 32-bit. */
    if (address >= P_SCR2 && address < P_SCR2 + 4) {
        int byte_off = address - P_SCR2;
        int shift = 8 * (3 - byte_off);
        uint32_t new_val = (scr2_value & ~(0xFF << shift)) | ((uint32_t)value << shift);
        next_io_write_32(P_SCR2, new_val);
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
            static int timer_log = 0;
            if (timer_log < 5) { timer_log++; xil_printf("[TIMER] enable periodic IRQ every %d us\r\n", latch_hardclock); }
        }
        /* Writing CSR clears timer interrupt */
        next_intr_clear(I_IPL6_TIMER);
        return;
    }

    /* TMC/ADB byte writes — read-modify-write through 32-bit handler */
    if (address >= 0x02200000 && address < 0x02210000) {
        uint32_t aligned = address & ~3u;
        int shift = 8 * (3 - (address & 3));
        uint32_t cur = next_io_read_32(aligned);
        uint32_t newv = (cur & ~(0xFFu << shift)) | ((uint32_t)value << shift);
        if (address >= 0x02208000 && address < 0x02208100)
            xil_printf("[ADB] W8  @%08X val=$%02X PC=$%08X\r\n",
                       address, value, m68k_get_reg(NULL, M68K_REG_PC));
        next_io_write_32(aligned, newv);
        return;
    }

#ifdef NEXT_IO_DEBUG
    xil_printf("[NEXT] W8 @%08X = %02X\r\n", address, value);
#endif
}

void next_io_write_16(uint32_t address, uint16_t value)
{
    address = next_io_canon(address);
    if (next_debug_io) io_log("W", address, value, 2);

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
    if (next_debug_io) io_log("W", address, value, 4);

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

        /* Software interrupts: kernel sets SCR2 SOFTINT bits to trigger
         * IPL1 (softint0) and IPL2 (softint1). These wake the kernel's
         * softint_thread which delivers deferred Mach IPC messages. */
        if (softint_enabled && ((value ^ scr2_value) & SCR2_SOFTINT0)) {
            static int si0_log = 0;
            if (si0_log < 10) {
                xil_printf("[SI0] %s PC=$%08X\r\n",
                    (value & SCR2_SOFTINT0) ? "SET" : "CLR",
                    m68k_get_reg(NULL, M68K_REG_PC));
                si0_log++;
            }
            if (value & SCR2_SOFTINT0)
                next_intr_set(I_IPL1_SOFTINT0);
            else
                next_intr_clear(I_IPL1_SOFTINT0);
        }
        if (softint_enabled && ((value ^ scr2_value) & SCR2_SOFTINT1)) {
            static int si1_log = 0;
            if (si1_log < 10) {
                xil_printf("[SI1] %s PC=$%08X\r\n",
                    (value & SCR2_SOFTINT1) ? "SET" : "CLR",
                    m68k_get_reg(NULL, M68K_REG_PC));
                si1_log++;
            }
            if (value & SCR2_SOFTINT1)
                next_intr_set(I_IPL2_SOFTINT1);
            else
                next_intr_clear(I_IPL2_SOFTINT1);
        }

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
#if NEXT_DEBUG_DMA
        {
            static int dma_reg_wr_log = 0;
            if (dma_reg_wr_log < 20) {
                xil_printf("[DMA-REG] W @$%08X off=$%03X ← $%08X PC=$%08X\r\n",
                           address, off, value, m68k_get_reg(NULL, M68K_REG_PC));
                dma_reg_wr_log++;
            }
        }
#endif
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
#if NEXT_DEBUG_DMA
                static int dma_wr_reset_cnt = 0;
                if (value & 0x00100000) { /* TDMA_RESET */
                    dma_wr_reset_cnt++;
                    if (dma_wr_reset_cnt <= 10 || (dma_wr_reset_cnt % 1000) == 0) {
                        uint32_t pc = m68k_get_reg(NULL, M68K_REG_PC);
                        xil_printf("[DMA-WR] RESET #%d val=$%08X PC=$%08X\r\n",
                                   dma_wr_reset_cnt, value, pc);
                    }
                } else {
                    dma_wr_reset_cnt = 0; /* reset counter on non-reset write */
                }
#endif
                next_scsi_dma_csr_write(value);
                return;
            }
            if (ch == 7 || ch == 8)
                xil_printf("[ENET-DMA] W32 @%08X ch=%d val=$%08X PC=$%08X\r\n",
                           address, ch, value,
                           m68k_get_reg(NULL, M68K_REG_PC));
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
        /* TMC Control at $02200010 — accept writes (parity, burst config) */
        if (tmc_off >= 0x10 && tmc_off < 0x14)
            return;  /* accept and discard */
        /* TMC VIR write at $02200080 — write-1-to-clear status, set mask.
         * Previous: tmc_vir_write0() handles byte 0 of the 32-bit reg.
         * Value is big-endian so high byte = VIR byte. */
        if (tmc_off >= 0x80 && tmc_off < 0x84) {
            uint8_t vir_byte = (uint8_t)(value >> 24);
            /* Update mask bit from written value (normal read-write) */
            tmc_vir = (tmc_vir & ~TMC_VI_INT_MASK) | (vir_byte & TMC_VI_INT_MASK);
            /* Write-1-to-clear on status bit */
            if (vir_byte & TMC_VI_INTERRUPT) {
                tmc_vir &= ~TMC_VI_INTERRUPT;
                next_intr_clear(I_IPL3_DISK);
            }
            return;
        }
        /* TMC Video Interrupt at $02200100 — also clears VBL */
        if (tmc_off >= 0x100 && tmc_off < 0x104) {
            tmc_vir &= ~TMC_VI_INTERRUPT;
            next_intr_clear(I_IPL3_DISK);
            return;
        }
        /* ADB registers at TMC+$8000-$80FF */
        if (tmc_off >= 0x8000 && tmc_off < 0x8100) {
            uint32_t adb_reg = tmc_off - 0x8000;
            xil_printf("[ADB] W32 @%08X reg=$%02X val=$%08X PC=$%08X\r\n",
                       address, adb_reg, value, m68k_get_reg(NULL, M68K_REG_PC));
            switch (adb_reg) {
            case ADB_REG_INTSTATUS:
                adb.intstatus &= ~value;  /* write-1-to-clear */
                adb_update_irq();
                break;
            case ADB_REG_INTMASK:
                adb.intmask = value;
                adb_update_irq();
                break;
            case ADB_REG_SETINT:
                adb.intstatus |= value;
                adb_update_irq();
                break;
            case ADB_REG_CONFIG:
                adb.config = value;
                break;
            case ADB_REG_CTRL:
                /* Control register — matches Previous emulator logic */
                if (value & ADB_CTRL_RESET_ADB) {
                    adb.status &= ~ADB_STAT_POLL_EN;
                    adb.intstatus |= ADB_INT_RESET;
                }
                if (value & ADB_CTRL_XMIT_CMD) {
                    if (adb.status & (ADB_STAT_RESET | ADB_STAT_ACCESS)) {
                        adb.intstatus |= ADB_INT_REJECT;
                    } else {
                        /* No ADB devices: command times out */
                        adb.status |= ADB_STAT_TIMEOUT;
                        adb.intstatus |= ADB_INT_ACCESS;
                    }
                }
                if (value & ADB_CTRL_DIS_POLL)
                    adb.status &= ~ADB_STAT_POLL_EN;
                if (value & ADB_CTRL_EN_POLL) {
                    if ((adb.status & (ADB_STAT_RESET | ADB_STAT_ACCESS)) &&
                        !(adb.status & ADB_STAT_POLL_EN))
                        adb.intstatus |= ADB_INT_REJECT;
                    else
                        adb.status |= ADB_STAT_POLL_EN;
                }
                adb_update_irq();
                break;
            case ADB_REG_CMD:
                adb.command = value;
                break;
            case ADB_REG_COUNT:
                adb.bitcount = value;
                break;
            case ADB_REG_DATA0:
                adb.data0 = value;
                break;
            case ADB_REG_DATA1:
                adb.data1 = value;
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
uint32_t next_scr1_get(void) { return scr1_value; }
