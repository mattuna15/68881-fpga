/*
 * mc68881_e2e_test.c
 * Lightweight end-to-end test with vectors from the GHDL testbench.
 * Tests arithmetic, trig, exponential, and logarithmic operations.
 *
 * Vitis standalone BSP application.
 */

#include <stdio.h>
#include "platform.h"
#include "xil_printf.h"
#include "xil_io.h"

#ifndef MC68881_BASE
#define MC68881_BASE 0x80000000u
#endif

static inline void wr(u32 off, u32 v) { Xil_Out32(MC68881_BASE + off, v); }
static inline u32  rd(u32 off)        { return Xil_In32(MC68881_BASE + off); }

/* Register offsets (register index * 4) */
#define OFF_OPSEL   (0  * 4)
#define OFF_OPA_L   (1  * 4)
#define OFF_OPA_H   (2  * 4)
#define OFF_OPA_E   (3  * 4)
#define OFF_OPB_L   (4  * 4)
#define OFF_OPB_H   (5  * 4)
#define OFF_OPB_E   (6  * 4)
#define OFF_RES_L   (7  * 4)
#define OFF_RES_H   (8  * 4)
#define OFF_RES_E   (9  * 4)
#define OFF_STATUS  (10 * 4)

#define STATUS_VALID  0x01

/* OPSEL: namespace[31:24] | opcode_id[7:0]   (CORE_V1 = 0x01) */
#define OPSEL(id)  (0x01000000u | (u32)(id))

#define OP_ADD    OPSEL(0x01)
#define OP_SUB    OPSEL(0x02)
#define OP_MUL    OPSEL(0x03)
#define OP_DIV    OPSEL(0x04)
#define OP_SQRT   OPSEL(0x11)
#define OP_SIN    OPSEL(0x0D)
#define OP_COS    OPSEL(0x0E)
#define OP_TAN    OPSEL(0x0F)
#define OP_ETOX   OPSEL(0x45)
#define OP_LOGN   OPSEL(0x47)

/* ------------------------------------------------------------------ */
/* FP80 helper: {exp[15:0], sig_hi[31:0], sig_lo[31:0]}              */
/* ------------------------------------------------------------------ */
typedef struct { u32 e; u32 h; u32 l; } fp80_t;

#define FP80(e,h,l) ((fp80_t){(e),(h),(l)})

static void load_opa(fp80_t v) { wr(OFF_OPA_L,v.l); wr(OFF_OPA_H,v.h); wr(OFF_OPA_E,v.e); }
static void load_opb(fp80_t v) { wr(OFF_OPB_L,v.l); wr(OFF_OPB_H,v.h); wr(OFF_OPB_E,v.e); }

static fp80_t read_res(void)
{
    fp80_t r;
    r.l = rd(OFF_RES_L);
    r.h = rd(OFF_RES_H);
    r.e = rd(OFF_RES_E) & 0xFFFFu;
    return r;
}

/* ~200ms at 200MHz with AXI read latency ~500ns per poll */
#define TIMEOUT_POLLS  200000

static int wait_done(void)
{
    for (int i = 0; i < TIMEOUT_POLLS; i++)
        if (rd(OFF_STATUS) & STATUS_VALID) return 0;
    return -1;
}

/* ------------------------------------------------------------------ */
/* FP80 comparison: exact match on exp+sign, then allow               */
/* sig_hi:sig_lo to differ by up to tol_hi:tol_lo ULPs.              */
/* tol_hi=0 for tight (arithmetic), nonzero for wide (trig ~30 bits) */
/* ------------------------------------------------------------------ */
static int fp80_close(fp80_t got, fp80_t exp, u32 tol_hi, u32 tol_lo)
{
    if (got.e != exp.e) return 0;

    /* 64-bit abs(got_sig - exp_sig) via manual subtraction */
    u32 dh, dl;
    int borrow;
    if (got.h > exp.h || (got.h == exp.h && got.l >= exp.l)) {
        dl = got.l - exp.l;
        borrow = (got.l < exp.l) ? 1 : 0;
        dh = got.h - exp.h - borrow;
    } else {
        dl = exp.l - got.l;
        borrow = (exp.l < got.l) ? 1 : 0;
        dh = exp.h - got.h - borrow;
    }
    /* Compare 64-bit diff against 64-bit tolerance */
    if (dh > tol_hi) return 0;
    if (dh < tol_hi) return 1;
    return dl <= tol_lo;  /* dh == tol_hi, compare low words */
}

