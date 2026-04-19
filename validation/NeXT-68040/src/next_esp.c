/*
 * next_esp.c
 * NCR53C90 (ESP) SCSI controller emulation.
 * Adapted from Previous emulator (previous/src/esp.c).
 *
 * Synchronous model: commands complete immediately within the I/O write
 * handler. SCSI interrupt delivery is deferred to the main loop tick to
 * avoid a race with kernel polling flag setup (see next_intr_set in
 * next_devs.c).
 */

#include "next_esp.h"
#include "next_scsi.h"
#include "next_scsi_dma.h"
#include "next_devs.h"
#include "next_hw.h"
#include "next_debug.h"
#include "musashi/m68k.h"
#include "xil_printf.h"
#include <string.h>
#include <stdbool.h>

extern int next_debug_scsi;
#define DPRINTF(...) do { if (next_debug_scsi) xil_printf(__VA_ARGS__); } while(0)

/* ------------------------------------------------------------------ */
/* ESP command byte encoding                                           */
/* ------------------------------------------------------------------ */
#define CMD_DMA         0x80
#define CMD_CMD         0x7F

/* Miscellaneous commands */
#define CMD_NOP         0x00
#define CMD_FLUSH       0x01
#define CMD_RESET       0x02
#define CMD_BUSRESET    0x03

/* Initiator commands */
#define CMD_TI          0x10    /* Transfer Information */
#define CMD_ICCS        0x11    /* Initiator Command Complete Sequence */
#define CMD_MSGACC      0x12    /* Message Accepted */
#define CMD_PAD         0x18    /* Transfer Pad */
#define CMD_SATN        0x1A    /* Set ATN */

/* Disconnected commands */
#define CMD_RESEL       0x40
#define CMD_SEL         0x41
#define CMD_SELATN      0x42    /* Select with ATN */
#define CMD_SELATNS     0x43
#define CMD_ENSEL       0x44
#define CMD_DISSEL      0x45

/* ------------------------------------------------------------------ */
/* Status register bits                                                */
/* ------------------------------------------------------------------ */
#define STAT_PHASE      0x07
#define STAT_VGC        0x08    /* Valid Group Code */
#define STAT_TC         0x10    /* Transfer Count zero */
#define STAT_PE         0x20    /* Parity Error */
#define STAT_GE         0x40    /* Gross Error */
#define STAT_INT        0x80    /* Interrupt pending */

/* ------------------------------------------------------------------ */
/* Interrupt status register bits                                      */
/* ------------------------------------------------------------------ */
#define INTR_SEL        0x01
#define INTR_SELATN     0x02
#define INTR_RESEL      0x04
#define INTR_FC         0x08    /* Function Complete */
#define INTR_BS         0x10    /* Bus Service */
#define INTR_DC         0x20    /* Disconnected */
#define INTR_ILL        0x40    /* Illegal Command */
#define INTR_RST        0x80    /* Bus Reset */

/* Sequence step */
#define SEQ_0           0x00

/* Configuration register */
#define CFG1_RESREPT    0x40    /* Disable reset report */

/* Bus ID */
#define BUSID_DID       0x07

/* ESP DMA control register bits */
#define ESPCTRL_CLKMASK     0xC0
#define ESPCTRL_CLK20MHz    0x80
#define ESPCTRL_ENABLE_INT  0x20
#define ESPCTRL_MODE_DMA    0x10
#define ESPCTRL_DMA_READ    0x08
#define ESPCTRL_FLUSH       0x04
#define ESPCTRL_RESET       0x02
#define ESPCTRL_CHIP_TYPE   0x01

/* ESP DMA status register bits */
#define ESPSTAT_STATE_MASK  0x03
#define ESPSTAT_STATE_D0S1  0x01
#define ESPSTAT_STATE_D1S0  0x02

/* Max CDB size */
#define SCSI_CDB_MAX_SIZE   12

#if NEXT_DEBUG_ESP_TRACE
/* Trace flag: set by DMA loop detector, counts down ESP accesses to log */
int esp_loop_trace = 0;

/* Sticky flag: once the DMA tight-loop detector fires, every ESP cmd write
 * is logged with an instruction timestamp so we can correlate ESP activity
 * (or the lack of it) against the RESET-only loop on the DMA side. */
int esp_tight_trace = 0;
#endif

/* ------------------------------------------------------------------ */
/* ESP FIFO                                                            */
/* ------------------------------------------------------------------ */
#define ESP_FIFO_SIZE   16

/* ------------------------------------------------------------------ */
/* ESP state                                                           */
/* ------------------------------------------------------------------ */
typedef enum {
    ESP_DISCONNECTED,
    ESP_INITIATOR
} esp_state_t;

