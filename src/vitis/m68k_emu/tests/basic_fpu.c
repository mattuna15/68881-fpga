/*
 * basic_fpu.c
 * Integration test: Musashi M68K emulator + F-line handler + hardware FPU.
 *
 * Hand-assembled M68K FPU instruction sequences are loaded into emu_ram[],
 * Musashi executes them, F-line traps fire the hardware FPU, and we
 * verify results by reading back from the software FP register file.
 *
 * 68881 F-line instruction encoding reference:
 *
 *   Opword:   1111 001 000 mmm rrr    (CpID=001, type=000, EA mode/reg)
 *   Command:  R/M 0 src[2:0] dst[2:0] opcode[6:0]
 *
 *   R/M=0, reg-to-reg:  0_0_sss_ddd_ooooooo
 *   R/M=1, mem-to-reg:  1_0_fff_ddd_ooooooo  (fff=format, EA in opword)
 *
 * Format codes: 0=Long, 1=Single, 2=Extended, 3=Packed, 4=Word, 5=Double, 6=Byte
 *
 * 68881 opcodes (7-bit): FMOVE=0x00, FADD=0x22, FSUB=0x28, FMUL=0x23,
 *   FDIV=0x20, FSQRT=0x04, FSIN=0x0E, FCOS=0x1D, FCMP=0x38, FTST=0x3A,
 *   FMOVECR=special (cmd=0x5C00|dst<<7|rom_offset)
 *
 * TRAP #15 is used as a "halt" mechanism — Musashi stops when cycle count
 * is exhausted or we catch the trap.
 */

#include <stdio.h>
#include "xil_printf.h"
#include "../fpu_periph.h"
#include "../fp_regfile.h"
#include "../fline_handler.h"
#include "../emu_memory.h"
#include "../musashi/m68k.h"
#include "basic_fpu.h"

/* ------------------------------------------------------------------ */
/* Helpers                                                             */
/* ------------------------------------------------------------------ */

/* Write a big-endian 16-bit word into emu_ram at addr */
static void poke16(unsigned int addr, unsigned int val)
{
    m68k_write_memory_16(addr, val);
}

/* Write a big-endian 32-bit word into emu_ram at addr */
static void poke32(unsigned int addr, unsigned int val)
{
    m68k_write_memory_32(addr, val);
}

static int pass_cnt;
static int fail_cnt;

#define TOL_HI  0x0u
#define TOL_LO  0x10000u
#define TRIG_HI 0x100u
#define TRIG_LO 0x0u

static void check(const char *name, int reg, fp80_t expect, u32 th, u32 tl)
{
    fp80_t got = fp_reg_get(reg);
    if (fp80_close(got, expect, th, tl)) {
        xil_printf("PASS %s\r\n", name);
        pass_cnt++;
    } else {
        xil_printf("FAIL %s\r\n", name);
        xil_printf("  got:    %04lx %08lx %08lx\r\n", got.e, got.h, got.l);
        xil_printf("  expect: %04lx %08lx %08lx\r\n", expect.e, expect.h, expect.l);
        fail_cnt++;
    }
}

/* ------------------------------------------------------------------ */
/* Test programs                                                       */
/* ------------------------------------------------------------------ */

/*
 * Test 1: FMOVECR pi -> FP0, then FADD.X FP0,FP1 (FP1 = FP1 + FP0)
 *
 * We first load pi into FP0 via FMOVECR, then load 1.0 into FP1 via
 * FMOVE.L #1, FP1, then FADD.X FP0,FP1 -> FP1 = pi + 1.0
 *
 * Assembly:
 *   FMOVECR  #$00, FP0          ; FP0 = pi
 *   FMOVE.L  #1, FP1            ; FP1 = 1.0
 *   FADD.X   FP0, FP1           ; FP1 = pi + 1.0
 *   TRAP     #15                 ; halt
 */
