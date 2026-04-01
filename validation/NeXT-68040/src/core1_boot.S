/*
 * core1_boot.S
 * Cortex-A53 core 1 startup for ZynqMP at EL3.
 *
 * Replicates the essential parts of the BSP boot.S so that core 1 has:
 * - Hardware coherency (SMPEN)
 * - MMU with the same translation tables as core 0
 * - I-cache and D-cache enabled
 * - FP/SIMD access (CPTR_EL3 cleared)
 *
 * Then sets the stack and branches to core1_main() in render_core1.c.
 */

.globl MMUTableL0
.globl core1_entry
.globl core1_main
.globl core1_stack
.globl _vector_table

.set L0Table,     MMUTableL0
.set vector_base, _vector_table

.text
.align 6                               /* 64-byte / cache-line aligned */

core1_entry:
    /* ---- Exception vectors (reuse core 0's table) ---- */
    ldr     x1, =vector_base
    msr     VBAR_EL3, x1

    /* ---- Enable hardware coherency (SMPEN) ---- */
    mrs     x0, S3_1_c15_c2_1         /* CPUECTLR_EL1 */
    orr     x0, x0, #(1 << 6)         /* SMPEN bit */
    msr     S3_1_c15_c2_1, x0
    isb

    /* ---- Allow FP/SIMD access from EL3 ---- */
    mov     x0, #0
    msr     CPTR_EL3, x0              /* clear all trap bits */
    isb

    /* ---- Configure SCR_EL3 ---- */
    mov     w0, #0
    orr     w0, w0, #(1 << 11)        /* ST  */
    orr     w0, w0, #(1 << 10)        /* RW — EL1 is AArch64 */
    orr     w0, w0, #(1 << 3)         /* EA  */
    orr     w0, w0, #(1 << 2)         /* FIQ */
    orr     w0, w0, #(1 << 1)         /* IRQ */
    msr     SCR_EL3, x0

    /* ---- Invalidate TLBs and caches ---- */
    tlbi    ALLE3
    ic      IALLU
    bl      .Linvalidate_dcaches
    dsb     sy
    isb

    /* ---- Set up MMU (reuse core 0's translation tables) ---- */
    ldr     x1, =L0Table
    msr     TTBR0_EL3, x1

    /*
     * Memory attributes — same as boot.S:
     *   0 = Normal, Inner/Outer Non-Cacheable
     *   1 = Normal, Inner/Outer WB/WA/RA
     *   2 = Device-nGnRnE
     *   3 = Device-nGnRE
     *   4 = Normal, Inner/Outer WT/WA/RA
     */
    ldr     x1, =0x000000BB0400FF44
    msr     MAIR_EL3, x1

    /* TCR_EL3: PS=010 (40-bit/1TB), TG0=4KB, T0SZ=24 */
    ldr     x1, =0x80823518
    msr     TCR_EL3, x1
    isb

    /* ---- Enable I-cache, D-cache, MMU ---- */
    mov     x1, #0
    orr     x1, x1, #(1 << 12)        /* I — instruction cache */
    orr     x1, x1, #(1 << 3)         /* SA — SP alignment check */
    orr     x1, x1, #(1 << 2)         /* C — data cache */
    orr     x1, x1, #(1 << 0)         /* M — MMU enable */
    msr     SCTLR_EL3, x1
    dsb     sy
    isb

    /* ---- Set stack and enter C ---- */
    ldr     x0, =core1_stack + 16384  /* top of 16KB stack */
    mov     sp, x0
    b       core1_main


/* ------------------------------------------------------------------ */
/* D-cache invalidation (same algorithm as BSP boot.S)                 */
/* ------------------------------------------------------------------ */
.Linvalidate_dcaches:
    dmb     ISH
    mrs     x0, CLIDR_EL1
    ubfx    w2, w0, #24, #3           /* LoC */
    cmp     w2, #0
    b.eq    .Linv_done
    mov     w1, #0

.Linv_level:
    add     w3, w1, w1, lsl #1
    lsr     w3, w0, w3
    ubfx    w3, w3, #0, #3
    cmp     w3, #2
    b.lt    .Linv_next

    lsl     w4, w1, #1
    msr     CSSELR_EL1, x4
    isb
    mrs     x4, CCSIDR_EL1

    ubfx    w3, w4, #0, #3
    add     w3, w3, #2
    ubfx    w5, w4, #13, #15
    ubfx    w4, w4, #3, #10
    clz     w6, w4

.Linv_set:
    mov     w8, w4
.Linv_way:
    lsl     w7, w1, #1
    lsl     w9, w5, w3
    orr     w7, w7, w9
    lsl     w9, w8, w6
    orr     w7, w7, w9
    dc      CISW, x7
    subs    w8, w8, #1
    b.ge    .Linv_way
    subs    w5, w5, #1
    b.ge    .Linv_set

.Linv_next:
    add     w1, w1, #1
    cmp     w2, w1
    b.gt    .Linv_level

.Linv_done:
    ret