static struct {
    /* Write-only transfer count registers */
    uint8_t  writetcl, writetch;
    /* FIFO */
    uint8_t  fifo[ESP_FIFO_SIZE];
    uint8_t  fifoflags;      /* low 5 bits = FIFO byte count */
    /* Command register (dual-ranked) */
    uint8_t  command[2];
    uint8_t  cmd_state;
    #define ESP_CMD_INPROGRESS  0x01
    #define ESP_CMD_WAITING     0x02
    /* Registers */
    uint8_t  status;
    uint8_t  selectbusid;
    uint8_t  intstatus;
    uint8_t  selecttimeout;
    uint8_t  seqstep;
    uint8_t  syncperiod;
    uint8_t  syncoffset;
    uint8_t  configuration;
    uint8_t  clockconv;
    uint8_t  esptest;
    uint8_t  config2;
    /* Internal counter */
    uint32_t counter;
    uint8_t  mode_dma;
    /* ESP state */
    esp_state_t state;
    /* ESP DMA control/status */
    uint8_t  dma_control;
    uint8_t  dma_status;
} esp;

static int esp_post_probe = 0;  /* set once probing is clearly done */
int esp_cmds_since_last_sel = 0; /* commands since last SELECT */

/* ------------------------------------------------------------------ */
/* FIFO operations                                                     */
/* ------------------------------------------------------------------ */

static uint8_t esp_fifo_read(void)
{
    if (esp.fifoflags > 0) {
        uint8_t val = esp.fifo[0];
        for (int i = 0; i < ESP_FIFO_SIZE - 1; i++)
            esp.fifo[i] = esp.fifo[i + 1];
        esp.fifo[ESP_FIFO_SIZE - 1] = 0;
        esp.fifoflags--;
        return val;
    }
    DPRINTF("[ESP] FIFO read: empty!\r\n");
    return 0;
}

static void esp_raise_irq(void);

static void esp_fifo_write(uint8_t val)
{
    if (esp.fifoflags >= ESP_FIFO_SIZE) {
        DPRINTF("[ESP] FIFO write: overflow!\r\n");
        esp.fifo[ESP_FIFO_SIZE - 1] = val;
        esp.status |= STAT_GE;
        esp_raise_irq();
        return;
    } else {
        esp.fifo[esp.fifoflags] = val;
        esp.fifoflags++;
    }
}

static void esp_fifo_clear(void)
{
    memset(esp.fifo, 0, ESP_FIFO_SIZE);
    esp.fifoflags = 0;
}

/* ------------------------------------------------------------------ */
/* Interrupt management                                                */
/* ------------------------------------------------------------------ */

static void esp_finish_command(void);

/* Ring buffer to capture last ESP IRQ events */
#define ESP_IRQ_LOG_SIZE 8
static struct {
    uint8_t intstatus;
    uint8_t cmd;
    uint8_t dma_ctrl;
    uint8_t raised;  /* 1=raised, 0=suppressed */
} esp_irq_log[ESP_IRQ_LOG_SIZE];
static int esp_irq_log_idx = 0;

void esp_dump_irq_log(void)
{
    xil_printf("[ESP-IRQ] Last %d events:\r\n", ESP_IRQ_LOG_SIZE);
    for (int i = 0; i < ESP_IRQ_LOG_SIZE; i++) {
        int idx = (esp_irq_log_idx + i) % ESP_IRQ_LOG_SIZE;
        if (esp_irq_log[idx].intstatus || esp_irq_log[idx].cmd)
            xil_printf("  [%d] cmd=$%02X intstatus=$%02X dma_ctrl=$%02X %s\r\n",
                       i, esp_irq_log[idx].cmd, esp_irq_log[idx].intstatus,
                       esp_irq_log[idx].dma_ctrl,
                       esp_irq_log[idx].raised ? "RAISED" : "SUPPRESSED");
    }
}

static void esp_raise_irq(void)
{
    extern int next_debug_scsi;
    /* Log every IRQ attempt to ring buffer */
    esp_irq_log[esp_irq_log_idx].intstatus = esp.intstatus;
    esp_irq_log[esp_irq_log_idx].cmd = esp.command[0];
    esp_irq_log[esp_irq_log_idx].dma_ctrl = esp.dma_control;

    if (!(esp.status & STAT_INT)) {
        esp.status |= STAT_INT;
        if (esp.dma_control & ESPCTRL_ENABLE_INT) {
            esp_irq_log[esp_irq_log_idx].raised = 1;
            if (next_debug_scsi)
                xil_printf("[ESP-IRQ] RAISE: intstatus=$%02X status=$%02X dma_ctrl=$%02X\r\n",
                           esp.intstatus, esp.status, esp.dma_control);
            next_intr_set(I_IPL3_SCSI);
        } else {
            esp_irq_log[esp_irq_log_idx].raised = 0;
            /* Log INT-disabled suppression after probe phase */
            if (esp_post_probe)
                xil_printf("[ESP-IRQ] SUPPRESS (INT disabled): intstatus=$%02X dma=$%02X\r\n",
                           esp.intstatus, esp.dma_control);
        }
    } else {
        esp_irq_log[esp_irq_log_idx].raised = 0;
        /* Log double-INT suppression after probe phase */
        if (esp_post_probe)
            xil_printf("[ESP-IRQ] SUPPRESS (STAT_INT set): intstatus=$%02X cmd=$%02X\r\n",
                       esp.intstatus, esp.command[0]);
    }
    esp_irq_log_idx = (esp_irq_log_idx + 1) % ESP_IRQ_LOG_SIZE;
}

