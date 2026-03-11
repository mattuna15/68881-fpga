/*
 * cir_dialog.c
 * CIR dialog protocol test — validates the AN-947 coprocessor interface
 * state machine from the ARM Cortex-A53 over AXI-Lite.
 *
 * Tests exercise mem-to-reg, reg-to-reg, and reg-to-mem CIR dialogs
 * with various data formats and operations.
 */

#include <stdio.h>
#include "xil_printf.h"
#include "../cir_periph.h"

static int pass_cnt;
static int fail_cnt;

/* ------------------------------------------------------------------ */
/* Tolerances                                                          */
/* ------------------------------------------------------------------ */
#define TOL_HI    0x0u
#define TOL_LO    0x10000u     /* ~65K ULPs */
#define TRIG_HI   0x100u       /* ~2^40 ULPs for transcendentals */
#define TRIG_LO   0x0u

/* ------------------------------------------------------------------ */
/* Helpers                                                             */
/* ------------------------------------------------------------------ */
static void print_fp80(const char *tag, fp80_t v)
{
    xil_printf("  %s %04lx %08lx %08lx\r\n", tag, v.e, v.h, v.l);
}

/* Load integer into FP register via CIR FMOVE.L mem-to-reg */
static int cir_load_long(u8 dst_reg, u32 int_val)
{
    u32 op = int_val;
    return cir_cpgen_mem_to_reg(CIR_FMT_LONG, dst_reg, FPOP_MOVE, &op, 1);
}

/* Load single-precision into FP register via CIR FMOVE.S mem-to-reg */
static int cir_load_single(u8 dst_reg, u32 ieee_single)
{
    return cir_cpgen_mem_to_reg(CIR_FMT_SINGLE, dst_reg, FPOP_MOVE,
                                &ieee_single, 1);
}

/* Readback FP register as long integer via CIR FMOVE.L reg-to-mem */
static int cir_readback_long(u8 src_reg, u32 *result)
{
    return cir_cpgen_reg_to_mem(CIR_FMT_LONG, src_reg, result, 1);
}

/* Readback FP register as extended (3 words) via CIR FMOVE.X reg-to-mem */
static int cir_readback_ext(u8 src_reg, fp80_t *result)
{
    u32 words[3];
    int rc = cir_cpgen_reg_to_mem(CIR_FMT_EXTENDED, src_reg, words, 3);
    if (rc != CIR_OK)
        return rc;
    result->e = words[0] & 0xFFFFu;
    result->h = words[1];
    result->l = words[2];
    return CIR_OK;
}

/* ------------------------------------------------------------------ */
/* Test 1: FMOVE.L round-trip (mem-to-reg + reg-to-mem)                */
/* Load 42 into FP0, read back as long, expect 42.                     */
/* ------------------------------------------------------------------ */
static void test1_fmove_long_roundtrip(void)
{
    int rc;
    u32 got;

    rc = cir_load_long(0, 42);
    if (rc != CIR_OK) {
        xil_printf("FAIL CIR.1 FMOVE.L load: TIMEOUT\r\n");
        fail_cnt++;
        return;
    }

    rc = cir_readback_long(0, &got);
    if (rc != CIR_OK) {
        xil_printf("FAIL CIR.1 FMOVE.L readback: TIMEOUT\r\n");
        fail_cnt++;
        return;
    }

    if (got == 42) {
        xil_printf("PASS CIR.1 FMOVE.L round-trip (42)\r\n");
        pass_cnt++;
    } else {
        xil_printf("FAIL CIR.1 FMOVE.L round-trip: got %lu, expect 42\r\n",
                   (unsigned long)got);
        fail_cnt++;
    }
}

/* ------------------------------------------------------------------ */
/* Test 2: FADD.S mem-to-reg                                           */
/* FP0=42 (from test 1), FADD.S #3.7f -> FP0 should be ~45.7          */
/* ------------------------------------------------------------------ */
static void test2_fadd_single_mem(void)
{
    int rc;
    u32 ieee_3_7 = 0x406CCCCDU;  /* 3.7f */
    u32 op = ieee_3_7;

    rc = cir_cpgen_mem_to_reg(CIR_FMT_SINGLE, 0, FPOP_ADD, &op, 1);
    if (rc != CIR_OK) {
        xil_printf("FAIL CIR.2 FADD.S mem: TIMEOUT\r\n");
        fail_cnt++;
        return;
    }

    /* Readback as extended and compare */
    fp80_t got;
    rc = cir_readback_ext(0, &got);
    if (rc != CIR_OK) {
        xil_printf("FAIL CIR.2 FADD.S readback: TIMEOUT\r\n");
        fail_cnt++;
        return;
    }

    /* 42.0 + 3.7f ≈ 45.7  (single-precision 3.7 = 3.70000004768...)
     * 3.7f = 0x406CCCCD → FP80 mantissa 0xECCCCD00_00000000
     * Expected FP80: exp=0x4004, sig = 0xB6CCCCD0_00000000 */
    fp80_t expect = FP80(0x4004, 0xB6CCCCD0, 0x00000000);
    if (fp80_close(got, expect, TOL_HI + 1, TOL_LO)) {
        xil_printf("PASS CIR.2 FADD.S mem (42+3.7)\r\n");
        pass_cnt++;
    } else {
        xil_printf("FAIL CIR.2 FADD.S mem\r\n");
        print_fp80("got:   ", got);
        print_fp80("expect:", expect);
        fail_cnt++;
    }
}

