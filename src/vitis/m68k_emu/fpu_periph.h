/*
 * fpu_periph.h
 * FPU peripheral driver — register-mapped interface over AXI-Lite.
 * Refactored from mc68881_e2e_test.c for reuse by the M68K emulator.
 */

#ifndef FPU_PERIPH_H
#define FPU_PERIPH_H

#include "xil_io.h"
#include "xil_types.h"

/* ------------------------------------------------------------------ */
/* Base address                                                        */
/* ------------------------------------------------------------------ */
#ifndef MC68881_BASE
#define MC68881_BASE 0x80000000u
#endif

/* ------------------------------------------------------------------ */
/* Register offsets (register index * 4)                               */
/* ------------------------------------------------------------------ */
#define OFF_OPSEL    (0  * 4)
#define OFF_OPA_L    (1  * 4)
#define OFF_OPA_H    (2  * 4)
#define OFF_OPA_E    (3  * 4)
#define OFF_OPB_L    (4  * 4)
#define OFF_OPB_H    (5  * 4)
#define OFF_OPB_E    (6  * 4)
#define OFF_RES_L    (7  * 4)
#define OFF_RES_H    (8  * 4)
#define OFF_RES_E    (9  * 4)
#define OFF_STATUS   (10 * 4)
#define OFF_FPCR     (11 * 4)
#define OFF_FPSR     (14 * 4)
#define OFF_MOVE_CFG (23 * 4)
#define OFF_FPIAR    (24 * 4)

/* Status register bits */
#define STATUS_VALID  0x01u
#define STATUS_BUSY   0x02u

/* ------------------------------------------------------------------ */
/* OPSEL encoding: namespace[31:24] | opcode_id[7:0]                   */
/* CORE_V1 namespace = 0x01                                            */
/* ------------------------------------------------------------------ */
#define OPSEL(id)  (0x01000000u | (u32)(id))

/* CORE_V1 opcode IDs */
#define FPOP_ADD      0x01
#define FPOP_SUB      0x02
#define FPOP_MUL      0x03
#define FPOP_DIV      0x04
#define FPOP_MOVE     0x05
#define FPOP_MOVEM    0x06
#define FPOP_CMP      0x07
#define FPOP_MOD      0x08
#define FPOP_REM      0x09
#define FPOP_SCALE    0x0A
#define FPOP_SGLDIV   0x0B
#define FPOP_SGLMUL   0x0C
#define FPOP_SIN      0x0D
#define FPOP_COS      0x0E
#define FPOP_TAN      0x0F
#define FPOP_SINCOS   0x10
#define FPOP_SQRT     0x11
#define FPOP_ABS      0x12
#define FPOP_NEG      0x13
#define FPOP_INT      0x14
#define FPOP_INTRZ    0x15
#define FPOP_GETEXP   0x16
#define FPOP_GETMAN   0x17
#define FPOP_TST      0x18
#define FPOP_ACOS     0x40
#define FPOP_ASIN     0x41
#define FPOP_ATAN     0x42
#define FPOP_ATANH    0x43
#define FPOP_COSH     0x44
#define FPOP_ETOX     0x45
#define FPOP_ETOXM1   0x46
#define FPOP_LOGN     0x47
#define FPOP_LOGNP1   0x48
#define FPOP_LOG10    0x49
#define FPOP_LOG2     0x4A
#define FPOP_SINH     0x4B
#define FPOP_TANH     0x4C
#define FPOP_TENTOX   0x4D
#define FPOP_TWOTOX   0x4E

/* ------------------------------------------------------------------ */
/* FP80: 80-bit extended precision {sign+exp[15:0], sig_hi, sig_lo}    */
/* ------------------------------------------------------------------ */
typedef struct {
    u32 e;   /* bits [15:0] = sign(15) + exponent(14:0) */
    u32 h;   /* significand bits [63:32] */
    u32 l;   /* significand bits [31:0]  */
} fp80_t;

#define FP80(e, h, l) ((fp80_t){(e), (h), (l)})
#define FP80_ZERO      FP80(0x0000, 0x00000000, 0x00000000)
#define FP80_SNAN      FP80(0x7FFF, 0xBFFFFFFF, 0xFFFFFFFF)  /* signaling NaN */

/* FMOVECR move_cfg helper: dst_idx in [11:9], fmovecr_enable in [26] */
#define MOVE_CFG_FMOVECR(dst) (0x04000000u | (((u32)(dst) & 7) << 9))

/* ------------------------------------------------------------------ */
/* Timeout (polls) — ~200ms at 200 MHz with ~500ns AXI read latency   */
/* ------------------------------------------------------------------ */
#define FPU_TIMEOUT_POLLS  200000

/* ------------------------------------------------------------------ */
/* Return codes                                                        */
/* ------------------------------------------------------------------ */
#define FPU_OK        0
#define FPU_TIMEOUT  -1
#define FPU_BUS_ERR  -2

/* ------------------------------------------------------------------ */
/* API                                                                 */
/* ------------------------------------------------------------------ */

/* Low-level register access */
static inline void fpu_wr(u32 off, u32 v) { Xil_Out32(MC68881_BASE + off, v); }
static inline u32  fpu_rd(u32 off)        { return Xil_In32(MC68881_BASE + off); }

/* Check bus connectivity (returns 0 if FPU responds) */
int  fpu_probe(void);

/* Load operands into OPA/OPB registers */
void fpu_load_opa(fp80_t v);
void fpu_load_opb(fp80_t v);

/* Read result from RES registers */
fp80_t fpu_read_res(void);

/* Wait for operation completion (returns FPU_OK or FPU_TIMEOUT) */
int  fpu_wait_done(void);

/* Execute a binary operation: result = op(a, b) */
int  fpu_exec(u8 opcode, fp80_t a, fp80_t b, fp80_t *result);

/* Execute a unary/monadic operation: result = op(a) */
int  fpu_exec_unary(u8 opcode, fp80_t a, fp80_t *result);

/* FMOVECR: load constant from ROM into result */
int  fpu_movecr(u8 rom_offset, fp80_t *result);

/* Control/status register access */
u32  fpu_read_fpsr(void);
u32  fpu_read_fpcr(void);
void fpu_write_fpcr(u32 val);
u32  fpu_read_fpiar(void);
void fpu_write_fpiar(u32 val);

/* FP80 comparison with tolerance (from e2e_test.c) */
int  fp80_close(fp80_t got, fp80_t exp, u32 tol_hi, u32 tol_lo);

#endif /* FPU_PERIPH_H */
