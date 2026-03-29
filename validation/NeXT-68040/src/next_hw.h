/*
 * next_hw.h
 * NeXT hardware register definitions for 68040LC emulator.
 *
 * Address map from NeXTMach mk-108.1 next/cpu.h and next/scr.h.
 * SLOT_ID = 0 (main slot), SLOT_ID_BMAP = 0 (68030 compat).
 */

#ifndef NEXT_HW_H
#define NEXT_HW_H

#include <stdint.h>

/* ------------------------------------------------------------------ */
/* Physical address map (SLOT_ID = 0)                                  */
/* ------------------------------------------------------------------ */

/* ROM */
#define P_EPROM         0x00000000
#define P_EPROM_SIZE    (128 * 1024)

/* Main memory — kernel loads here */
#define P_MAINMEM       0x04000000
#define P_MAINMEM_SIZE  (16 * 1024 * 1024)  /* 16 MB emulated */

/* Video memory */
#define P_VIDEOMEM      0x0B000000
#define P_VIDEOMEM_SIZE (256 * 1024)    /* 1120x832 mono, 2bpp */

/* ------------------------------------------------------------------ */
/* Device I/O space: 0x02000000 - 0x020C0000                           */
/* ------------------------------------------------------------------ */

/* DMA control/status registers (32-bit writes only) */
#define P_SCSI_CSR      0x02000010
#define P_SOUNDOUT_CSR  0x02000040
#define P_DISK_CSR      0x02000050
#define P_SOUNDIN_CSR   0x02000080
#define P_PRINTER_CSR   0x02000090
#define P_SCC_CSR       0x020000C0
#define P_DSP_CSR       0x020000D0
#define P_ENETX_CSR     0x02000110
#define P_ENETR_CSR     0x02000150
#define P_VIDEO_CSR     0x02000180
#define P_R2M_CSR       0x020001C0
#define P_M2R_CSR       0x020001D0

/* Interrupt controller */
#define P_INTRSTAT      0x02007000  /* read-only: interrupt status */
#define P_INTRMASK      0x02007800  /* read/write: interrupt mask */

/* System control registers */
#define P_ENET          0x02006000
#define P_MON           0x0200E000
#define P_SCR1          0x0200C000  /* read-only: machine type, board rev */
#define P_SID           0x0200C800  /* slot ID */
#define P_SCR2          0x0200D000  /* read/write: system control */
#define P_RMTINT        0x0200D800  /* remote interrupt */

/* Device registers */
#define P_BRIGHTNESS    0x02010000
#define P_DISK          0x02012000
#define P_SCSI          0x02014000
#define P_FLOPPY        0x02014100
#define P_TIMER         0x02016000
#define P_TIMER_CSR     0x02016004
#define P_SCC           0x02018000  /* Zilog 8530 serial */
#define P_SCC_CLK       0x02018004
#define P_EVENTC        0x0201A000  /* event counter (microseconds) */
#define P_BMAP          0x020C0000

/* ------------------------------------------------------------------ */
/* Machine types (from scr.h)                                          */
/* ------------------------------------------------------------------ */
#define NeXT_CUBE       0   /* 68030 original */
#define NeXT_WARP9      1   /* 68040 NeXTstation */
#define NeXT_X15        2   /* 68040 NeXTcube Turbo */
#define NeXT_WARP9C     3   /* 68040 NeXTstation Color */

/* SCR1 encoding helpers */
#define MACHINE_TYPE(x) ((x) >> 4)
#define BOARD_REV(x)    ((x) & 0xF)

/* Construct SCR1 value for emulation:
 * slot_id=0, dma_rev=1, cpu_rev encodes machine_type+board_rev,
 * vmem_speed=MEM_80ns(2), mem_speed=MEM_80ns(2), cpu_clock=CPU_25MHz(2) */
