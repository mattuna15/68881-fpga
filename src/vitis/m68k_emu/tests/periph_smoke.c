/*
 * periph_smoke.c
 * Peripheral-mode smoke test — validates fpu_periph API against
 * known e2e_test.c vectors (no Musashi, no emulator).
 */

#include <stdio.h>
#include "xil_printf.h"
#include "../fpu_periph.h"
#include "periph_smoke.h"

/* ------------------------------------------------------------------ */
/* Tolerances (same as e2e_test.c)                                     */
/* ------------------------------------------------------------------ */
#define TOL_HI    0x0u
#define TOL_LO    0x10000u     /* ~65K ULPs = ~3.5e-15 rel */
#define TRIG_HI   0x100u       /* ~2^40 ULPs = ~27 bits accuracy */
#define TRIG_LO   0x0u

static int pass_cnt;
static int fail_cnt;

static void print_fp80(const char *tag, fp80_t v)
{
    xil_printf("  %s %04lx %08lx %08lx\r\n", tag, v.e, v.h, v.l);
}

static void check_binary(const char *name, u8 opcode,
                          fp80_t a, fp80_t b, fp80_t expect,
                          u32 th, u32 tl)
{
    fp80_t got;
    int rc = fpu_exec(opcode, a, b, &got);
    if (rc != FPU_OK) {
        xil_printf("FAIL %s: %s\r\n", name,
                   rc == FPU_TIMEOUT ? "TIMEOUT" : "BUS_ERR");
        fail_cnt++;
        return;
    }
    if (fp80_close(got, expect, th, tl)) {
        xil_printf("PASS %s\r\n", name);
        pass_cnt++;
    } else {
        xil_printf("FAIL %s\r\n", name);
        print_fp80("got:   ", got);
        print_fp80("expect:", expect);
        fail_cnt++;
    }
}

static void check_unary(const char *name, u8 opcode,
                         fp80_t arg, fp80_t expect,
                         u32 th, u32 tl)
{
    fp80_t got;
    int rc = fpu_exec_unary(opcode, arg, &got);
    if (rc != FPU_OK) {
        xil_printf("FAIL %s: %s\r\n", name,
                   rc == FPU_TIMEOUT ? "TIMEOUT" : "BUS_ERR");
        fail_cnt++;
        return;
    }
    if (fp80_close(got, expect, th, tl)) {
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
/* Run all smoke tests                                                 */
/* ------------------------------------------------------------------ */
int periph_smoke_run(void)
{
    pass_cnt = 0;
    fail_cnt = 0;

    xil_printf("\r\n--- Peripheral smoke test ---\r\n");

    /* Bus probe */
    if (fpu_probe() != FPU_OK) {
        xil_printf("FATAL: No FPU response at 0x%08lx\r\n",
                   (u32)MC68881_BASE);
        return 1;
    }

    /* ADD: 3.7 + 2.4 = 6.1 */
    check_binary("ADD 3.7+2.4", FPOP_ADD,
        FP80(0x4000, 0xECCCCCCC, 0xCCCCCCCD),
        FP80(0x4000, 0x99999999, 0x9999999A),
        FP80(0x4001, 0xC3333333, 0x33333333),
        TOL_HI, TOL_LO);

    /* SUB: -2.3 - 0.6 = -2.9 */
    check_binary("SUB -2.3-0.6", FPOP_SUB,
        FP80(0xC000, 0x93333333, 0x33333333),
        FP80(0x3FFE, 0x99999999, 0x9999999A),
        FP80(0xC000, 0xB9999999, 0x9999999A),
        TOL_HI, TOL_LO);

    /* MUL: 3.7 * 2.4 = 8.88 */
    check_binary("MUL 3.7*2.4", FPOP_MUL,
        FP80(0x4000, 0xECCCCCCC, 0xCCCCCCCD),
        FP80(0x4000, 0x99999999, 0x9999999A),
        FP80(0x4002, 0x8E147AE1, 0x47AE147B),
        TOL_HI, TOL_LO);

    /* DIV: 12.5 / -0.7 = -17.857... */
    check_binary("DIV 12.5/-0.7", FPOP_DIV,
        FP80(0x4002, 0xC8000000, 0x00000000),
        FP80(0xBFFE, 0xB3333333, 0x33333333),
        FP80(0xC003, 0x8EDB6DB6, 0xDB6DB6DB),
        TOL_HI, TOL_LO);

    /* SQRT(9) = 3 (exact) */
    check_unary("SQRT(9)", FPOP_SQRT,
        FP80(0x4002, 0x90000000, 0x00000000),
        FP80(0x4000, 0xC0000000, 0x00000000),
        0, 0);

    /* SIN(1.0) */
    check_unary("SIN(1.0)", FPOP_SIN,
        FP80(0x3FFF, 0x80000000, 0x00000000),
        FP80(0x3FFE, 0xD76AA478, 0x48677020),
        TRIG_HI, TRIG_LO);

    /* FMOVECR pi */
    {
        fp80_t got;
        fp80_t pi_expect = FP80(0x4000, 0xC90FDAA2, 0x2168C235);
        int rc = fpu_movecr(0x00, &got);
        if (rc != FPU_OK) {
            xil_printf("FAIL FMOVECR(pi): %s\r\n",
                       rc == FPU_TIMEOUT ? "TIMEOUT" : "BUS_ERR");
            fail_cnt++;
        } else if (fp80_close(got, pi_expect, 0, 0)) {
            xil_printf("PASS FMOVECR(pi)\r\n");
            pass_cnt++;
        } else {
            xil_printf("FAIL FMOVECR(pi)\r\n");
            print_fp80("got:   ", got);
            print_fp80("expect:", pi_expect);
            fail_cnt++;
        }
    }

    xil_printf("--- %d passed, %d failed ---\r\n", pass_cnt, fail_cnt);
    return fail_cnt;
}
