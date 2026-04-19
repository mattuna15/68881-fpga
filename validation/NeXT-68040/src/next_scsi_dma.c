/*
 * next_scsi_dma.c
 * DMA data registers and transfer engine for SCSI channel (channel 0).
 * Adapted from Previous emulator (previous/src/dma.c).
 *
 * Simplified: synchronous transfer, no burst buffer, direct memory access.
 * Uses 68040 Turbo DMA CSR bit format.
 */

#include "next_scsi_dma.h"
#include "next_scsi.h"
#include "musashi/m68k.h"
#include "next_memory.h"
#include "next_hw.h"
#include "next_devs.h"
#include "next_debug.h"
#include "xil_printf.h"
#include <string.h>
#include <stdbool.h>

/* Quiet mode: all DMA prints go through debug toggle */
extern int next_debug_scsi;

/* DMA verification log counter — reset after kernel BUSRST */
int dma_verify_log = 0;
#define DPRINTF(...) do { if (next_debug_scsi) xil_printf(__VA_ARGS__); } while(0)

/* ------------------------------------------------------------------ */
/* Turbo DMA CSR bits (68040 format)                                   */
/* ------------------------------------------------------------------ */
/* Read bits (upper byte) */
#define TDMA_ENABLE         0x01000000
#define TDMA_SUPDATE        0x02000000
#define TDMA_COMPLETE       0x08000000
#define TDMA_BUSEXC         0x10000000

/* Write bits (bits 16-23) */
#define TDMA_SETENABLE      0x00010000
#define TDMA_SETSUPDATE     0x00020000
#define TDMA_DEV2M          0x00040000
#define TDMA_CLRCOMPLETE    0x00080000
#define TDMA_RESET          0x00100000

/* ------------------------------------------------------------------ */
/* DMA channel state                                                   */
/* ------------------------------------------------------------------ */
static struct {
    uint32_t next;      /* current DMA address pointer */
    uint32_t limit;     /* DMA transfer end address */
    uint32_t start;     /* chained: next buffer start */
    uint32_t stop;      /* chained: next buffer limit */
    uint32_t csr;       /* internal CSR (using 68030-style low bits for convenience) */
    uint8_t  direction; /* 0 = mem→dev, non-zero = dev→mem */
    /* Saved/scratchpad registers (0x02004000-0x0200400F) — the kernel's
     * DMA_W macro writes these and retries until readback matches. */
    uint32_t saved_next;
    uint32_t saved_limit;
    uint32_t saved_start;
    uint32_t saved_stop;
    /* Init buffer register (0x02004210) — also read/write scratchpad */
    uint32_t initbuf;
} dma;

/* Internal CSR bits (68030-style, for state tracking) */
#define DMA_ENABLE      0x01
#define DMA_SUPDATE     0x02
#define DMA_COMPLETE    0x08
#define DMA_BUSEXC      0x10
#define DMA_DEV2M       0x04

/* ------------------------------------------------------------------ */
/* Deferred DMA completion                                             */
/* ------------------------------------------------------------------ */
/* On real hardware, DMA takes many bus cycles. Our synchronous model
 * completes instantly inside the ESP command write callback, which means
 * the DMA_COMPLETE interrupt is set before Musashi finishes the current
 * instruction. The kernel's very next instruction writes RESET to DMA
 * CSR, clearing the interrupt before the CPU ever takes it.
 *
 * Fix: buffer the transfer parameters when ESP issues TI+DMA, and
 * complete the transfer from the instruction hook after a short delay.
 * This lets the CPU take the DMA interrupt naturally. */

static struct {
    int      pending;       /* non-zero if a deferred transfer is waiting */
    int      countdown;     /* instructions remaining before completion */
    int      direction;     /* 0=mem→dev, 1=dev→mem */
    uint32_t esp_counter;   /* ESP transfer counter (copied from ESP) */
} dma_deferred;

#define DMA_DEFER_TICKS  20 /* complete after 20 instructions — must be long
                             * enough that the CPU takes the IPL6 DMA interrupt
                             * before the kernel code path reaches the next
                             * dma_start → DMA CSR RESET write.  Musashi checks
                             * interrupts at instruction END, not START, so the
                             * tick (which fires at instruction start) needs at
                             * least 1 extra instruction after setting IRQ. */

