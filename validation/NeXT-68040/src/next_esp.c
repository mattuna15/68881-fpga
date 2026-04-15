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
    esp_reset_soft();
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
    bool timeout = next_scsi_select(target);

    if (timeout) {
        esp.intstatus = INTR_DC;
        esp_command_clear();
        esp.state = ESP_DISCONNECTED;
        DPRINTF("[ESP] Select target %d: timeout\r\n", target);
        esp_raise_irq();
        return;
    }

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
        /* DMA transfer */
        int direction = (phase == SCSI_PHASE_DI) ? 1 : 0;
        int transferred = next_scsi_dma_transfer(direction, &esp.counter);

        DPRINTF("[ESP] TI DMA: phase=%d, transferred=%d, counter=%u\r\n",
                   phase, transferred, esp.counter);

        if (esp.counter == 0) {
            esp.intstatus = INTR_FC;
            esp.status |= STAT_TC;
        } else {
            /* Phase change or data exhausted */
            esp_command_clear();
            esp.intstatus = INTR_BS;
        }
        esp_raise_irq();
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
            DPRINTF("[ESP] TI PIO: unhandled phase %d\r\n", phase);
            esp.intstatus = INTR_FC;
            esp_raise_irq();
            break;
        }
    }
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
        return (esp.status & ~STAT_PHASE) | (next_scsi_get_phase() & STAT_PHASE);
    case 0x05: /* Interrupt Status — reading clears interrupt */
    {
        extern int next_debug_scsi;
        uint8_t val = esp.intstatus;
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
        esp_command_write(value);
        break;
    case 0x04: /* Select Bus ID (write) */
        esp.selectbusid = value;
        break;
    case 0x05: /* Select Timeout (write) */
        esp.selecttimeout = value;
        break;
    case 0x06: /* Sync Period (write) */
        esp.syncperiod = value;
        break;
    case 0x07: /* Sync Offset (write) */
        esp.syncoffset = value;
        break;
    case 0x08: /* Configuration */
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

uint8_t next_esp_dma_ctrl_read(void)
{
    return esp.dma_control;
}

void next_esp_dma_ctrl_write(uint8_t value)
{
    uint8_t old_ctrl = esp.dma_control;
    esp.dma_control = value;

    (void)old_ctrl;

    if (value & ESPCTRL_FLUSH) {
        /* DMA flush — no action needed in our synchronous model */
    }
    if (value & ESPCTRL_RESET) {
        DPRINTF("[ESP] DMA reset → chip reset\r\n");
        esp_reset_hard();
    }
    if (value & ESPCTRL_ENABLE_INT) {
        /* Only raise system interrupt on 0→1 transition of INT enable,
         * not when already enabled (avoids spurious re-raise during
         * DMA flush writes while scintr is processing). */
        if (!(old_ctrl & ESPCTRL_ENABLE_INT)) {
            if (esp.status & STAT_INT)
                next_intr_set(I_IPL3_SCSI);
        }
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