static void esp_lower_irq(void)
{
    extern int next_debug_scsi;
    if (esp.status & STAT_INT) {
        if (next_debug_scsi)
            xil_printf("[ESP-IRQ] LOWER: was intstatus=$%02X\r\n", esp.intstatus);
        esp.status &= ~STAT_INT;
        next_intr_clear(I_IPL3_SCSI);
        esp_finish_command();
    }
}

/* ------------------------------------------------------------------ */
/* Command management                                                  */
/* ------------------------------------------------------------------ */

static void esp_start_command(uint8_t cmd);

static void esp_finish_command(void)
{
    esp.cmd_state &= ~ESP_CMD_INPROGRESS;
    if (esp.cmd_state & ESP_CMD_WAITING) {
        esp.command[0] = esp.command[1];
        esp.command[1] = 0;
        esp.cmd_state &= ~ESP_CMD_WAITING;
        esp_start_command(esp.command[0]);
    }
}

static void esp_command_clear(void)
{
    esp.command[0] = 0;
    if ((esp.command[1] & CMD_CMD) != CMD_RESET) {
        esp.command[1] = 0;
        esp.cmd_state &= ~ESP_CMD_WAITING;
    }
}

static void esp_command_write(uint8_t cmd)
{
    /* Log all commands — SELECT prominently */
    if ((cmd & 0x7F) == 0x42 || (cmd & 0x7F) == 0x41)
        DPRINTF("\r\n*** SELECT $%02X ***\r\n", cmd);
    else
        DPRINTF("[ESP] Cmd $%02X\r\n", cmd);

    if ((esp.command[1] & CMD_CMD) == CMD_RESET && (cmd & CMD_CMD) != CMD_NOP) {
        DPRINTF("[ESP] Chip reset in command register, ignoring command $%02X\r\n", cmd);
        return;
    }

    esp.command[1] = cmd;

    if (esp.cmd_state & ESP_CMD_WAITING) {
        DPRINTF("[ESP] Command overwritten!\r\n");
        esp.status |= STAT_GE;
    }

    if ((cmd & CMD_CMD) == CMD_RESET || (cmd & CMD_CMD) == CMD_BUSRESET) {
        esp_start_command(cmd);
        return;
    }

    if (esp.cmd_state & ESP_CMD_INPROGRESS) {
        esp.cmd_state |= ESP_CMD_WAITING;
        DPRINTF("[ESP] Cmd $%02X QUEUED (inprog)\r\n", cmd);
    } else {
        esp.command[0] = esp.command[1];
        esp.command[1] = 0;
        esp_start_command(esp.command[0]);
    }
}

/* ------------------------------------------------------------------ */
/* Reset                                                               */
/* ------------------------------------------------------------------ */

static void esp_select_timeout_cancel(void);

static void esp_reset_soft(void)
{
    esp.status &= ~STAT_TC;
    esp.intstatus = 0;  /* defense in depth — harmless if caller already cleared */
    esp.mode_dma = 0;
    esp.counter = 0;
    esp.seqstep = 0;
    esp.cmd_state = 0;  /* Clear INPROGRESS + WAITING */
    esp.command[0] = 0;
    esp.command[1] = 0;
    esp.state = ESP_DISCONNECTED;
    /* Cancel any pending SELECT TIMEOUT: its deferred IRQ would fire
     * ~500 instructions later against whatever intstatus the caller of
     * this reset installed, producing a spurious second IRQ.  Only the
     * hard-reset path used to cancel; any caller of soft-reset
     * (bus-reset, etc.) needs the same protection. */
    esp_select_timeout_cancel();
}

static void esp_reset_hard(void)
{
    DPRINTF("[ESP] Hard reset\r\n");
    esp.clockconv = 0x02;
    esp.configuration &= ~0xF8;
    esp_fifo_clear();
    esp.syncperiod = 0x05;
    esp.syncoffset = 0x00;
    esp.status &= ~STAT_INT;
    next_intr_clear(I_IPL3_SCSI);
    esp.intstatus = 0x00;
    esp.status &= ~(STAT_VGC | STAT_PE | STAT_GE);
    esp_reset_soft();  /* cancels pending select-timeout inside */
    esp_finish_command();
}

/* ------------------------------------------------------------------ */
/* Bus reset                                                           */
/* ------------------------------------------------------------------ */

extern void sfa_dump(void);
extern unsigned int m68k_read_memory_32(unsigned int address);