#if NEXT_DEBUG_DMA
/* ------------------------------------------------------------------ */
/* CSR-write ring buffer for post-mortem diagnostics                   */
/* ------------------------------------------------------------------ */
#define DMA_WR_RING_SIZE 64
static struct {
    uint32_t instr;
    uint32_t value;
    uint32_t pc;
} dma_wr_ring[DMA_WR_RING_SIZE];
static int dma_wr_ring_idx;

uint32_t next_scsi_dma_get_csr(void)      { return dma.csr; }
int      next_scsi_dma_get_pending(void)  { return dma_deferred.pending; }
int      next_scsi_dma_get_countdown(void){ return dma_deferred.countdown; }

void next_scsi_dma_dump_write_ring(void)
{
    xil_printf("[DMA-RING] recent CSR writes (oldest→newest):\r\n");
    for (int i = 0; i < DMA_WR_RING_SIZE; i++) {
        int k = (dma_wr_ring_idx + i) % DMA_WR_RING_SIZE;
        if (dma_wr_ring[k].pc == 0 && dma_wr_ring[k].value == 0)
            continue;
        xil_printf("  instr=%u val=$%08X PC=$%08X\r\n",
                   dma_wr_ring[k].instr,
                   dma_wr_ring[k].value,
                   dma_wr_ring[k].pc);
    }
}
#endif /* NEXT_DEBUG_DMA */

/* ------------------------------------------------------------------ */
/* Init                                                                */
/* ------------------------------------------------------------------ */

void next_scsi_dma_init(void)
{
    memset(&dma, 0, sizeof(dma));
    dma.csr = DMA_COMPLETE;
    memset(&dma_deferred, 0, sizeof(dma_deferred));
}

/* ------------------------------------------------------------------ */
/* DMA data register read/write (0x02004010-0x0200401F)                */
/* ------------------------------------------------------------------ */

uint32_t next_scsi_dma_reg_read(uint32_t addr)
{
    uint32_t off = addr & 0x1FFFF; /* mask to I/O segment */
    switch (off) {
    /* Saved/scratchpad registers (kernel DMA_W retries until readback matches) */
    case 0x4000: return dma.saved_next;
    case 0x4004: return dma.saved_limit;
    case 0x4008: return dma.saved_start;
    case 0x400C: return dma.saved_stop;
    /* Active DMA registers */
    case 0x4010: return dma.next;
    case 0x4014: return dma.limit;
    case 0x4018: return dma.start;
    case 0x401C: return dma.stop;
    /* DMA Init register (read/write scratchpad) */
    case 0x4210: return dma.initbuf;
    default:
        return 0;
    }
}

void next_scsi_dma_reg_write(uint32_t addr, uint32_t value)
{
    uint32_t off = addr & 0x1FFFF;
    switch (off) {
    /* Saved/scratchpad registers */
    case 0x4000: dma.saved_next = value; break;
    case 0x4004: dma.saved_limit = value; break;
    case 0x4008: dma.saved_start = value; break;
    case 0x400C: dma.saved_stop = value; break;
    /* Active DMA registers */
    case 0x4010:
        dma.next = value;
        DPRINTF("[DMA] next=$%08X\r\n", value);
        break;
    case 0x4014:
        dma.limit = value;
        DPRINTF("[DMA] limit=$%08X\r\n", value);
        break;
    case 0x4018:
        dma.start = value;
        break;
    case 0x401C:
        dma.stop = value;
        break;
    /* DMA Init register — writing sets dma.next AND initializes buffer */
    case 0x4210:
        dma.next = value;
        dma.initbuf = value;
        break;
    default:
        break;
    }
}

/* ------------------------------------------------------------------ */
/* DMA CSR (Turbo 68040 format) at 0x02000010                         */
/* ------------------------------------------------------------------ */