/* ------------------------------------------------------------------ */
/* Test 3: Reg-to-reg FADD                                             */
/* Load FP1=1, FADD FP1,FP0 (FP0 ~45.7 -> ~46.7)                     */
/* ------------------------------------------------------------------ */
static void test3_fadd_reg_to_reg(void)
{
    int rc;

    /* Load FP1 = 1 */
    rc = cir_load_long(1, 1);
    if (rc != CIR_OK) {
        xil_printf("FAIL CIR.3 load FP1: TIMEOUT\r\n");
        fail_cnt++;
        return;
    }

    /* FADD FP1, FP0 (reg-to-reg) */
    rc = cir_cpgen_reg_to_reg(1, 0, FPOP_ADD);
    if (rc != CIR_OK) {
        xil_printf("FAIL CIR.3 FADD reg: TIMEOUT\r\n");
        fail_cnt++;
        return;
    }

    /* Readback FP0 as long integer — should be ~46 (truncated) */
    u32 got;
    rc = cir_readback_long(0, &got);
    if (rc != CIR_OK) {
        xil_printf("FAIL CIR.3 readback: TIMEOUT\r\n");
        fail_cnt++;
        return;
    }

    /* FP0 was ~45.7, +1 = ~46.7.  FMOVE.L converts to integer using
     * the current rounding mode (default: round-to-nearest → 47). */
    if (got == 46 || got == 47) {
        xil_printf("PASS CIR.3 FADD reg-to-reg (FP1+FP0=%lu)\r\n",
                   (unsigned long)got);
        pass_cnt++;
    } else {
        xil_printf("FAIL CIR.3 FADD reg-to-reg: got %lu, expect 46 or 47\r\n",
                   (unsigned long)got);
        fail_cnt++;
    }
}

/* ------------------------------------------------------------------ */
/* Test 4: FMUL.S mem-to-reg                                           */
/* Load FP2=3.7f, then FMUL.S #2.4f, FP2 -> ~8.88                     */
/* ------------------------------------------------------------------ */
static void test4_fmul_single_mem(void)
{
    int rc;

    /* Load FP2 = 3.7f */
    rc = cir_load_single(2, 0x406CCCCDU);
    if (rc != CIR_OK) {
        xil_printf("FAIL CIR.4 load FP2: TIMEOUT\r\n");
        fail_cnt++;
        return;
    }

    /* FMUL.S #2.4f, FP2 */
    u32 ieee_2_4 = 0x4019999Au;  /* 2.4f */
    rc = cir_cpgen_mem_to_reg(CIR_FMT_SINGLE, 2, FPOP_MUL, &ieee_2_4, 1);
    if (rc != CIR_OK) {
        xil_printf("FAIL CIR.4 FMUL.S: TIMEOUT\r\n");
        fail_cnt++;
        return;
    }

    /* Readback via CIR extended and compare with expected value */
    fp80_t cir_got;
    rc = cir_readback_ext(2, &cir_got);
    if (rc != CIR_OK) {
        xil_printf("FAIL CIR.4 readback: TIMEOUT\r\n");
        fail_cnt++;
        return;
    }

    /* 3.7f * 2.4f ≈ 8.88.  Both inputs are single-precision so the result
     * has ~23 bits of significand precision.  Use a generous tolerance
     * (tol_hi=0x100 ≈ 2^40 ULPs of the 64-bit significand). */
    fp80_t expect = FP80(0x4002, 0x8E147AE1, 0x00000000);  /* ~8.88 */
    if (fp80_close(cir_got, expect, 0x100u, 0x0u)) {
        xil_printf("PASS CIR.4 FMUL.S (3.7f*2.4f~8.88)\r\n");
        pass_cnt++;
    } else {
        xil_printf("FAIL CIR.4 FMUL.S\r\n");
        print_fp80("got:   ", cir_got);
        print_fp80("expect:", expect);
        fail_cnt++;
    }
}