/* ------------------------------------------------------------------ */
/* Test infrastructure                                                */
/* ------------------------------------------------------------------ */
static int pass_cnt = 0;
static int fail_cnt = 0;

static void print_fp80(const char *tag, fp80_t v)
{
    xil_printf("  %s %04lx %08lx %08lx\r\n", tag, v.e, v.h, v.l);
}

static void run_monadic(const char *name, u32 opsel, fp80_t arg, fp80_t expect,
                        u32 tol_hi, u32 tol_lo)
{
    load_opa(arg);
    wr(OFF_OPSEL, opsel);
    if (wait_done() < 0) {
        xil_printf("FAIL %s: TIMEOUT\r\n", name);
        fail_cnt++;
        return;
    }
    fp80_t got = read_res();
    if (fp80_close(got, expect, tol_hi, tol_lo)) {
        xil_printf("PASS %s\r\n", name);
        pass_cnt++;
    } else {
        xil_printf("FAIL %s\r\n", name);
        print_fp80("got:   ", got);
        print_fp80("expect:", expect);
        fail_cnt++;
    }
}

static void run_binary(const char *name, u32 opsel, fp80_t a, fp80_t b,
                        fp80_t expect, u32 tol_hi, u32 tol_lo)
{
    load_opa(a);
    load_opb(b);
    wr(OFF_OPSEL, opsel);
    if (wait_done() < 0) {
        xil_printf("FAIL %s: TIMEOUT\r\n", name);
        fail_cnt++;
        return;
    }
    fp80_t got = read_res();
    if (fp80_close(got, expect, tol_hi, tol_lo)) {
        xil_printf("PASS %s\r\n", name);
        pass_cnt++;
    } else {
        xil_printf("FAIL %s\r\n", name);
        print_fp80("got:   ", got);
        print_fp80("expect:", expect);
        fail_cnt++;
    }
}

/* ------------------------------------------------------------------ */
/* Test vectors from tb_mc68881_alu.vhd / mc68881_golden_vectors_pkg  */
/*                                                                    */
/* Tolerances (64-bit ULP as hi:lo pair):                             */
/*   TOL    = 0:0x10000   tight, for arithmetic/exp/log (~50+ bits)   */
/*   TRIG   = 0x100:0     wide, for sin/cos/tan (~27-30 bits)        */
/* ------------------------------------------------------------------ */

#define TOL_HI    0x0u
#define TOL_LO    0x10000u     /* ~65K ULPs = ~3.5e-15 rel */
#define TRIG_HI   0x100u       /* ~2^40 ULPs = ~27 bits accuracy */
#define TRIG_LO   0x0u