uint32_t next_scsi_dma_csr_read(void)
{
    /* Turbo CSR read format: state bits in upper byte (bits 24-31),
     * burst buffer hardware status in lower bits (0-9).
     *
     * The kernel's get_dma_state() for chip 313 spins:
     *   while ((state = ddp->dd_csr) == 0) continue;
     * This checks the ENTIRE 32-bit value, not just the state bits.
     * On real Turbo DMA hardware the burst buffer status (byte count,
     * write/read pointers, dirty bits, bufsel) in the lower 10 bits
     * is always non-zero, so the full CSR is never $00000000 even
     * after reset.  We must return non-zero lower bits to prevent
     * the chip 313 workaround from spinning forever. */
    uint32_t val = ((uint32_t)dma.csr << 24) | 0x00000040;
    extern int next_debug_scsi;
    if (next_debug_scsi) {
        uint32_t pc = m68k_get_reg(NULL, M68K_REG_PC);
        DPRINTF("[DMA] CSR read → $%08X (csr=$%02X) PC=$%08X\r\n", val, dma.csr, pc);
    }
#if NEXT_DEBUG_DMA
    /* Sample dc_state on kernel CSR reads.  If A6+8 looks like a pointer
     * into the kernel data region, dereference it as a struct dma_chan
     * and print dc_state (+$24).  Helps distinguish "DMA completes but
     * kernel's dc_state never transitions" from "kernel never enters
     * the DMA-complete handler at all." */
    {
        uint32_t pc = m68k_get_reg(NULL, M68K_REG_PC);
        if (pc >= 0x04000000 && pc < 0x08000000) {
            static int rd_state_log = 0;
            if (rd_state_log < 40 || (rd_state_log % 500) == 0) {
                uint32_t a6   = m68k_get_reg(NULL, M68K_REG_A6);
                uint32_t dcp  = next_phys_read_32(a6 + 8);
                if (dcp >= 0x04000000 && dcp < 0x08000000) {
                    uint32_t dc_state   = next_phys_read_32(dcp + 0x24);
                    uint32_t dc_flags   = next_phys_read_32(dcp + 0x2C);
                    uint32_t dc_current = next_phys_read_32(dcp + 0x08);
                    xil_printf("[DMA-RDSTATE] #%d PC=$%08X dcp=$%08X "
                               "dc_state=$%08X dc_flags=$%08X dc_current=$%08X "
                               "our_csr=$%08X\r\n",
                               rd_state_log, pc, dcp,
                               dc_state, dc_flags, dc_current, val);
                }
            }
            rd_state_log++;
        }
    }
#endif
    return val;
}