static void esp_bus_reset(void)
{
    if (esp_post_probe) {
        static int busrst_count = 0;
        if (busrst_count++ < 2) {
            extern int esp_cmds_since_last_sel;
            uint32_t pc = m68k_get_reg(NULL, M68K_REG_PC);
            uint32_t sp = m68k_get_reg(NULL, M68K_REG_A7);
            xil_printf("[BUSRST] PC=$%08X SP=$%08X cmds_since_sel=%d\r\n",
                       pc, sp, esp_cmds_since_last_sel);
            /* Dump stack to see full caller chain */
            xil_printf("[BUSRST] Stack: ");
            for (int i = 0; i < 16; i++)
                xil_printf("%08X ", m68k_read_memory_32(sp + i*4));
            xil_printf("\r\n");
            /* Dump 256 bytes from scsi_ctrl to find sc_ipl/sc_target */
            uint32_t scp_addr = m68k_read_memory_32(0x040C69D4); /* s5c_scp */
            xil_printf("[SC-CTRL] scp=$%08X dump 256 bytes:\r\n", scp_addr);
            for (int off = 0; off < 256; off += 16) {
                xil_printf("  +$%02X: ", off);
                for (int b = 0; b < 16; b++)
                    xil_printf("%02X", m68k_read_memory_8(scp_addr + off + b));
                xil_printf("\r\n");
            }
        }
    }
    /* Reset SCSI read + DMA verify + ATC fault logs so we see kernel-driven activity */
    { extern void next_scsi_reset_read_log(void); next_scsi_reset_read_log(); }
    { extern int dma_verify_log; dma_verify_log = 0; }
    { extern int mmu040_fault_total, mmu040_fault_reset_at;
      mmu040_fault_reset_at = mmu040_fault_total; }
    DPRINTF("[ESP] Bus reset\r\n");
    esp_reset_soft();
    if (!(esp.configuration & CFG1_RESREPT)) {
        esp.intstatus = INTR_RST;
        next_scsi_set_phase(SCSI_PHASE_MI);
        esp_raise_irq();
    } else {
        esp_finish_command();
    }
}

/* ------------------------------------------------------------------ */
/* Deferred SELECT TIMEOUT                                             */
/* ------------------------------------------------------------------ */
/* Matches Previous's CycInt_AddRelativeInterruptUs(seltout, 0, ESP)
 * semantics: the real 53C9x waits ~250 µs (the programmed
 * selecttimeout × 8192 × clockconv / ESP_CLOCK_FREQ) before signalling
 * DISCONNECT on selection timeout.  During those microseconds the
 * kernel's scstart → sfa_arbitrate → sc_dostart → scsi_expectintr →
 * scsi_pollcmd return path completes.  Our previous implementation
 * fired the IRQ ~10 instructions after the CMD_SELATN write — which
 * lands mid-way through sc_dostart, before scsi_expectintr sets
 * sc_expectintr=1, so scintr gets confused.  Defer by a constant
 * instruction count instead; the ~500 tick value is empirically chosen
 * to cover sc_dostart's remaining lines + returns + scsi_pollcmd's
 * first splx/DELAY entry. */

#define ESP_SELECT_TIMEOUT_DEFER_TICKS  500

static struct {
    int pending;
    int countdown;
} esp_select_to_deferred;

int next_esp_select_timeout_tick(void)
{
    if (!esp_select_to_deferred.pending)
        return 0;
    if (--esp_select_to_deferred.countdown > 0)
        return 0;
    esp_select_to_deferred.pending = 0;
    esp_raise_irq();
    return 1;
}

static void esp_select_timeout_cancel(void)
{
    esp_select_to_deferred.pending = 0;
}

/* ------------------------------------------------------------------ */
/* Select with/without ATN                                             */
/* ------------------------------------------------------------------ */