int main()
{
    init_platform();
    xil_printf("\r\nmc68881 e2e test (vectors from GHDL tb)\r\n");
    xil_printf("========================================\r\n");

    u32 status = rd(OFF_STATUS);
    if (status == 0xFFFFFFFFu) {
        xil_printf("FATAL: No response at 0x%08lx -- check bitstream and address map\r\n",
                   (u32)MC68881_BASE);
        cleanup_platform();
        return 1;
    }

    /* --- Arithmetic --- */

    /* ADD: 3.7 + 2.4 = 6.1 */
    run_binary("ADD 3.7+2.4",  OP_ADD,
        FP80(0x4000, 0xECCCCCCC, 0xCCCCCCCD),   /* 3.7 */
        FP80(0x4000, 0x99999999, 0x9999999A),   /* 2.4 */
        FP80(0x4001, 0xC3333333, 0x33333333),   /* 6.1 */
        TOL_HI, TOL_LO);

    /* SUB: -2.3 - 0.6 = -2.9 */
    run_binary("SUB -2.3-0.6", OP_SUB,
        FP80(0xC000, 0x93333333, 0x33333333),   /* -2.3 */
        FP80(0x3FFE, 0x99999999, 0x9999999A),   /* 0.6 */
        FP80(0xC000, 0xB9999999, 0x9999999A),   /* -2.9 */
        TOL_HI, TOL_LO);

    /* MUL: 3.7 * 2.4 = 8.88 */
    run_binary("MUL 3.7*2.4",  OP_MUL,
        FP80(0x4000, 0xECCCCCCC, 0xCCCCCCCD),   /* 3.7 */
        FP80(0x4000, 0x99999999, 0x9999999A),   /* 2.4 */
        FP80(0x4002, 0x8E147AE1, 0x47AE147B),   /* 8.88 */
        TOL_HI, TOL_LO);

    /* DIV: 12.5 / -0.7 = -17.857142... */
    run_binary("DIV 12.5/-0.7", OP_DIV,
        FP80(0x4002, 0xC8000000, 0x00000000),   /* 12.5 */
        FP80(0xBFFE, 0xB3333333, 0x33333333),   /* -0.7 */
        FP80(0xC003, 0x8EDB6DB6, 0xDB6DB6DB),   /* -17.857.. */
        TOL_HI, TOL_LO);

    /* SQRT(9) = 3 */
    run_monadic("SQRT(9)", OP_SQRT,
        FP80(0x4002, 0x90000000, 0x00000000),   /* 9.0 */
        FP80(0x4000, 0xC0000000, 0x00000000),   /* 3.0 */
        0, 0);  /* exact */

    /* --- Trig (~30 bits accuracy, wide tolerance) --- */

    /* SIN(1.0) - verified on hardware */
    run_monadic("SIN(1.0)", OP_SIN,
        FP80(0x3FFF, 0x80000000, 0x00000000),   /* 1.0 */
        FP80(0x3FFE, 0xD76AA478, 0x48677020),   /* sin(1) */
        TRIG_HI, TRIG_LO);

    /* SIN(1.1) */
    run_monadic("SIN(1.1)", OP_SIN,
        FP80(0x3FFF, 0x8CCCCCCC, 0xCCCCCCCD),   /* 1.1 */
        FP80(0x3FFE, 0xE4262A61, 0x6B19BA80),   /* sin(1.1) */
        TRIG_HI, TRIG_LO);

    /* SIN(-0.7) */
    run_monadic("SIN(-0.7)", OP_SIN,
        FP80(0xBFFE, 0xB3333333, 0x33333333),   /* -0.7 */
        FP80(0xBFFE, 0xA4EB734A, 0x30CDC2A8),   /* sin(-0.7) */
        TRIG_HI, TRIG_LO);

    /* COS(-2.3) */
    run_monadic("COS(-2.3)", OP_COS,
        FP80(0xC000, 0x93333333, 0x33333333),   /* -2.3 */
        FP80(0xBFFE, 0xAA9110B9, 0x817F0E68),   /* cos(-2.3) */
        TRIG_HI, TRIG_LO);

    /* COS(0.3) */
    run_monadic("COS(0.3)", OP_COS,
        FP80(0x3FFD, 0x99999999, 0x99999800),   /* 0.3 */
        FP80(0x3FFE, 0xF490EEA1, 0x784DD000),   /* cos(0.3) */
        TRIG_HI, TRIG_LO);

    /* TAN(0.9) */
    run_monadic("TAN(0.9)", OP_TAN,
        FP80(0x3FFE, 0xE6666666, 0x66666800),   /* 0.9 */
        FP80(0x3FFF, 0xA14CDD4E, 0x1509BE2A),   /* tan(0.9) */
        TRIG_HI, TRIG_LO);

    /* --- Exp / Log --- */

    /* e^0.75 */
    run_monadic("ETOX(0.75)", OP_ETOX,
        FP80(0x3FFE, 0xC0000000, 0x00000000),   /* 0.75 */
        FP80(0x4000, 0x877CEDA3, 0x3EE7BDEA),   /* e^0.75 */
        TOL_HI, TOL_LO);

    /* ln(1.25) */
    run_monadic("LOGN(1.25)", OP_LOGN,
        FP80(0x3FFF, 0xA0000000, 0x00000000),   /* 1.25 */
        FP80(0x3FFC, 0xE47FBE3C, 0xD4D10D61),   /* ln(1.25) */
        TOL_HI, TOL_LO);

    /* --- Edge cases --- */

    /* SIN(0) = 0 (exact) */
    run_monadic("SIN(0)", OP_SIN,
        FP80(0x0000, 0x00000000, 0x00000000),
        FP80(0x0000, 0x00000000, 0x00000000),
        0, 0);

    /* SQRT(1) = 1 (exact) */
    run_monadic("SQRT(1)", OP_SQRT,
        FP80(0x3FFF, 0x80000000, 0x00000000),
        FP80(0x3FFF, 0x80000000, 0x00000000),
        0, 0);

    /* --- Summary --- */
    xil_printf("========================================\r\n");
    xil_printf("%d passed, %d failed, %d total\r\n",
               pass_cnt, fail_cnt, pass_cnt + fail_cnt);
    if (fail_cnt == 0)
        xil_printf("ALL TESTS PASSED\r\n");

    cleanup_platform();
    return fail_cnt ? 1 : 0;
}