void next_scsi_dma_csr_write(uint32_t value)
{
#if NEXT_DEBUG_DMA
    /* Capture every write into the ring — dumped when RESET-loop trigger fires.
     * Also watch for a tight-loop pattern (same kernel PC writing bare RESET
     * repeatedly with no intervening different-PC writes) and dump the stack
     * and recent-PC ring the first time we detect it. */
    {
        uint32_t pc = m68k_get_reg(NULL, M68K_REG_PC);

        /* Unknown-bits probe: log any bit we're not explicitly handling in
         * next_scsi_dma_csr_write.  The kernel writes $00940000 where
         * $00800000 is NOT one of our TDMA_* macros — this tells us
         * whether we're silently swallowing a bit the kernel relies on. */
        {
            const uint32_t known_mask =
                0x00010000 /* TDMA_SETENABLE  */ |
                0x00020000 /* TDMA_SETSUPDATE */ |
                0x00040000 /* TDMA_DEV2M      */ |
                0x00080000 /* TDMA_CLRCOMPLETE*/ |
                0x00100000 /* TDMA_RESET      */ ;
            uint32_t unknown = value & ~known_mask;
            if (unknown) {
                static uint32_t last_unknown_bits;
                static uint32_t last_unknown_val;
                if (unknown != last_unknown_bits || value != last_unknown_val) {
                    xil_printf("[DMA-UNKBIT] val=$%08X unknown=$%08X PC=$%08X\r\n",
                               value, unknown, pc);
                    last_unknown_bits = unknown;
                    last_unknown_val  = value;
                }
            }
        }

        /* Per-iteration probe: dump dc_flags each time a kernel bare-RESET
         * is written.  We read the first stack argument (dcp) via A6+8
         * and follow it to read dc_flags / dc_queue.dq_head / dc_current
         * / dc_state.  Log first 5 occurrences then every 50th to avoid
         * flooding. */
        if (value == 0x00100000 && pc >= 0x04000000 && pc < 0x08000000) {
            static int flags_log = 0;
            if (flags_log < 5 || (flags_log % 50) == 0) {
                uint32_t a6  = m68k_get_reg(NULL, M68K_REG_A6);
                uint32_t dcp = next_phys_read_32(a6 + 8);
                if (dcp >= 0x04000000 && dcp < 0x08000000) {
                    uint32_t dq_head  = next_phys_read_32(dcp + 0x00);
                    uint32_t dc_cur   = next_phys_read_32(dcp + 0x08);
                    uint32_t dc_state = next_phys_read_32(dcp + 0x24);
                    uint32_t dc_flag  = next_phys_read_32(dcp + 0x2C);
                    xil_printf("[DMA-FLAGS] #%d PC=$%08X dcp=$%08X flags=$%08X "
                               "head=$%08X current=$%08X dc_state=$%08X\r\n",
                               flags_log, pc, dcp, dc_flag, dq_head, dc_cur,
                               dc_state);
                } else {
                    xil_printf("[DMA-FLAGS] #%d PC=$%08X dcp=$%08X (OOR)\r\n",
                               flags_log, pc, dcp);
                }
            }
            flags_log++;
        }

        static uint32_t tight_last_pc;
        static int      tight_count;
        static int      tight_dumped;
        if (pc == tight_last_pc && value == 0x00100000 && pc >= 0x04000000) {
            tight_count++;
            if (tight_count == 5 && !tight_dumped) {
                tight_dumped = 1;
                xil_printf("[DMA-TIGHT] 5 consecutive bare-RESETs from PC=$%08X — stack:\r\n", pc);
                uint32_t a6_orig = m68k_get_reg(NULL, M68K_REG_A6);
                uint32_t a6 = a6_orig;
                for (int i = 0; i < 10 && a6 >= 0x04000000 && a6 < 0x08000000; i++) {
                    uint32_t ret  = next_phys_read_32(a6 + 4);
                    uint32_t prev = next_phys_read_32(a6);
                    xil_printf("  frame %d: A6=$%08X ret=$%08X\r\n", i, a6, ret);
                    a6 = prev;
                }

                /* Register snapshot */
                xil_printf("[DMA-TIGHT] D0=$%08X D1=$%08X D2=$%08X D3=$%08X\r\n",
                           m68k_get_reg(NULL, M68K_REG_D0),
                           m68k_get_reg(NULL, M68K_REG_D1),
                           m68k_get_reg(NULL, M68K_REG_D2),
                           m68k_get_reg(NULL, M68K_REG_D3));
                xil_printf("[DMA-TIGHT] D4=$%08X D5=$%08X D6=$%08X D7=$%08X\r\n",
                           m68k_get_reg(NULL, M68K_REG_D4),
                           m68k_get_reg(NULL, M68K_REG_D5),
                           m68k_get_reg(NULL, M68K_REG_D6),
                           m68k_get_reg(NULL, M68K_REG_D7));
                xil_printf("[DMA-TIGHT] A0=$%08X A1=$%08X A2=$%08X A3=$%08X\r\n",
                           m68k_get_reg(NULL, M68K_REG_A0),
                           m68k_get_reg(NULL, M68K_REG_A1),
                           m68k_get_reg(NULL, M68K_REG_A2),
                           m68k_get_reg(NULL, M68K_REG_A3));
                xil_printf("[DMA-TIGHT] A4=$%08X A5=$%08X A6=$%08X A7=$%08X\r\n",
                           m68k_get_reg(NULL, M68K_REG_A4),
                           m68k_get_reg(NULL, M68K_REG_A5),
                           a6_orig,
                           m68k_get_reg(NULL, M68K_REG_A7));

                /* Dump caller's loop body (24 bytes before & after the JSR).
                 * The JSR that called us sits just before ret in the caller. */
                uint32_t caller_ret = next_phys_read_32(a6_orig + 4);
                xil_printf("[DMA-TIGHT] caller code near ret=$%08X:\r\n", caller_ret);
                for (int off = -24; off < 24; off += 8) {
                    uint32_t addr = caller_ret + off;
                    if (addr < 0x04000000 || addr >= 0x08000000) continue;
                    xil_printf("  $%08X: %08X %08X\r\n", addr,
                               next_phys_read_32(addr),
                               next_phys_read_32(addr + 4));
                }

                /* First stack argument is *(A6+8) — likely dcp pointer.
                 * Dump 64 bytes to cover dc_flags at offset 0x2C. */
                uint32_t arg1 = next_phys_read_32(a6_orig + 8);
                xil_printf("[DMA-TIGHT] stack arg1=$%08X\r\n", arg1);
                if (arg1 >= 0x04000000 && arg1 < 0x08000000) {
                    xil_printf("[DMA-TIGHT] arg1 struct head (64 bytes):\r\n");
                    for (int off = 0; off < 64; off += 8) {
                        xil_printf("  +$%02X: $%08X $%08X\r\n", off,
                                   next_phys_read_32(arg1 + off),
                                   next_phys_read_32(arg1 + off + 4));
                    }
                }

                /* Dump function entry code at $0407C6C8 so we can identify it. */
                xil_printf("[DMA-TIGHT] callee entry code:\r\n");
                for (int off = 0; off < 32; off += 8) {
                    uint32_t addr = 0x0407C6C8 + off;
                    xil_printf("  $%08X: %08X %08X\r\n", addr,
                               next_phys_read_32(addr),
                               next_phys_read_32(addr + 4));
                }

                /* Dump outermost polling loop code at $0409F5C0..$0409F5F0. */
                xil_printf("[DMA-TIGHT] outer poll code at $0409F5xx:\r\n");
                for (int off = 0; off < 48; off += 8) {
                    uint32_t addr = 0x0409F5C0 + off;
                    xil_printf("  $%08X: %08X %08X\r\n", addr,
                               next_phys_read_32(addr),
                               next_phys_read_32(addr + 4));
                }

                /* Dump the OUTER loop body at $040146xx — this is where the
                 * hang actually lives.  PC ring shows backward jump from
                 * $040146C2 → $0401469C each iteration.  Dump 64 bytes
                 * covering the loop body plus exit test. */
                xil_printf("[DMA-TIGHT] OUTER loop body at $040146xx:\r\n");
                for (int off = 0; off < 64; off += 8) {
                    uint32_t addr = 0x04014690 + off;
                    xil_printf("  $%08X: %08X %08X\r\n", addr,
                               next_phys_read_32(addr),
                               next_phys_read_32(addr + 4));
                }

                /* Also dump $0408ACxx and $0408A6xx — the layers between the
                 * outer loop and dma_abort.  Each might contain the real
                 * exit test if $040146xx is just plumbing. */
                xil_printf("[DMA-TIGHT] $0408ACxx layer:\r\n");
                for (int off = 0; off < 48; off += 8) {
                    uint32_t addr = 0x0408ACF0 + off;
                    xil_printf("  $%08X: %08X %08X\r\n", addr,
                               next_phys_read_32(addr),
                               next_phys_read_32(addr + 4));
                }
                xil_printf("[DMA-TIGHT] $0408A6xx layer:\r\n");
                for (int off = 0; off < 48; off += 8) {
                    uint32_t addr = 0x0408A650 + off;
                    xil_printf("  $%08X: %08X %08X\r\n", addr,
                               next_phys_read_32(addr),
                               next_phys_read_32(addr + 4));
                }

                extern void emu_dump_pc_ring(const char *why);
                emu_dump_pc_ring("DMA tight-loop trigger");
#if NEXT_DEBUG_ESP_TRACE
                /* Arm sticky ESP-cmd trace so we see whether the driver
                 * keeps issuing new commands during the RESET loop. */
                extern int esp_tight_trace;
                esp_tight_trace = 1;
                xil_printf("[DMA-TIGHT] Sticky ESP-cmd trace armed\r\n");
#endif
            }
        } else {
            tight_count = 0;
            tight_last_pc = pc;
        }

        dma_wr_ring[dma_wr_ring_idx].instr = (uint32_t)emu_instr_count;
        dma_wr_ring[dma_wr_ring_idx].value = value;
        dma_wr_ring[dma_wr_ring_idx].pc    = pc;
        dma_wr_ring_idx = (dma_wr_ring_idx + 1) % DMA_WR_RING_SIZE;
    }
#endif /* NEXT_DEBUG_DMA */

    extern int next_debug_scsi;
    if (next_debug_scsi) {
        uint32_t pc = m68k_get_reg(NULL, M68K_REG_PC);
        DPRINTF("[DMA] CSR write=$%08X PC=$%08X\r\n", value, pc);
        /* Trace caller chain via A6 frame pointer */
        static int call_traced = 0;
        if (!call_traced) {
            call_traced = 1;
            uint32_t a6 = m68k_get_reg(NULL, M68K_REG_A6);
            DPRINTF("[DMA] Call chain: ");
            for (int i = 0; i < 6 && a6 >= 0x04000000 && a6 < 0x08000000; i++) {
                uint32_t ret = next_phys_read_32(a6 + 4);
                xil_printf("$%08X ", ret);
                a6 = next_phys_read_32(a6);
            }
            xil_printf("\r\n");
            /* Dump code at first caller */
            a6 = m68k_get_reg(NULL, M68K_REG_A6);
            uint32_t caller = next_phys_read_32(a6 + 4);
            DPRINTF("[DMA] Code at caller $%08X:\r\n  ", caller);
            for (int i = -8; i < 8; i++) {
                uint32_t w = next_phys_read_32(caller + i*2);
                xil_printf("%04X ", w >> 16);
            }
            xil_printf("\r\n");
        }
    } else {
        DPRINTF("[DMA] CSR write=$%08X\r\n", value);
    }

    dma.direction = (value & TDMA_DEV2M) ? DMA_DEV2M : 0;

    if (value & TDMA_RESET) {
#if NEXT_DEBUG_DMA
        static int kernel_reset_count = 0;
        uint32_t pc = m68k_get_reg(NULL, M68K_REG_PC);
        if (pc >= 0x04000000) {
            kernel_reset_count++;
            /* Enable ESP trace logging once we detect the hang pattern */
            if (kernel_reset_count == 20) {
                extern void esp_dump_state(void);
                extern void emu_dump_pc_ring(const char *why);
                uint32_t sr = m68k_get_reg(NULL, M68K_REG_SR);
                xil_printf("[DMA-LOOP] 20 consecutive kernel RESETs! PC=$%08X SR=$%04X\r\n", pc, sr);
                esp_dump_state();
                next_scsi_dma_dump_write_ring();
                emu_dump_pc_ring("DMA-LOOP trigger");
#if NEXT_DEBUG_ESP_TRACE
                extern int esp_loop_trace;
                xil_printf("[DMA-LOOP] Enabling ESP trace for next 100 accesses\r\n");
                esp_loop_trace = 100;
#endif
            }
        } else {
            kernel_reset_count = 0;
        }
#endif /* NEXT_DEBUG_DMA */
        dma.csr &= ~(DMA_COMPLETE | DMA_SUPDATE | DMA_ENABLE);
        next_intr_clear(I_IPL6_SCSI_DMA);
        /* Cancel any deferred transfer queued by
         * next_scsi_dma_start_deferred: the driver is aborting this
         * command, so firing esp_deferred_dma_complete later would
         * post stale bytes and a phantom IRQ for a command the
         * kernel no longer cares about. */
        if (dma_deferred.pending) {
            DPRINTF("[DMA] reset: cancelling deferred (dir=%d cnt=%u countdown=%d)\r\n",
                    dma_deferred.direction, dma_deferred.esp_counter,
                    dma_deferred.countdown);
            dma_deferred.pending = 0;
        }
        DPRINTF("[DMA] reset → csr=$%02X\r\n", dma.csr);
    }
    if (value & TDMA_SETSUPDATE) {
        dma.csr |= DMA_SUPDATE;
    }
    if (value & TDMA_SETENABLE) {
        dma.csr |= DMA_ENABLE;
    }
    if (value & TDMA_CLRCOMPLETE) {
        dma.csr &= ~DMA_COMPLETE;
        next_intr_clear(I_IPL6_SCSI_DMA);
    }
}