static void esp_select(bool atn)
{
    esp.seqstep = 0;

    uint8_t target = esp.selectbusid & BUSID_DID;
    /* Unconditional: track every SELECT to see if scsi_pollcmd's command executes */
    {
        static int sel_count = 0;
        sel_count++;
        esp_cmds_since_last_sel = 0;  /* reset counter */
        (void)sel_count;
    }

    /* Overlap: if a previous SELECT's timeout is still pending when a
     * new SELECT arrives, the earlier IRQ has not been delivered yet.
     * The real hardware would have either accepted the first IRQ (and
     * the driver would not re-SELECT without ack'ing INTR_DC), or the
     * driver explicitly ack'd and cleared.  Either way the safer action
     * is to flush the stale deferral — but log it, because reaching here
     * typically signals a driver bug upstream. */
    if (esp_select_to_deferred.pending) {
        xil_printf("[ESP-SELECT-OVERLAP] new select target=%d while prior "
                   "timeout pending (countdown=%d); flushing stale IRQ\r\n",
                   target, esp_select_to_deferred.countdown);
        esp_select_timeout_cancel();
    }

    bool timeout = next_scsi_select(target);

    if (timeout) {
        /* State is visible immediately (consistent with a register
         * read in the window), but the IRQ is deferred. */
        esp.intstatus = INTR_DC;
        esp_command_clear();
        esp.state = ESP_DISCONNECTED;
        DPRINTF("[ESP] Select target %d: timeout (deferred %d ticks)\r\n",
                target, ESP_SELECT_TIMEOUT_DEFER_TICKS);
        esp_select_to_deferred.pending   = 1;
        esp_select_to_deferred.countdown = ESP_SELECT_TIMEOUT_DEFER_TICKS;
        return;
    }

    /* Non-timeout path: any previously scheduled timeout was already
     * cancelled by the overlap guard above. */

    /* Read identify message and CDB from FIFO */
    uint8_t identify_msg = 0;
    uint8_t commandbuf[SCSI_CDB_MAX_SIZE];
    int cmd_size = 0;

    if (atn) {
        next_scsi_set_phase(SCSI_PHASE_MO);
        esp.seqstep = 1;
        identify_msg = esp_fifo_read();
        DPRINTF("[ESP] Select: IDENTIFY=$%02X\r\n", identify_msg);
    }

    next_scsi_set_phase(SCSI_PHASE_CD);
    esp.seqstep = 3;
    for (cmd_size = 0; cmd_size < SCSI_CDB_MAX_SIZE && esp.fifoflags > 0; cmd_size++) {
        commandbuf[cmd_size] = esp_fifo_read();
    }
    DPRINTF("[ESP] Select: target=%d, CDB size=%d, opcode=$%02X\r\n",
               target, cmd_size, cmd_size > 0 ? commandbuf[0] : 0xFF);

#if NEXT_DEBUG_ESP_TRACE
    /* CDB logging — distinguishes "kernel retrying same read (static LBA)"
     * vs "kernel progressing through sectors (incrementing LBA)" vs
     * "kernel stopped issuing CDBs (abort-wait)". */
    {
        static int cdb_log;
        if (cdb_log < 200 || (cdb_log % 500) == 0) {
            const char *opname = "?";
            uint32_t lba = 0, xferlen = 0;
            if (cmd_size > 0) {
                uint8_t op = commandbuf[0];
                switch (op) {
                case 0x00: opname = "TUR";        break;
                case 0x03: opname = "REQ_SENSE";  break;
                case 0x08: opname = "READ(6)";
                    lba = ((uint32_t)(commandbuf[1] & 0x1F) << 16)
                        | ((uint32_t)commandbuf[2] << 8)
                        |  (uint32_t)commandbuf[3];
                    xferlen = commandbuf[4] ? commandbuf[4] : 256;
                    break;
                case 0x0A: opname = "WRITE(6)";   break;
                case 0x12: opname = "INQUIRY";    xferlen = commandbuf[4]; break;
                case 0x15: opname = "MODE_SELECT(6)"; break;
                case 0x1A: opname = "MODE_SENSE(6)";  xferlen = commandbuf[4]; break;
                case 0x25: opname = "READ_CAPACITY";  break;
                case 0x28: opname = "READ(10)";
                    lba = ((uint32_t)commandbuf[2] << 24)
                        | ((uint32_t)commandbuf[3] << 16)
                        | ((uint32_t)commandbuf[4] << 8)
                        |  (uint32_t)commandbuf[5];
                    xferlen = ((uint32_t)commandbuf[7] << 8) | commandbuf[8];
                    break;
                case 0x2A: opname = "WRITE(10)";
                    lba = ((uint32_t)commandbuf[2] << 24)
                        | ((uint32_t)commandbuf[3] << 16)
                        | ((uint32_t)commandbuf[4] << 8)
                        |  (uint32_t)commandbuf[5];
                    xferlen = ((uint32_t)commandbuf[7] << 8) | commandbuf[8];
                    break;
                }
            }
            xil_printf("[ESP-CDB] #%d tgt=%d %s op=$%02X lba=%u len=%u cdb:",
                       cdb_log, target, opname,
                       cmd_size > 0 ? commandbuf[0] : 0xFF,
                       lba, xferlen);
            for (int i = 0; i < cmd_size && i < 12; i++)
                xil_printf(" %02X", commandbuf[i]);
            xil_printf(" instr=%u\r\n", (uint32_t)emu_instr_count);
        }
        cdb_log++;
    }
#endif

    next_scsi_receive_command(commandbuf, cmd_size, identify_msg);
    esp.seqstep = 4;
    esp_command_clear();

    esp.intstatus = INTR_BS | INTR_FC;
    esp.state = ESP_INITIATOR;
    esp_raise_irq();
}

/* ------------------------------------------------------------------ */
/* Transfer Information                                                */
/* ------------------------------------------------------------------ */

static void esp_transfer_info(void)
{
    uint8_t phase = next_scsi_get_phase();

    if (esp.mode_dma) {
        /* Defer DMA transfer so the completion interrupt fires on a
         * later instruction boundary.  Synchronous completion inside
         * this write-callback meant the DMA_COMPLETE bit was set and
         * then cleared by the kernel's very next RESET instruction
         * before the CPU could take the interrupt.  Deferring by even
         * 2 instructions lets the CPU sample the IRQ6 line first. */
        int direction = (phase == SCSI_PHASE_DI) ? 1 : 0;
        DPRINTF("[ESP] TI DMA: phase=%d, counter=%u — deferring\r\n",
                   phase, esp.counter);
        next_scsi_dma_start_deferred(direction, esp.counter);
        /* Don't raise IRQ yet — esp_deferred_dma_complete will do it */
        return;
    } else {
        /* PIO transfer */
        switch (phase) {
        case SCSI_PHASE_DI:
            esp_fifo_write(next_scsi_send_data());
            esp.intstatus = INTR_FC;
            esp_raise_irq();
            break;
        case SCSI_PHASE_MI:
            /* Message byte already available via ICCS */
            esp.intstatus = INTR_FC;
            esp_raise_irq();
            break;
        case SCSI_PHASE_ST:
            DPRINTF("[ESP] TI PIO: status phase (unexpected)\r\n");
            esp.intstatus = INTR_FC;
            esp_raise_irq();
            break;
        default:
            /* Unhandled phase in PIO transfer is a driver/hardware
             * mismatch — the real 53C9x raises INTR_ILL (Illegal
             * command), not INTR_FC (Function Complete).  Raising FC
             * lied to the driver that the transfer succeeded, masking
             * phase-tracking bugs.  Log at error level so the next
             * occurrence is visible. */
            xil_printf("[ESP] TI PIO: unhandled phase %d at PC=$%08X — raising INTR_ILL\r\n",
                       phase, m68k_get_reg(NULL, M68K_REG_PC));
            esp.intstatus = INTR_ILL;
            esp.seqstep = 0;
            esp_raise_irq();
            break;
        }
    }
}

