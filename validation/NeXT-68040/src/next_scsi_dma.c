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
#include "xil_printf.h"
#include <string.h>

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
    /* Turbo CSR shadow: last value written, returned on read for DMA_W */
    uint32_t csr_shadow;
} dma;

/* Internal CSR bits (68030-style, for state tracking) */
#define DMA_ENABLE      0x01
#define DMA_SUPDATE     0x02
#define DMA_COMPLETE    0x08
#define DMA_BUSEXC      0x10
#define DMA_DEV2M       0x04

/* ------------------------------------------------------------------ */
/* Init                                                                */
/* ------------------------------------------------------------------ */

void next_scsi_dma_init(void)
{
    memset(&dma, 0, sizeof(dma));
    dma.csr = DMA_COMPLETE;
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
        xil_printf("[DMA] next=$%08X\r\n", value);
        break;
    case 0x4014:
        dma.limit = value;
        xil_printf("[DMA] limit=$%08X\r\n", value);
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
    extern int next_debug_scsi;
    if (next_debug_scsi) {
        uint32_t pc = m68k_get_reg(NULL, M68K_REG_PC);
        xil_printf("[DMA] CSR read → $%08X PC=$%08X\r\n", dma.csr_shadow, pc);
    }
    return dma.csr_shadow;
}

void next_scsi_dma_csr_write(uint32_t value)
{
    extern int next_debug_scsi;
    if (next_debug_scsi) {
        uint32_t pc = m68k_get_reg(NULL, M68K_REG_PC);
        xil_printf("[DMA] CSR write=$%08X PC=$%08X\r\n", value, pc);
        /* Dump code around PC on first debug hit */
        static int code_dumped = 0;
        if (!code_dumped) {
            code_dumped = 1;
            xil_printf("[DMA] Code near PC=$%08X:\r\n  ", pc);
            for (int i = -4; i < 8; i++) {
                uint32_t w = next_phys_read_32(pc + i*4);
                xil_printf("%08X ", w);
            }
            xil_printf("\r\n");
        }
    } else {
        xil_printf("[DMA] CSR write=$%08X\r\n", value);
    }

    dma.csr_shadow = value;  /* echo back for DMA_W readback check */
    dma.direction = (value & TDMA_DEV2M) ? DMA_DEV2M : 0;

    if (value & TDMA_RESET) {
        dma.csr &= ~(DMA_COMPLETE | DMA_SUPDATE | DMA_ENABLE);
        next_intr_clear(I_IPL6_SCSI_DMA);
        xil_printf("[DMA] reset\r\n");
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
        xil_printf("[DMA] Transfer requested but DMA not enabled\r\n");
        return 0;
    }

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
                uint8_t *src = next_scsi_get_buffer_ptr();
                if (src) {
                    memcpy(&next_ram[phys - NEXT_RAM_BASE], src, chunk);
                } else {
                    xil_printf("[DMA] NULL src at phys=$%08X\r\n", phys);
                    break;
                }
            } else {
                xil_printf("[DMA] Bus error: write outside RAM $%08X\r\n", phys);
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
            xil_printf("[DMA] Chain: next=$%08X limit=$%08X\r\n", dma.next, dma.limit);
        }
    } else {
        /* Memory to device (68K RAM → SCSI write) — not implemented */
        xil_printf("[DMA] Mem→SCSI transfer not implemented\r\n");
        return 0;
    }

    /* Signal completion only if data was actually transferred without error */
    if (total > 0 && !(dma.csr & DMA_BUSEXC)) {
        dma.csr |= DMA_COMPLETE;
        dma.csr &= ~DMA_ENABLE;
        next_intr_set(I_IPL6_SCSI_DMA);
    }

    xil_printf("[DMA] Transfer done: %d bytes, next=$%08X\r\n", total, dma.next);
    return total;
}