/* ------------------------------------------------------------------ */
/* Test 5: FSQRT.L mem-to-reg                                          */
/* FSQRT.L #9 -> FP3, expect 3.0 exactly                              */
/* ------------------------------------------------------------------ */
static void test5_fsqrt_long(void)
{
    int rc;
    u32 op = 9;

    rc = cir_cpgen_mem_to_reg(CIR_FMT_LONG, 3, FPOP_SQRT, &op, 1);
    if (rc != CIR_OK) {
        xil_printf("FAIL CIR.5 FSQRT.L: TIMEOUT\r\n");
        fail_cnt++;
        return;
    }

    fp80_t got;
    rc = cir_readback_ext(3, &got);
    if (rc != CIR_OK) {
        xil_printf("FAIL CIR.5 readback: TIMEOUT\r\n");
        fail_cnt++;
        return;
    }

    fp80_t expect = FP80(0x4000, 0xC0000000, 0x00000000);  /* 3.0 */
    if (fp80_close(got, expect, 0, 0)) {
        xil_printf("PASS CIR.5 FSQRT(9)=3 exact\r\n");
        pass_cnt++;
    } else {
        xil_printf("FAIL CIR.5 FSQRT(9)\r\n");
        print_fp80("got:   ", got);
        print_fp80("expect:", expect);
        fail_cnt++;
    }
}

/* ------------------------------------------------------------------ */
/* Test 6: FSIN.L mem-to-reg                                           */
/* FSIN.L #1 -> FP4, compare to sin(1.0)                              */
/* ------------------------------------------------------------------ */
static void test6_fsin_long(void)
{
    int rc;
    u32 op = 1;

    rc = cir_cpgen_mem_to_reg(CIR_FMT_LONG, 4, FPOP_SIN, &op, 1);
    if (rc != CIR_OK) {
        xil_printf("FAIL CIR.6 FSIN.L: TIMEOUT\r\n");
        fail_cnt++;
        return;
    }

    fp80_t got;
    rc = cir_readback_ext(4, &got);
    if (rc != CIR_OK) {
        xil_printf("FAIL CIR.6 readback: TIMEOUT\r\n");
        fail_cnt++;
        return;
    }

    fp80_t expect = FP80(0x3FFE, 0xD76AA478, 0x48677020);  /* sin(1.0) */
    if (fp80_close(got, expect, TRIG_HI, TRIG_LO)) {
        xil_printf("PASS CIR.6 FSIN(1)\r\n");
        pass_cnt++;
    } else {
        xil_printf("FAIL CIR.6 FSIN(1)\r\n");
        print_fp80("got:   ", got);
        print_fp80("expect:", expect);
        fail_cnt++;
    }
}

/* ------------------------------------------------------------------ */
/* Test 7: Extended format round-trip (3-word transfer)                 */
/* Load FP80 pi via FMOVE.X mem-to-reg, readback as extended.          */
/* ------------------------------------------------------------------ */
static void test7_extended_roundtrip(void)
{
    int rc;

    /* Pi in FP80: exp=0x4000, sig=0xC90FDAA2_2168C235 */
    u32 words_in[3];
    words_in[0] = 0x4000u;         /* sign + exponent */
    words_in[1] = 0xC90FDAA2u;     /* significand hi */
    words_in[2] = 0x2168C235u;     /* significand lo */

    rc = cir_cpgen_mem_to_reg(CIR_FMT_EXTENDED, 5, FPOP_MOVE, words_in, 3);
    if (rc != CIR_OK) {
        xil_printf("FAIL CIR.7 FMOVE.X load: TIMEOUT\r\n");
        fail_cnt++;
        return;
    }

    fp80_t got;
    rc = cir_readback_ext(5, &got);
    if (rc != CIR_OK) {
        xil_printf("FAIL CIR.7 FMOVE.X readback: TIMEOUT\r\n");
        fail_cnt++;
        return;
    }

    fp80_t expect = FP80(0x4000, 0xC90FDAA2, 0x2168C235);  /* pi */
    if (fp80_close(got, expect, 0, 0)) {
        xil_printf("PASS CIR.7 FMOVE.X extended round-trip (pi)\r\n");
        pass_cnt++;
    } else {
        xil_printf("FAIL CIR.7 FMOVE.X extended round-trip\r\n");
        print_fp80("got:   ", got);
        print_fp80("expect:", expect);
        fail_cnt++;
    }
}

/* ------------------------------------------------------------------ */
/* Run all CIR dialog tests                                            */
/* ------------------------------------------------------------------ */
int cir_dialog_run(void)
{
    pass_cnt = 0;
    fail_cnt = 0;

    xil_printf("\r\n--- CIR dialog protocol test ---\r\n");

    /* Bus probe (reuse from fpu_periph) */
    if (fpu_probe() != FPU_OK) {
        xil_printf("FATAL: No FPU response at 0x%08lx\r\n",
                   (u32)MC68881_BASE);
        return 1;
    }

    /* Debug: read CIR state before first dialog */
    {
        u32 resp_before = cir_rd(OFF_CIR_RESPONSE);
        u32 status = cir_rd(OFF_STATUS);
        xil_printf("  [init] resp=0x%08lx status=0x%02lx\r\n",
                   resp_before, status & 0x7Fu);
    }

    test1_fmove_long_roundtrip();
    test2_fadd_single_mem();
    test3_fadd_reg_to_reg();
    test4_fmul_single_mem();
    test5_fsqrt_long();
    test6_fsin_long();
    test7_extended_roundtrip();

    xil_printf("--- CIR: %d passed, %d failed ---\r\n", pass_cnt, fail_cnt);
    return fail_cnt;
}