/* ------------------------------------------------------------------ */
/* Deferred DMA completion callback (called from DMA tick)             */
/* ------------------------------------------------------------------ */

void esp_deferred_dma_complete(uint32_t remaining, int bytes)
{
    esp.counter = remaining;

    DPRINTF("[ESP] Deferred DMA done: %d bytes, counter=%u\r\n",
               bytes, remaining);

    if (esp.counter == 0) {
        esp.intstatus = INTR_FC;
        esp.status |= STAT_TC;
    } else {
        esp_command_clear();
        esp.intstatus = INTR_BS;
    }
    esp_raise_irq();
}

/* ------------------------------------------------------------------ */
/* Initiator Command Complete Sequence                                 */
/* ------------------------------------------------------------------ */

static void esp_initiator_command_complete(void)
{
    /* ICCS drives the bus from STATUS → MSG-IN explicitly.
     * Matches Previous's architecture where the ESP layer owns phase
     * transitions (see previous/src/esp.c: esp_message_accepted et al). */
    uint8_t st = next_scsi_send_status();
    esp_fifo_write(st);

    /* Advance bus to MSG-IN so the follow-up FIFO read hands over the
     * command-complete message byte. */
    next_scsi_set_phase(SCSI_PHASE_MI);

    uint8_t msg = next_scsi_send_message();
    esp_fifo_write(msg);

    esp.intstatus = INTR_FC;
    esp_raise_irq();
    DPRINTF("[ESP] ICCS: status=$%02X msg=$%02X\r\n", st, msg);
}

/* ------------------------------------------------------------------ */
/* Message Accepted                                                    */
/* ------------------------------------------------------------------ */

static void esp_message_accepted(void)
{
    next_scsi_set_phase(SCSI_PHASE_ST);
    esp.intstatus = INTR_BS;
    esp.state = ESP_DISCONNECTED;
    esp_raise_irq();
}

/* ------------------------------------------------------------------ */
/* Transfer Pad                                                        */
/* ------------------------------------------------------------------ */

static void esp_transfer_pad(void)
{
    uint8_t phase = next_scsi_get_phase();
    DPRINTF("[ESP] Transfer pad: phase=%d counter=%u\r\n", phase, esp.counter);

    if (phase == SCSI_PHASE_DI) {
        while (next_scsi_get_phase() == SCSI_PHASE_DI && esp.counter > 0) {
            next_scsi_send_data();
            esp.counter--;
        }
    }

    if (esp.counter == 0) {
        esp.intstatus = INTR_FC;
        esp.status |= STAT_TC;
    } else {
        esp_command_clear();
        esp.intstatus = INTR_BS;
    }
    esp_raise_irq();
}

/* ------------------------------------------------------------------ */
/* Command dispatch                                                    */
/* ------------------------------------------------------------------ */