static void test_fmovecr_and_add(void)
{
    unsigned int pc = 0x1000;

    /* FMOVECR #$00, FP0:
     *   opword = F200 (CpID=1, type=000, EA=000000)
     *   command = 5C00 | (0<<7) | 0x00 = 0x5C00  */
    poke16(pc, 0xF200); pc += 2;
    poke16(pc, 0x5C00); pc += 2;

    /* FMOVE.L #1, FP1:
     *   opword = F23C (type=000, EA=111100 = immediate)
     *   command = 1_00_000_001_0000000 = 0x4080 (R/M=1, fmt=0=Long, dst=1, op=FMOVE=0x00)
     *   followed by 32-bit immediate: 0x00000001 */
    poke16(pc, 0xF23C); pc += 2;
    poke16(pc, 0x4080); pc += 2;
    poke32(pc, 0x00000001); pc += 4;

    /* FADD.X FP0, FP1:
     *   opword = F200 (type=000, EA=000000 — ignored for reg-to-reg)
     *   command = 0_0_000_001_0100010 = 0x00A2 (R/M=0, src=FP0, dst=FP1, op=FADD=0x22) */
    poke16(pc, 0xF200); pc += 2;
    poke16(pc, 0x00A2); pc += 2;

    /* TRAP #15 (halt) = 0x4E4F */
    poke16(pc, 0x4E4F); pc += 2;

    /* Set up vectors and run */
    emu_mem_set_vectors(0x00100000, 0x1000);
    /* Set trap #15 vector (vector 47 = 0xBC) to point to itself (infinite loop) */
    poke32(0xBC, pc);       /* trap vector -> next instruction (just stops) */
    poke16(pc, 0x4E72);    /* STOP #$2700 */
    poke16(pc + 2, 0x2700);

    fline_init();
    m68k_set_cpu_type(M68K_CPU_TYPE_68000);
    m68k_init();
    m68k_pulse_reset();
    m68k_execute(200);

    /* Expected: FP0 = pi, FP1 = pi + 1.0 */
    fp80_t pi = FP80(0x4000, 0xC90FDAA2, 0x2168C235);
    check("FMOVECR(pi)->FP0", 0, pi, 0, 0);

    /* pi + 1.0 (mpmath): 4000 8490FDAA 2168C235 ... actually:
     * pi = 3.14159265..., pi+1 = 4.14159265...
     * 4.14159... = 1.0353981... * 2^2 -> exp = 16383+2 = 0x4001
     * sig = 0x8490FDAA2168C235 (pi significand shifted right 1, plus 1.0 contribution)
     * Let's use tolerance instead of exact match */
    /* pi + 1.0: align 1.0 (exp 3FFF) to pi's exponent (4000) -> shift right 1,
     * then add: C90FDAA22168C235 + 4000000000000000 = 1_090FDAA22168C235,
     * normalize: >> 1, exp++ -> 4001 8487ED51 10B4611A (exact) */
    fp80_t pi_plus_1 = FP80(0x4001, 0x8487ED51, 0x10B4611A);
    check("FADD pi+1->FP1", 1, pi_plus_1, TOL_HI, TOL_LO);
}

/*
 * Test 2: FMOVE.S #3.7, FP2 then FMOVE.S #2.4, FP3 then FMUL.X FP2,FP3
 * Expected: FP3 = 3.7 * 2.4 = 8.88
 */
static void test_mul_from_single(void)
{
    unsigned int pc = 0x2000;

    /* FMOVE.S #3.7, FP2:
     *   opword = F23C (imm), command = R/M=1, fmt=1(single), dst=2, op=FMOVE(0x00)
     *   command = 1_00_001_010_0000000 = 0x4500
     *   3.7f = 0x406CCCCD */
    poke16(pc, 0xF23C); pc += 2;
    poke16(pc, 0x4500); pc += 2;
    poke32(pc, 0x406CCCCD); pc += 4;

    /* FMOVE.S #2.4, FP3:
     *   command = 1_00_001_011_0000000 = 0x4580
     *   2.4f = 0x4019999A */
    poke16(pc, 0xF23C); pc += 2;
    poke16(pc, 0x4580); pc += 2;
    poke32(pc, 0x4019999A); pc += 4;

    /* FMUL.X FP2, FP3:
     *   command = 0_0_010_011_0100011 = 0x09A3 (src=FP2, dst=FP3, op=FMUL=0x23) */
    poke16(pc, 0xF200); pc += 2;
    poke16(pc, 0x09A3); pc += 2;

    /* TRAP #15 */
    poke16(pc, 0x4E4F); pc += 2;
    poke32(0xBC, pc);
    poke16(pc, 0x4E72); poke16(pc + 2, 0x2700);

    emu_mem_set_vectors(0x00100000, 0x2000);
    fline_init();
    m68k_set_cpu_type(M68K_CPU_TYPE_68000);
    m68k_init();
    m68k_pulse_reset();
    m68k_execute(200);

    /* 3.7f * 2.4f — inputs are single-precision approximations, so the
     * exact extended-precision product differs from ideal 3.7*2.4.
     * 3.7f=0x406CCCCD (3.70000005), 2.4f=0x4019999A (2.40000010) */
    fp80_t expect = FP80(0x4002, 0x8E147B5E, 0xB8520000);
    check("FMUL 3.7*2.4->FP3", 3, expect, TOL_HI, TOL_LO);
}