/* ------------------------------------------------------------------ */
/* DMA transfer: move data between SCSI buffer and 68K memory          */
/* ------------------------------------------------------------------ */

int next_scsi_dma_transfer(int direction, uint32_t *esp_counter)
{
    int total = 0;

    if (!(dma.csr & DMA_ENABLE)) {
        DPRINTF("[DMA] Transfer requested but DMA not enabled\r\n");
        return 0;
    }

    /* DMA_BUSEXC is sticky: the kernel's bus-error handler clears it by
     * writing RESET to the CSR (handled in next_scsi_dma_csr_write).  But
     * if the done-branch below is reached by a subsequent transfer before
     * the kernel has processed the previous bus error, the stale bit
     * would short-circuit `done` and spuriously re-assert DMA_COMPLETE.
     * Clear at the top of every transfer so each transfer starts clean;
     * real bus errors this time around will re-set it below. */
    dma.csr &= ~DMA_BUSEXC;

    if (direction) {
        /* Device to memory (SCSI read → 68K RAM) */
        while (*esp_counter > 0 && dma.next < dma.limit) {
            /* Get data from SCSI */
            int avail = next_scsi_get_buffer_remaining();
            if (avail <= 0)
                break;

            /* Calculate chunk size — all unsigned to avoid sign issues */
            uint32_t dma_remain = dma.limit - dma.next;
            uint32_t chunk = (uint32_t)avail;
            if (chunk > dma_remain) chunk = dma_remain;
            if (chunk > *esp_counter) chunk = *esp_counter;
            if (chunk == 0) break;

            /* Resolve destination address (strip bit 31 for TT mapping) */
            uint32_t phys = dma.next & 0x7FFFFFFF;

            /* Overflow-safe bounds check: phys in [RAM_BASE, RAM_BASE+RAM_SIZE) */
            if (phys >= NEXT_RAM_BASE && phys < NEXT_RAM_BASE + NEXT_RAM_SIZE) {
                uint32_t ram_avail = (NEXT_RAM_BASE + NEXT_RAM_SIZE) - phys;
                if (chunk > ram_avail) chunk = ram_avail;
                /* Bank-masked offset (matches next_memory.c::ram_offset).
                 * Only the bank 1→bank 2 boundary at $08000000 is
                 * non-contiguous in the flat buffer, so clip chunk to
                 * stop before $08000000 if we'd cross it. */
                if (phys < 0x08000000u && phys + chunk > 0x08000000u)
                    chunk = 0x08000000u - phys;
                uint8_t *src = next_scsi_get_buffer_ptr();
                if (src) {
                    memcpy(&next_ram[phys & 0x07FFFFFFu], src, chunk);
                } else {
                    DPRINTF("[DMA] NULL src at phys=$%08X\r\n", phys);
                    break;
                }
            } else {
                DPRINTF("[DMA] Bus error: write outside RAM $%08X\r\n", phys);
                dma.csr |= DMA_BUSEXC;
                break;
            }

            next_scsi_consume_bytes((int)chunk);
            dma.next += chunk;
            *esp_counter -= chunk;
            total += (int)chunk;
        }

        /* Check for chaining */
        if (dma.next >= dma.limit && (dma.csr & DMA_SUPDATE)) {
            dma.next = dma.start;
            dma.limit = dma.stop;
            dma.csr &= ~DMA_SUPDATE;
            DPRINTF("[DMA] Chain: next=$%08X limit=$%08X\r\n", dma.next, dma.limit);
        }
    } else {
        /* Memory to device (68K RAM → SCSI write) — discard data.
         * The kernel flushes dirty buffers via SCSI WRITE; we accept
         * the DMA transfer and throw away the bytes so the buffer
         * cache can reclaim buffers for new reads. */
        while (*esp_counter > 0 && dma.next < dma.limit) {
            int avail = next_scsi_get_write_remaining();
            if (avail <= 0)
                break;

            uint32_t dma_remain = dma.limit - dma.next;
            uint32_t chunk = (uint32_t)avail;
            if (chunk > dma_remain) chunk = dma_remain;
            if (chunk > *esp_counter) chunk = *esp_counter;
            if (chunk == 0) break;

            /* Just advance pointers — data is discarded */
            next_scsi_consume_write_bytes((int)chunk);
            dma.next += chunk;
            *esp_counter -= chunk;
            total += (int)chunk;
        }

        /* Check for chaining (same as read path) */
        if (dma.next >= dma.limit && (dma.csr & DMA_SUPDATE)) {
            dma.next = dma.start;
            dma.limit = dma.stop;
            dma.csr &= ~DMA_SUPDATE;
        }
    }

    if (total == 0 && (dma.csr & DMA_ENABLE)) {
        DPRINTF("[DMA] WARNING: zero-byte transfer (next=$%08X limit=$%08X dir=%d)\r\n",
                dma.next, dma.limit, direction);
    }

    /* Signal completion whenever the ESP counter drained, the DMA window
     * filled, or a bus error was observed.  Previous (dma.c:457-461,
     * 488-492) always raises the done-interrupt on bus error with
     * DMA_COMPLETE and DMA_BUSEXC set together and DMA_ENABLE cleared
     * — otherwise the kernel's bus-error handler never runs and the
     * device driver stalls waiting for a completion that never comes. */
    bool done = (*esp_counter == 0) || (dma.next >= dma.limit)
                || (dma.csr & DMA_BUSEXC);
    if (done) {
        dma.csr |= DMA_COMPLETE;
        dma.csr &= ~DMA_ENABLE;
        next_intr_set(I_IPL6_SCSI_DMA);
#if NEXT_DEBUG_DMA
        /* Track DMA completion for interrupt delivery diagnosis */
        {
            static int dma_complete_count = 0;
            dma_complete_count++;
            if (dma_complete_count <= 30 || (dma_complete_count % 100) == 0) {
                uint32_t sr = m68k_get_reg(NULL, M68K_REG_SR);
                xil_printf("[DMA-DONE] #%d total=%d bytes, next=$%08X SR=$%04X IPL=%d busexc=%d\r\n",
                           dma_complete_count, total, dma.next, sr & 0xFFFF,
                           (sr >> 8) & 7, !!(dma.csr & DMA_BUSEXC));
            }
        }
#endif /* NEXT_DEBUG_DMA */
    }


    DPRINTF("[DMA] Transfer done: %d bytes, next=$%08X\r\n", total, dma.next);
    return total;
}