static void esp_start_command(uint8_t cmd)
{
    esp.cmd_state |= ESP_CMD_INPROGRESS;

    /* Log all ESP commands after probe phase */
    if (esp_post_probe)
        esp_cmds_since_last_sel++;

    /* Load counter for DMA commands */
    if (cmd & CMD_DMA) {
        esp.counter = esp.writetcl | ((uint32_t)esp.writetch << 8);
        if (esp.counter == 0)
            esp.counter = 0x10000;
        esp.status &= ~STAT_TC;
        esp.mode_dma = 1;
    } else {
        esp.mode_dma = 0;
    }

    switch (cmd & CMD_CMD) {
    case CMD_NOP:
        esp_finish_command();
        break;
    case CMD_FLUSH:
        DPRINTF("[ESP] Flush FIFO\r\n");
        esp_fifo_clear();
        esp_finish_command();
        break;
    case CMD_RESET:
        esp_reset_hard();
        break;
    case CMD_BUSRESET:
        esp_bus_reset();
        break;
    case CMD_SEL:
        DPRINTF("[ESP] Select without ATN\r\n");
        esp_select(false);
        break;
    case CMD_SELATN:
        DPRINTF("[ESP] Select with ATN\r\n");
        esp_select(true);
        break;
    case CMD_SELATNS:
        /* Select with ATN + Stop after identify/message byte.  A driver
         * uses this to send a message before issuing the CDB.  The NeXT
         * SCSI driver never issues it (it uses plain CMD_SELATN), but
         * Previous (esp.c:496-499) calls abort() here — we instead flag
         * it as illegal so an emulator mistake doesn't take down the
         * whole process.  Clear seqstep: a driver reading it after
         * INTR_ILL would otherwise get the stale value from the prior
         * command. */
        DPRINTF("[ESP] Select-with-ATN-and-stop not implemented\r\n");
        esp_command_clear();
        esp.seqstep = 0;
        esp.intstatus |= INTR_ILL;
        esp_raise_irq();
        break;
    case CMD_RESEL:
        /* Enable reselection as a target.  NeXT is a single-initiator
         * bus; the kernel never puts the ESP into target mode.  Flag
         * as illegal (matches Previous's abort()) rather than silently
         * ignoring. */
        DPRINTF("[ESP] Reselect (target mode) not implemented\r\n");
        esp_command_clear();
        esp.seqstep = 0;
        esp.intstatus |= INTR_ILL;
        esp_raise_irq();
        break;
    case CMD_TI:
        esp_transfer_info();
        break;
    case CMD_ICCS:
        esp_initiator_command_complete();
        break;
    case CMD_MSGACC:
        esp_message_accepted();
        break;
    case CMD_PAD:
        esp_transfer_pad();
        break;
    case CMD_ENSEL:
        /* Enable selection/reselection — just finish, we don't reselect */
        esp_finish_command();
        break;
    case CMD_DISSEL:
        esp_finish_command();
        break;
    default:
        DPRINTF("[ESP] Unknown command $%02X\r\n", cmd & CMD_CMD);
        esp_command_clear();
        esp.seqstep = 0;
        esp.intstatus |= INTR_ILL;
        esp_raise_irq();
        break;
    }
}

/* ------------------------------------------------------------------ */
/* Public: register read/write                                         */
/* ------------------------------------------------------------------ */

void next_esp_init(void)
{
    memset(&esp, 0, sizeof(esp));
    esp.clockconv = 0x02;
    esp.syncperiod = 0x05;
    esp.state = ESP_DISCONNECTED;
    DPRINTF("[ESP] NCR53C90 initialised\r\n");
}

uint8_t next_esp_read(uint32_t offset)
{
    switch (offset) {
    case 0x00: /* Transfer Count LSB */
        return esp.counter & 0xFF;
    case 0x01: /* Transfer Count MSB */
        return (esp.counter >> 8) & 0xFF;
    case 0x02: /* FIFO */
        return esp_fifo_read();
    case 0x03: /* Command */
        return esp.command[0];
    case 0x04: /* Status */
    {
        uint8_t sval = (esp.status & ~STAT_PHASE) | (next_scsi_get_phase() & STAT_PHASE);
#if NEXT_DEBUG_ESP_TRACE
        if (esp_loop_trace > 0) {
            esp_loop_trace--;
            xil_printf("[ESP-T] R status=$%02X PC=$%08X\r\n", sval,
                       m68k_get_reg(NULL, M68K_REG_PC));
        }
#endif
        return sval;
    }
    case 0x05: /* Interrupt Status — reading clears interrupt */
    {
        extern int next_debug_scsi;
        uint8_t val = esp.intstatus;
#if NEXT_DEBUG_ESP_TRACE
        if (esp_loop_trace > 0) {
            esp_loop_trace--;
            xil_printf("[ESP-T] R intrstatus=$%02X STAT_INT=%d PC=$%08X\r\n",
                       val, !!(esp.status & STAT_INT),
                       m68k_get_reg(NULL, M68K_REG_PC));
        }
#endif
        if (next_debug_scsi)
            DPRINTF("[ESP] R intrstat=$%02X stat=$%02X (INT=%d)\r\n",
                       val, esp.status, !!(esp.status & STAT_INT));
        if (esp.status & STAT_INT) {
            esp.intstatus = 0;
            esp.status &= ~(STAT_VGC | STAT_PE | STAT_GE);
            esp_lower_irq();
        }
        return val;
    }
    case 0x06: /* Sequence Step */
        return esp.seqstep;
    case 0x07: /* FIFO Flags */
        return esp.fifoflags;
    case 0x08: /* Configuration */
        return esp.configuration;
    case 0x09: /* Clock Conversion (write-only, read returns 0) */
        return 0;
    case 0x0A: /* Test (write-only) */
        return 0;
    case 0x0B: /* Configuration 2 — read/write for 53C90A detection */
        return esp.config2;
    default:
        return 0;
    }
}

