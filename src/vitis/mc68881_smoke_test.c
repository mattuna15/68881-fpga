/*
 * mc68881_smoke_test.c
 * Basic AXI-Lite register read/write test for mc68881 FPU.
 * Verifies bus connectivity by writing and reading back FPCR and FPIAR.
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
    init_platform();

    xil_printf("\r\nmc68881 AXI-Lite smoke test\r\n");
    xil_printf("BASE = 0x%08lx\r\n", (u32)MC68881_BASE);

    u32 status = rd(OFF_STATUS);
    xil_printf("STATUS  = 0x%08lx (bus alive)\r\n", status);

    u32 fpcr_val = 0x00000010u;
    wr(OFF_FPCR, fpcr_val);
    u32 fpcr_rb = rd(OFF_FPCR);
    xil_printf("FPCR    : wrote 0x%08lx, read 0x%08lx %s\r\n",
               fpcr_val, fpcr_rb,
               (fpcr_rb == fpcr_val) ? "OK" : "MISMATCH");

    u32 fpiar_val = 0xDEADBEEFu;
    wr(OFF_FPIAR, fpiar_val);
    u32 fpiar_rb = rd(OFF_FPIAR);
    xil_printf("FPIAR   : wrote 0x%08lx, read 0x%08lx %s\r\n",
               fpiar_val, fpiar_rb,
               (fpiar_rb == fpiar_val) ? "OK" : "MISMATCH");

    u32 fpsr = rd(OFF_FPSR);
    xil_printf("FPSR    = 0x%08lx\r\n", fpsr);

    xil_printf("done.\r\n");
    cleanup_platform();
    return 0;
}