/*
 * Test 3: FSIN of 1.0
 *   FMOVE.L #1, FP0
 *   FSIN.X  FP0, FP1    (FP1 = sin(FP0))
 */
static void test_fsin(void)
{
    unsigned int pc = 0x3000;

    /* FMOVE.L #1, FP0:
     *   opword=F23C, command=0x4000 (R/M=1,fmt=0=Long,dst=0,op=FMOVE)
     *   imm = 0x00000001 */
    poke16(pc, 0xF23C); pc += 2;
    poke16(pc, 0x4000); pc += 2;  /* R/M=1,fmt=0=Long,dst=0,op=FMOVE */
    poke32(pc, 0x00000001); pc += 4;

    /* FSIN.X FP0, FP1:
     *   command = 0_0_000_001_0001110 = 0x008E (src=FP0, dst=FP1, op=FSIN=0x0E) */
    poke16(pc, 0xF200); pc += 2;
    poke16(pc, 0x008E); pc += 2;

    /* TRAP #15 */
    poke16(pc, 0x4E4F); pc += 2;
    poke32(0xBC, pc);
    poke16(pc, 0x4E72); poke16(pc + 2, 0x2700);

    emu_mem_set_vectors(0x00100000, 0x3000);
    fline_init();
    m68k_set_cpu_type(M68K_CPU_TYPE_68000);
    m68k_init();
    m68k_pulse_reset();
    m68k_execute(200);

    /* sin(1.0) = 0x3FFE D76AA478 48677020 */
    fp80_t expect = FP80(0x3FFE, 0xD76AA478, 0x48677020);
    check("FSIN(1.0)->FP1", 1, expect, TRIG_HI, TRIG_LO);
}

/*
 * Test 4: FSQRT of 9.0
 *   FMOVE.L #9, FP4
 *   FSQRT.X FP4, FP5
 */
static void test_fsqrt(void)
{
    unsigned int pc = 0x4000;

    /* FMOVE.L #9, FP4 */
    poke16(pc, 0xF23C); pc += 2;
    poke16(pc, 0x4200); pc += 2;  /* R/M=1,fmt=0=Long,dst=4,op=FMOVE */
    poke32(pc, 0x00000009); pc += 4;

    /* FSQRT.X FP4, FP5:
     *   command = 0_0_100_101_0000100 = 0x1284 (src=FP4, dst=FP5, op=FSQRT=0x04) */
    poke16(pc, 0xF200); pc += 2;
    poke16(pc, 0x1284); pc += 2;

    /* TRAP #15 */
    poke16(pc, 0x4E4F); pc += 2;
    poke32(0xBC, pc);
    poke16(pc, 0x4E72); poke16(pc + 2, 0x2700);

    emu_mem_set_vectors(0x00100000, 0x4000);
    fline_init();
    m68k_set_cpu_type(M68K_CPU_TYPE_68000);
    m68k_init();
    m68k_pulse_reset();
    m68k_execute(200);

    /* sqrt(9) = 3.0 (exact) */
    check("FSQRT(9)->FP5", 5, FP80(0x4000, 0xC0000000, 0x00000000), 0, 0);
}

/* ------------------------------------------------------------------ */
/* Run all basic FPU tests                                             */
/* ------------------------------------------------------------------ */
int basic_fpu_run(void)
{
    pass_cnt = 0;
    fail_cnt = 0;

    xil_printf("\r\n--- Basic FPU integration test (Musashi + F-line) ---\r\n");

    if (fpu_probe() != FPU_OK) {
        xil_printf("FATAL: No FPU response at 0x%08lx\r\n",
                   (u32)MC68881_BASE);
        return 1;
    }

    emu_mem_init();

    test_fmovecr_and_add();

    emu_mem_init();
    test_mul_from_single();

    emu_mem_init();
    test_fsin();

    emu_mem_init();
    test_fsqrt();

    xil_printf("--- %d passed, %d failed ---\r\n", pass_cnt, fail_cnt);
    return fail_cnt;
}
