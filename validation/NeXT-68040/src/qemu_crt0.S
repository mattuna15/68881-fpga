/*
 * qemu_crt0.S
 * Minimal AArch64 startup for QEMU bare-metal (no Xilinx crt0).
 * Sets up stack, zeroes BSS, calls main.
 */

.global _start
.global _vector_table

.section .text.boot, "ax"

_vector_table:
_start:
    /* Disable interrupts */
    msr daifset, #0xF

    /* Set stack pointer (linker provides _el3_stack_end from lscript.ld) */
    ldr x0, =_el3_stack_end
    mov sp, x0

    /* Zero BSS section */
    ldr x0, =__bss_start__
    ldr x1, =__bss_end__
    mov x2, #0
1:  cmp x0, x1
    b.ge 2f
    str x2, [x0], #8
    b 1b
2:

    /* Call main */
    bl main

    /* If main returns, spin */
3:  wfe
    b 3b
