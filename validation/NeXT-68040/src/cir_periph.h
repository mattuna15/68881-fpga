/*
 * cir_periph.h
 * CIR (Coprocessor Interface Register) driver — AN-947 dialog protocol
 * over AXI-Lite.  Exercises the same state machine a real 68000 would use.
 */

#ifndef CIR_PERIPH_H
#define CIR_PERIPH_H

#include "fpu_periph.h"          /* MC68881_BASE, fpu_wr/rd, fp80_t */

/* ------------------------------------------------------------------ */
/* CIR register offsets (5-bit addr * 4 = AXI byte offset)             */
/* ------------------------------------------------------------------ */
#define OFF_CIR_OPWORD      (4  * 4)   /* 0x10 — overlaps OPB_L */
#define OFF_CIR_COMMAND     (5  * 4)   /* 0x14 — overlaps OPB_H */
#define OFF_CIR_CONDITION   (7  * 4)   /* 0x1C — overlaps RES_L */
#define OFF_CIR_OPERAND     (8  * 4)   /* 0x20 — overlaps RES_H */
#define OFF_CIR_SAVE        (12 * 4)   /* 0x30 — read format word during cpSAVE */
#define OFF_CIR_INSTADDR    (12 * 4)   /* 0x30 — overlaps CIR_SAVE */
#define OFF_CIR_OPADDR      (14 * 4)   /* 0x38 — overlaps FPSR */
#define OFF_CIR_RESPONSE    (13 * 4)   /* 0x34 — CIR response (read) / mode control (write) */
#define OFF_CIR_RESTORE     (28 * 4)   /* 0x70 — write format word for cpRESTORE */

/* ------------------------------------------------------------------ */
/* CIR response primitives                                             */
/* ------------------------------------------------------------------ */
/* AN-947 response primitives (MC68881 native bus encoding).
 * Bit 15=CA (come again), Bit 13=DR (0=to-FPU, 1=from-FPU), Bits 7:0=length. */
#define CIR_BUSY             0x8900u  /* Null CA=1 (come again) */
#define CIR_NULL             0x0900u  /* Null CA=0 (release) */
#define CIR_XFER_TO_CP_4    0x9604u  /* EA+Xfer CPU→FPU, 4 bytes, CA=1 */
#define CIR_XFER_TO_CP_8    0x9608u
#define CIR_XFER_TO_CP_12   0x960Cu
#define CIR_XFER_FROM_CP_4  0xB204u  /* EA+Xfer FPU→CPU, 4 bytes, CA=1 */
#define CIR_XFER_FROM_CP_8  0xB208u
#define CIR_XFER_FROM_CP_12 0xB20Cu

/* ------------------------------------------------------------------ */
/* Status register bits (supplement to fpu_periph.h)                   */
/* ------------------------------------------------------------------ */
#define STATUS_CIR_PENDING   0x10u     /* bit 4: cir_response_pending */

/* ------------------------------------------------------------------ */
/* OpWord instruction types: bits [8:6]                                */
/* ------------------------------------------------------------------ */
#define CIR_OPWORD_CPGEN     0x0000u   /* type 000 */
#define CIR_OPWORD_CPSAVE    0x0100u   /* type 100: bits [8:6] = 100 */
#define CIR_OPWORD_CPRESTORE 0x0140u   /* type 101: bits [8:6] = 101 */

/* ------------------------------------------------------------------ */
/* Source format codes (for memory-source / memory-dest operations)     */
/* ------------------------------------------------------------------ */
#define CIR_FMT_LONG         0
#define CIR_FMT_SINGLE       1
#define CIR_FMT_EXTENDED     2
#define CIR_FMT_PACKED       3
#define CIR_FMT_WORD         4
#define CIR_FMT_DOUBLE       5
#define CIR_FMT_BYTE         6

/* ------------------------------------------------------------------ */
/* Command word builder macros                                         */
/* Opcode IDs are MC68881 native encoding (FPOP_* = bits[6:0]).        */
/* ------------------------------------------------------------------ */

/* MC68881 command word format (Motorola convention):
 * R/M=0: source is FP register (bits[12:10]=register number)
 * R/M=1: source is effective address/memory (bits[12:10]=data format)
 * dir(bit13): 0=to-register, 1=from-register (FMOVE reg-to-mem only) */

/* Register-to-register: R/M=0, src_reg [12:10], dst_reg [9:7] */
#define CIR_CMD_REG(src, dst, op) \
    ((u16)(((u16)(src) << 10) | ((u16)(dst) << 7) | (u16)(op)))

/* Memory-to-register: R/M=1, dir=0, fmt [12:10], dst_reg [9:7] */
#define CIR_CMD_MEM2REG(fmt, dst, op) \
    ((u16)(0x4000u | ((u16)(fmt) << 10) | ((u16)(dst) << 7) | (u16)(op)))

/* Register-to-memory: R/M=1, dir=1, fmt [12:10], src_reg [9:7] */
#define CIR_CMD_REG2MEM(fmt, src, op) \
    ((u16)(0x6000u | ((u16)(fmt) << 10) | ((u16)(src) << 7) | (u16)(op)))

/* ------------------------------------------------------------------ */
/* Low-level CIR register access (same base as peripheral)             */
/* ------------------------------------------------------------------ */
static inline void cir_wr(u32 off, u32 v) { Xil_Out32(MC68881_BASE + off, v); }
static inline u32  cir_rd(u32 off)        { return Xil_In32(MC68881_BASE + off); }

/* ------------------------------------------------------------------ */
/* Timeout (polls)                                                     */
/* ------------------------------------------------------------------ */
#define CIR_TIMEOUT_POLLS   200000

/* ------------------------------------------------------------------ */
/* Return codes (reuse FPU_OK / FPU_TIMEOUT from fpu_periph.h)         */
/* ------------------------------------------------------------------ */
#define CIR_OK       FPU_OK
#define CIR_TIMEOUT  FPU_TIMEOUT

/* ------------------------------------------------------------------ */
/* API                                                                 */
/* ------------------------------------------------------------------ */

/* Poll CIR_RESPONSE until non-BUSY.  Returns response word or 0 on timeout. */
u16 cir_poll_response(void);

/* Poll CIR_RESPONSE until NULL release.  Returns CIR_OK or CIR_TIMEOUT. */
int cir_wait_null(void);

/* Full reg-to-reg dialog: FADD FPsrc, FPdst etc. */
int cir_cpgen_reg_to_reg(u8 src_reg, u8 dst_reg, u8 opcode);

/* Full mem-to-reg dialog with operand transfer. */
int cir_cpgen_mem_to_reg(u8 fmt, u8 dst_reg, u8 opcode,
                         const u32 *operand_words, int word_count);

/* Full reg-to-mem readback. */
int cir_cpgen_reg_to_mem(u8 fmt, u8 src_reg,
                         u32 *result_words, int word_count);

#endif /* CIR_PERIPH_H */
