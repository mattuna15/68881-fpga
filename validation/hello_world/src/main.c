/*
 * main.c
 * M68K emulator + hardware FPU test application.
 * Entry point for Vitis standalone BSP on AXU3EG (ZU3EG).
 *
 * Test selector: reads DIP switches or defaults to running all tests.
 * For now, just runs all tests sequentially.
 */

#include <stdio.h>
#include "platform.h"
#include "xil_printf.h"
#include "fpu_periph.h"
#include "tests/periph_smoke.h"
#include "tests/basic_fpu.h"
#include "tests/cir_dialog.h"

int main(void)
{
    int total_failures = 0;

    init_platform();

    xil_printf("\r\n");
    xil_printf("================================================\r\n");
    xil_printf("  mc68881 M68K Emulator FPU Validation\r\n");
    xil_printf("  Musashi + F-line trap + AXI-Lite peripheral\r\n");
    xil_printf("================================================\r\n");

    /* Phase 1: Peripheral driver smoke test (no Musashi) */
    total_failures += periph_smoke_run();

    /* Phase 2: CIR dialog protocol (AN-947 coprocessor interface) */
    total_failures += cir_dialog_run();

    /* Phase 3: Musashi + F-line handler integration */
    total_failures += basic_fpu_run();

    /* Summary */
    xil_printf("\r\n================================================\r\n");
    if (total_failures == 0)
        xil_printf("ALL TESTS PASSED\r\n");
    else
        xil_printf("TOTAL FAILURES: %d\r\n", total_failures);
    xil_printf("================================================\r\n");

    cleanup_platform();
    return total_failures ? 1 : 0;
}
