/*
 * mc68881_smoke_test.c
 * Basic AXI-Lite register read/write test for mc68881 FPU.
 * Verifies bus connectivity by writing and reading back FPCR and FPIAR,
 * and reading FPSR.
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

#define OFF_FPCR    (11 * 4)
#define OFF_FPSR    (14 * 4)
#define OFF_FPIAR   (24 * 4)
#define OFF_STATUS  (10 * 4)

int main()
{
    int errors = 0;

    init_platform();

    xil_printf("\r\nmc68881 AXI-Lite smoke test\r\n");
    xil_printf("BASE = 0x%08lx\r\n", (u32)MC68881_BASE);

    u32 status = rd(OFF_STATUS);
    if (status == 0xFFFFFFFFu) {
        xil_printf("FATAL: No response at 0x%08lx -- check bitstream and address map\r\n",
                   (u32)MC68881_BASE);
        cleanup_platform();
        return 1;
    }
    xil_printf("STATUS  = 0x%08lx\r\n", status);

    u32 fpcr_val = 0x00000010u;
    wr(OFF_FPCR, fpcr_val);
    u32 fpcr_rb = rd(OFF_FPCR);
    if (fpcr_rb != fpcr_val) {
        xil_printf("FAIL FPCR : wrote 0x%08lx, read 0x%08lx\r\n", fpcr_val, fpcr_rb);
        errors++;
    } else {
        xil_printf("PASS FPCR : wrote 0x%08lx, read 0x%08lx\r\n", fpcr_val, fpcr_rb);
    }

    u32 fpiar_val = 0xDEADBEEFu;
    wr(OFF_FPIAR, fpiar_val);
    u32 fpiar_rb = rd(OFF_FPIAR);
    if (fpiar_rb != fpiar_val) {
        xil_printf("FAIL FPIAR: wrote 0x%08lx, read 0x%08lx\r\n", fpiar_val, fpiar_rb);
        errors++;
    } else {
        xil_printf("PASS FPIAR: wrote 0x%08lx, read 0x%08lx\r\n", fpiar_val, fpiar_rb);
    }

    u32 fpsr = rd(OFF_FPSR);
    xil_printf("FPSR    = 0x%08lx\r\n", fpsr);

    xil_printf("%d errors\r\n", errors);
    cleanup_platform();
    return errors ? 1 : 0;
}