/* ------------------------------------------------------------------ */
/* Deferred DMA: start / tick                                          */
/* ------------------------------------------------------------------ */

void next_scsi_dma_start_deferred(int direction, uint32_t esp_counter)
{
    /* Overlap guard: a real 53C9x cannot be asked to start a new DMA
     * transfer while one is still in flight.  If the previous deferred
     * transfer is still pending when a second CMD_TI is issued, silently
     * dropping the first would leave its esp_deferred_dma_complete
     * unfired and esp.counter stale.  Log loudly so we notice. */
    if (dma_deferred.pending) {
        xil_printf("[DMA-OVERLAP] new start while pending: "
                   "old dir=%d cnt=%u countdown=%d; new dir=%d cnt=%u (dropping NEW)\r\n",
                   dma_deferred.direction, dma_deferred.esp_counter,
                   dma_deferred.countdown, direction, esp_counter);
        return;
    }
    dma_deferred.direction   = direction;
    dma_deferred.esp_counter = esp_counter;
    dma_deferred.countdown   = DMA_DEFER_TICKS;
    dma_deferred.pending     = 1;
}

int next_scsi_dma_tick(void)
{
    if (!dma_deferred.pending)
        return 0;

    if (--dma_deferred.countdown > 0)
        return 0;

    /* Time's up — execute the DMA transfer now */
    dma_deferred.pending = 0;

    uint32_t counter = dma_deferred.esp_counter;
    int transferred = next_scsi_dma_transfer(dma_deferred.direction, &counter);

    /* Tell the ESP the result via callback */
    extern void esp_deferred_dma_complete(uint32_t remaining, int bytes);
    esp_deferred_dma_complete(counter, transferred);

    return 1;
}