void next_esp_write(uint32_t offset, uint8_t value)
{
    switch (offset) {
    case 0x00: /* Transfer Count LSB */
        esp.writetcl = value;
        break;
    case 0x01: /* Transfer Count MSB */
        esp.writetch = value;
        break;
    case 0x02: /* FIFO */
        esp_fifo_write(value);
        break;
    case 0x03: /* Command */
#if NEXT_DEBUG_ESP_TRACE
        if (esp_loop_trace > 0) {
            esp_loop_trace--;
            xil_printf("[ESP-T] W cmd=$%02X PC=$%08X\r\n", value,
                       m68k_get_reg(NULL, M68K_REG_PC));
        }
        if (esp_tight_trace) {
            static int tight_cmd_log = 0;
            if (tight_cmd_log < 200) {
                xil_printf("[ESP-CMD] #%d cmd=$%02X mode_dma=%d PC=$%08X instr=%u\r\n",
                           tight_cmd_log, value, esp.mode_dma,
                           m68k_get_reg(NULL, M68K_REG_PC),
                           (uint32_t)emu_instr_count);
                tight_cmd_log++;
            }
        }
#endif
        esp_command_write(value);
        break;
    case 0x04: /* Select Bus ID (write) */
        esp.selectbusid = value;
        break;
    case 0x05: /* Select Timeout (write) */
        esp.selecttimeout = value;
        break;
    /* Sync Period / Sync Offset are stored for readback only.  A real
     * 53C90A applies them during the SDTR (Synchronous Data Transfer
     * Request) message-in/out negotiation that precedes each data
     * transfer.  We don't emulate the message-phase handshake — all
     * data transfers run through esp_transfer_info which drives the
     * SCSI buffer directly — so the synchronous-mode timing these
     * registers control is irrelevant.  NeXT uses asynchronous mode
     * anyway (syncoffset stays at 0); we store the values so the
     * driver's write-then-read sanity check succeeds. */
    case 0x06: /* Sync Period (write) */
        esp.syncperiod = value;
        break;
    case 0x07: /* Sync Offset (write) */
        esp.syncoffset = value;
        break;
    case 0x08: /* Configuration */
#if NEXT_DEBUG_ESP_TRACE
        if (esp_loop_trace > 0) {
            esp_loop_trace--;
            xil_printf("[ESP-T] W config=$%02X PC=$%08X\r\n", value,
                       m68k_get_reg(NULL, M68K_REG_PC));
        }
#endif
        esp.configuration = value;
        break;
    case 0x09: /* Clock Conversion */
        esp.clockconv = value;
        break;
    case 0x0A: /* Test */
        esp.esptest = value;
        break;
    case 0x0B: /* Configuration 2 (53C90A) */
        esp.config2 = value;
        break;
    default:
        break;
    }
}

/* ------------------------------------------------------------------ */
/* ESP DMA control/status at 0x02014020-0x02014021                     */
/* ------------------------------------------------------------------ */

void esp_dump_state(void)
{
    xil_printf("[ESP-STATE] status=$%02X intstatus=$%02X seqstep=$%02X fifo=%d\r\n",
               esp.status, esp.intstatus, esp.seqstep, esp.fifoflags);
    xil_printf("[ESP-STATE] cmd[0]=$%02X cmd[1]=$%02X cmd_state=$%02X counter=%u\r\n",
               esp.command[0], esp.command[1], esp.cmd_state, esp.counter);
    xil_printf("[ESP-STATE] state=%s dma_ctrl=$%02X dma_status=$%02X mode_dma=%d\r\n",
               esp.state == ESP_DISCONNECTED ? "DISCONNECTED" : "INITIATOR",
               esp.dma_control, esp.dma_status, esp.mode_dma);
    xil_printf("[ESP-STATE] SCSI phase=%d post_probe=%d cmds_since_sel=%d\r\n",
               next_scsi_get_phase(), esp_post_probe, esp_cmds_since_last_sel);
}

uint8_t next_esp_dma_ctrl_read(void)
{
    return esp.dma_control;
}

void next_esp_dma_ctrl_write(uint8_t value)
{
    uint8_t old_ctrl = esp.dma_control;
    esp.dma_control = value;

#if NEXT_DEBUG_ESP_TRACE
    if (esp_loop_trace > 0) {
        esp_loop_trace--;
        xil_printf("[ESP-T] W dma_ctrl=$%02X (old=$%02X) STAT_INT=%d PC=$%08X\r\n",
                   value, old_ctrl, !!(esp.status & STAT_INT),
                   m68k_get_reg(NULL, M68K_REG_PC));
    }
#endif

    (void)old_ctrl;

    if (value & ESPCTRL_FLUSH) {
        /* DMA flush — no action needed in our synchronous model */
    }
    if (value & ESPCTRL_RESET) {
        DPRINTF("[ESP] DMA reset → chip reset\r\n");
        esp_reset_hard();
    }
    if (value & ESPCTRL_ENABLE_INT) {
        /* Level-sensitive: whenever ENABLE_INT is written and STAT_INT
         * is pending in the ESP, assert the system interrupt.  Real
         * hardware holds the interrupt line active as long as both
         * conditions are true.  The previous edge-triggered (0→1 only)
         * implementation missed re-assertions when the kernel wrote
         * ENABLE_INT while it was already set, causing the screset →
         * scsi_restart loop to spin without ever delivering the SCSI
         * interrupt. */
        if (esp.status & STAT_INT)
            next_intr_set(I_IPL3_SCSI);
    } else {
        next_intr_clear(I_IPL3_SCSI);
    }
}

uint8_t next_esp_dma_status_read(void)
{
    return esp.dma_status;
}

void next_esp_dma_status_write(uint8_t value)
{
    esp.dma_status = value;
}