#define SCR1_VALUE(mtype, brev) \
    ((0u << 28) |               /* slot_id = 0 */ \
     (0u << 24) |               /* padding */ \
     (1u << 16) |               /* dma_rev = 1 */ \
     ((((mtype) << 4) | ((brev) & 0xF)) << 8) | /* cpu_rev */ \
     (2u << 6) |                /* vmem_speed = 80ns */ \
     (2u << 4) |                /* mem_speed = 80ns */ \
     (0u << 2) |                /* reserved */ \
     (2u << 0))                 /* cpu_clock = 25 MHz */

/* SCR2 bit definitions */
#define SCR2_EKG_LED    0x00000001
#define SCR2_OVERLAY    0x00000080
#define SCR2_RTCE       0x00000100
#define SCR2_RTCLK      0x00000200
#define SCR2_RTDATA     0x00000400
#define SCR2_ROM_1M     0x00000800
#define SCR2_TIMERIPL7  0x00008000
#define SCR2_DRAM_1M    0x00010000

/* DMA CSR bits */
#define DMACSR_COMPLETE  0x08000000
#define DMACSR_ENABLE    0x01000000
#define DMACSR_RESET     0x00100000

/* Timer */
#define TIMER_ENABLE    0x80
#define TIMER_UPDATE    0x40
#define TIMER_MAX       0xFFFF

/* SCC (Zilog 8530) register offsets */
#define SCC_CHAN_A_CTRL  1   /* Channel A control (byte offset from P_SCC) */
#define SCC_CHAN_A_DATA  3   /* Channel A data */
#define SCC_CHAN_B_CTRL  0   /* Channel B control */
#define SCC_CHAN_B_DATA  2   /* Channel B data */

/* SCC Read Register 0 status bits */
#define SCC_RR0_RX_AVAIL    0x01
#define SCC_RR0_TX_EMPTY    0x04
#define SCC_RR0_DCD         0x08
#define SCC_RR0_CTS         0x20

/* ------------------------------------------------------------------ */
/* Interrupt status/mask bit definitions                               */
/* ------------------------------------------------------------------ */
#define I_IPL7_NMI          (1u << 31)
#define I_IPL7_PFAIL        (1u << 30)
#define I_IPL6_TIMER        (1u << 29)
#define I_IPL6_ENETX_DMA    (1u << 28)
#define I_IPL6_ENETR_DMA    (1u << 27)
#define I_IPL6_SCSI_DMA     (1u << 26)
#define I_IPL6_DISK_DMA     (1u << 25)
#define I_IPL6_PRINTER_DMA  (1u << 24)
#define I_IPL6_STXDMA       (1u << 23)
#define I_IPL6_SRXDMA       (1u << 22)
#define I_IPL6_SCC_DMA      (1u << 21)
#define I_IPL6_DSP_DMA      (1u << 20)
#define I_IPL6_M2R          (1u << 19)
#define I_IPL6_R2M          (1u << 18)
#define I_IPL5_SCC          (1u << 17)
#define I_IPL5_REMOTE       (1u << 16)
#define I_IPL5_BUS          (1u << 15)
#define I_IPL4_DSP          (1u << 14)
#define I_IPL3_DISK         (1u << 13)
#define I_IPL3_SCSI         (1u << 12)
#define I_IPL3_PRINTER      (1u << 11)
#define I_IPL3_ENETX        (1u << 10)
#define I_IPL3_ENETR        (1u <<  9)
#define I_IPL3_SOUND_OVRUN  (1u <<  8)
#define I_IPL3_PHONE        (1u <<  7)
#define I_IPL3_DSP          (1u <<  6)
#define I_IPL3_VIDEO        (1u <<  5)
#define I_IPL3_MONITOR      (1u <<  4)
#define I_IPL3_KBD_MOUSE    (1u <<  3)
#define I_IPL3_POWER        (1u <<  2)
#define I_IPL2_SOFTINT1     (1u <<  1)
#define I_IPL1_SOFTINT0     (1u <<  0)

#endif /* NEXT_HW_H */
