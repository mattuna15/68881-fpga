/*
 * mc68881_fsin_test.c
 * Compute sin(1.0) and sin(0.0) on the mc68881 FPU via AXI-Lite.
 * Loads FP80 operand, triggers FSIN, polls for completion, reads result.
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
#define OFF_RES_L   (7  * 4)
#define OFF_RES_H   (8  * 4)
#define OFF_RES_E   (9  * 4)
#define OFF_STATUS  (10 * 4)
#define OFF_FPSR    (14 * 4)

/* OPSEL encoding: namespace[31:24] | opcode_id[7:0] */
/* CORE_V1 namespace = 0x01, SIN opcode = 0x0D */
#define OPSEL_SIN   0x0100000Du

#define STATUS_VALID  0x01

static void load_fp80(u32 lo, u32 hi, u32 ex)
{
    wr(OFF_OPA_L, lo);
    wr(OFF_OPA_H, hi);
    wr(OFF_OPA_E, ex);
}

/* ~200ms at 200MHz with AXI read latency ~500ns per poll */
#define TIMEOUT_POLLS  200000

static int wait_done(void)
{
    for (int i = 0; i < TIMEOUT_POLLS; i++) {
        u32 st = rd(OFF_STATUS);
        if (st & STATUS_VALID)
            return 0;
    }
    return -1;
}

int main()
{
    int errors = 0;

    init_platform();

    xil_printf("\r\nmc68881 FSIN test\r\n");

    u32 status = rd(OFF_STATUS);
    if (status == 0xFFFFFFFFu) {
        xil_printf("FATAL: No response at 0x%08lx -- check bitstream and address map\r\n",
                   (u32)MC68881_BASE);
        cleanup_platform();
        return 1;
    }

    /* --- sin(1.0) --- */
    /* FP80 1.0 = 0x3FFF 80000000 00000000 */
    xil_printf("Computing sin(1.0)...\r\n");
    load_fp80(0x00000000u, 0x80000000u, 0x3FFFu);
    wr(OFF_OPSEL, OPSEL_SIN);

    if (wait_done() < 0) {
        xil_printf("FAIL sin(1.0): TIMEOUT, STATUS = 0x%08lx\r\n", rd(OFF_STATUS));
        errors++;
    } else {
        u32 res_l = rd(OFF_RES_L);
        u32 res_h = rd(OFF_RES_H);
        u32 res_e = rd(OFF_RES_E);
        u32 fpsr  = rd(OFF_FPSR);

        xil_printf("  RES_E = 0x%04lx (sign+exp)\r\n", res_e & 0xFFFF);
        xil_printf("  RES_H = 0x%08lx (sig hi)\r\n", res_h);
        xil_printf("  RES_L = 0x%08lx (sig lo)\r\n", res_l);
        xil_printf("  FPSR  = 0x%08lx\r\n", fpsr);
        xil_printf("  expect: 3FFE D76AA478 48677020\r\n");
    }

    /* --- sin(0.0) --- */
    /* FP80 0.0 = 0x0000 00000000 00000000 */
    xil_printf("Computing sin(0.0)...\r\n");
    load_fp80(0x00000000u, 0x00000000u, 0x0000u);
    wr(OFF_OPSEL, OPSEL_SIN);

    if (wait_done() < 0) {
        xil_printf("FAIL sin(0.0): TIMEOUT, STATUS = 0x%08lx\r\n", rd(OFF_STATUS));
        errors++;
    } else {
        u32 res_l = rd(OFF_RES_L);
        u32 res_h = rd(OFF_RES_H);
        u32 res_e = rd(OFF_RES_E);

        xil_printf("  RES_E = 0x%04lx\r\n", res_e & 0xFFFF);
        xil_printf("  RES_H = 0x%08lx\r\n", res_h);
        xil_printf("  RES_L = 0x%08lx\r\n", res_l);
        xil_printf("  expect: 0000 00000000 00000000\r\n");
    }

    xil_printf("%d errors\r\n", errors);
    cleanup_platform();
    return errors ? 1 : 0;
}
