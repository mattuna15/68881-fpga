/*
 * cirtest.c -- CIR (Coprocessor Interface Register) diagnostic test.
 *
 * Tests the MC68882 CIR dialog protocol by directly writing to the
 * AXI register file via 68K memory-mapped I/O at $FFFA40.
 * Run from the Merlin2 monitor (not EmuTOS).
 *
 * IMPORTANT: CIR command word bits[6:0] use CORE_V1 opcode encoding
 * (the FPGA's internal IDs), NOT MC68881 native opcodes.  The
 * fline_handler translates MC68881 opcodes before writing to CIR.
 *
 * Register map (5-bit address * 4 = AXI byte offset):
 *   addr  4 (0x10): CIR OpWord     (overlaps OPB_L in peripheral mode)
 *   addr  5 (0x14): CIR Command    (overlaps OPB_H)
 *   addr  7 (0x1C): CIR Condition  (overlaps RES_L)
 *   addr  8 (0x20): CIR Operand    (overlaps RES_H)
 *   addr 12 (0x30): CIR Save       (format word during cpSAVE)
 *   addr 13 (0x34): CIR Response   (read) / Mode control (write)
 *   addr 28 (0x70): CIR Restore    (format word for cpRESTORE)
 */

#include "../merlin2-bsp/merlin2.h"

/* ---- CIR register offsets from $FFFA40 (MC68020 coprocessor layout) ---- */
#define CIR_BASE      0xFFFA40u
#define CIR_RESPONSE  0x00   /* Response (R) / Control+Mode (W) */
#define CIR_CONTROL   0x02
#define CIR_SAVE      0x04
#define CIR_RESTORE   0x06
#define CIR_OPWORD    0x08   /* Operation Word */
#define CIR_COMMAND   0x0A   /* Command */
#define CIR_CONDITION 0x0E
#define CIR_OPERAND   0x10   /* Operand (32-bit transfers) */

/* ---- CIR OpWord types (bits [8:6]) ---- */
#define OPWORD_CPGEN     0x0000

/* ---- CIR response primitives ---- */
/* AN-947 response primitives (MC68881 native) */
#define CIR_PRIM_BUSY    0x8900  /* Null CA=1 (come again) */
#define CIR_PRIM_NULL_ID 0x0802  /* idle (emu_memory.c NULL→ID transform) */

/* ---- Source format codes (bits [12:10] of command word) ---- */
#define FMT_LONG     0   /* 32-bit integer */
#define FMT_SINGLE   1   /* IEEE 754 single */
#define FMT_EXTENDED 2   /* 80-bit extended */
#define FMT_WORD     4   /* 16-bit integer */
#define FMT_DOUBLE   5   /* IEEE 754 double */
#define FMT_BYTE     6   /* 8-bit integer */

/* ---- MC68881 native opcode IDs (bits[6:0] of cpGEN command word) ---- */
#define FPOP_MOVE   0x00
#define FPOP_SQRT   0x04
#define FPOP_SIN    0x0E
#define FPOP_ABS    0x18
#define FPOP_NEG    0x1A
#define FPOP_DIV    0x20
#define FPOP_ADD    0x22
#define FPOP_MUL    0x23
#define FPOP_SUB    0x28

/* ---- Command word builders (Motorola R/M convention) ---- */
/* R/M=0: register source, R/M=1: EA/memory source */

/* Memory-to-register: R/M=1, dir=0 */
#define CMD_MEM2REG(fmt, dst, op) \
    (0x4000 | ((fmt) << 10) | ((dst) << 7) | (op))

/* Register-to-memory: R/M=1, dir=1 */
#define CMD_REG2MEM(fmt, src, op) \
    (0x6000 | ((fmt) << 10) | ((src) << 7) | (op))

/* Register-to-register: R/M=0 */
#define CMD_REG2REG(src, dst, op) \
    (((src) << 10) | ((dst) << 7) | (op))

/* ---- Bus access ---- */
static void wr16(int offset, unsigned short val)
{
    *(volatile unsigned short *)(CIR_BASE + offset) = val;
}

static unsigned short rd16(int offset)
{
    return *(volatile unsigned short *)(CIR_BASE + offset);
}

static void wr32(int offset, unsigned long val)
{
    *(volatile unsigned long *)(CIR_BASE + offset) = val;
}

static unsigned long rd32(int offset)
{
    return *(volatile unsigned long *)(CIR_BASE + offset);
}

/* ---- Merlin2 TRAP #15 print helpers ---- */
static void print(const char *s)
{
    register const char *a1 __asm__("a1") = s;
    register int d0 __asm__("d0") = 14;
    __asm__ volatile("trap #15" : : "d"(d0), "a"(a1) : "memory", "d1", "d2");
}

static void println(const char *s)
{
    register const char *a1 __asm__("a1") = s;
    register int d0 __asm__("d0") = 13;
    __asm__ volatile("trap #15" : : "d"(d0), "a"(a1) : "memory", "d1", "d2");
}

static void print_hex(unsigned long v)
{
    register long d1 __asm__("d1") = (long)v;
    register int d2 __asm__("d2") = 16;
    register int d0 __asm__("d0") = 15;
    __asm__ volatile("trap #15" : : "d"(d0), "d"(d1), "d"(d2) : "memory");
}


/* ---- Test counters ---- */
static int pass_cnt, fail_cnt;

static void test_pass(const char *name)
{
    print("  PASS: "); println(name);
    pass_cnt++;
}

static void test_fail(const char *name, unsigned long got, unsigned long expect)
{
    volatile unsigned long g = got, e = expect;
    print("  FAIL: "); print(name);
    print(" got=$"); print_hex(g);
    print(" expect=$"); print_hex(e); println("");
    fail_cnt++;
}

/* ---- CIR dialog helpers ---- */

/* Poll CIR_RESPONSE until non-BUSY. Returns response word. */
static unsigned short poll_resp(int max_polls)
{
    unsigned short resp;
    for (int i = 0; i < max_polls; i++) {
        resp = rd16(CIR_RESPONSE);
        if (resp != CIR_PRIM_BUSY)
            return resp;
    }
    return 0;  /* timeout = BUSY */
}

/* Start a CIR dialog: write command + opword, return first non-BUSY response */
static unsigned short cir_start(unsigned short cmd)
{
    wr16(CIR_RESPONSE, 1);
    wr16(CIR_COMMAND, cmd);
    wr16(CIR_OPWORD, OPWORD_CPGEN);
    return poll_resp(200);
}

/* Load a long integer into FPn via CIR FMOVE.L mem-to-reg */
static int cir_load_long(int dst_reg, unsigned long int_val)
{
    unsigned short resp = cir_start(CMD_MEM2REG(FMT_LONG, dst_reg, FPOP_MOVE));
    if ((resp & 0xFF00) != 0x9600) return -1;
    wr32(CIR_OPERAND, int_val);
    resp = poll_resp(200);
    return (resp == CIR_PRIM_NULL_ID) ? 0 : -2;
}

/* (cir_load_single and cir_load_double removed — use cir_op_long/cir_op_double) */

/* Read FPn as long integer via CIR FMOVE.L reg-to-mem */
static int cir_read_long(int src_reg, unsigned long *result)
{
    unsigned short resp = cir_start(CMD_REG2MEM(FMT_LONG, src_reg, FPOP_MOVE));
    if ((resp & 0xFF00) != 0xB200) return -1;
    *result = rd32(CIR_OPERAND);
    /* Poll until NULL to complete the dialog */
    resp = poll_resp(200);
    return (resp == CIR_PRIM_NULL_ID) ? 0 : -2;
}

/* Execute a mem-to-reg ALU operation with long operand */
static int cir_op_long(int dst_reg, int opcode, unsigned long int_val)
{
    unsigned short resp = cir_start(CMD_MEM2REG(FMT_LONG, dst_reg, opcode));
    if ((resp & 0xFF00) != 0x9600) return -1;
    wr32(CIR_OPERAND, int_val);
    resp = poll_resp(50000);  /* long timeout for trig/sqrt */
    return (resp == CIR_PRIM_NULL_ID) ? 0 : -2;
}

/* Execute a mem-to-reg ALU operation with double operand */
static int cir_op_double(int dst_reg, int opcode, unsigned long hi, unsigned long lo)
{
    unsigned short resp = cir_start(CMD_MEM2REG(FMT_DOUBLE, dst_reg, opcode));
    if ((resp & 0xFF00) != 0x9600) return -1;
    wr32(CIR_OPERAND, hi);
    wr32(CIR_OPERAND, lo);
    resp = poll_resp(50000);  /* long timeout for trig */
    return (resp == CIR_PRIM_NULL_ID) ? 0 : -2;
}

/* Execute a reg-to-reg operation */
static int cir_op_reg(int src_reg, int dst_reg, int opcode)
{
    unsigned short resp;
    wr16(CIR_RESPONSE, 1);
    wr16(CIR_COMMAND, CMD_REG2REG(src_reg, dst_reg, opcode));
    wr16(CIR_OPWORD, OPWORD_CPGEN);
    resp = poll_resp(50000);
    return (resp == CIR_PRIM_NULL_ID) ? 0 : -2;
}

/* ---- TESTS ---- */

static void test_fmove_long_roundtrip(void)
{
    unsigned long got;
    if (cir_load_long(0, 42) != 0) { test_fail("FMOVE.L load 42", 0, 42); return; }
    if (cir_read_long(0, &got) != 0) { test_fail("FMOVE.L readback", 0, 42); return; }
    if (got == 42)
        test_pass("FMOVE.L round-trip (42)");
    else
        test_fail("FMOVE.L round-trip", got, 42);
}

static void test_fmove_negative(void)
{
    unsigned long got;
    /* Load -7 into FP1, read back */
    if (cir_load_long(1, (unsigned long)-7) != 0) { test_fail("FMOVE.L load -7", 0, 0); return; }
    if (cir_read_long(1, &got) != 0) { test_fail("FMOVE.L readback -7", 0, 0); return; }
    if ((long)got == -7)
        test_pass("FMOVE.L round-trip (-7)");
    else
        test_fail("FMOVE.L round-trip -7", got, (unsigned long)-7);
}

static void test_fadd_mem(void)
{
    unsigned long got;
    /* FP0=42 (from previous test), FADD.L #8,FP0 → FP0=50 */
    if (cir_op_long(0, FPOP_ADD, 8) != 0) { test_fail("FADD.L timeout", 0, 0); return; }
    if (cir_read_long(0, &got) != 0) { test_fail("FADD.L readback", 0, 0); return; }
    if (got == 50)
        test_pass("FADD.L #8 (42+8=50)");
    else
        test_fail("FADD.L #8", got, 50);
}

static void test_fadd_reg(void)
{
    unsigned long got;
    /* FP0=50, FP1=-7. FADD FP1,FP0 → FP0=43 */
    if (cir_op_reg(1, 0, FPOP_ADD) != 0) { test_fail("FADD reg timeout", 0, 0); return; }
    if (cir_read_long(0, &got) != 0) { test_fail("FADD reg readback", 0, 0); return; }
    if (got == 43)
        test_pass("FADD FP1,FP0 (50+(-7)=43)");
    else
        test_fail("FADD FP1,FP0", got, 43);
}

static void test_fmul_mem(void)
{
    unsigned long got;
    /* Load FP2=6, FMUL.L #7,FP2 → FP2=42 */
    if (cir_load_long(2, 6) != 0) { test_fail("FMUL load", 0, 0); return; }
    if (cir_op_long(2, FPOP_MUL, 7) != 0) { test_fail("FMUL timeout", 0, 0); return; }
    if (cir_read_long(2, &got) != 0) { test_fail("FMUL readback", 0, 0); return; }
    if (got == 42)
        test_pass("FMUL.L #7 (6*7=42)");
    else
        test_fail("FMUL.L #7", got, 42);
}

static void test_fdiv_mem(void)
{
    unsigned long got;
    /* FP2=42, FDIV.L #6,FP2 → FP2=7 */
    if (cir_op_long(2, FPOP_DIV, 6) != 0) { test_fail("FDIV timeout", 0, 0); return; }
    if (cir_read_long(2, &got) != 0) { test_fail("FDIV readback", 0, 0); return; }
    if (got == 7)
        test_pass("FDIV.L #6 (42/6=7)");
    else
        test_fail("FDIV.L #6", got, 7);
}

static void test_fsqrt_mem(void)
{
    unsigned long got;
    /* FSQRT.L #9,FP3 → FP3=3 */
    if (cir_op_long(3, FPOP_SQRT, 9) != 0) { test_fail("FSQRT timeout", 0, 0); return; }
    if (cir_read_long(3, &got) != 0) { test_fail("FSQRT readback", 0, 0); return; }
    if (got == 3)
        test_pass("FSQRT.L #9 = 3");
    else
        test_fail("FSQRT.L #9", got, 3);
}

static void test_fneg_reg(void)
{
    unsigned long got;
    /* FP3=3, FNEG FP3,FP4 → FP4=-3 */
    if (cir_op_reg(3, 4, FPOP_NEG) != 0) { test_fail("FNEG timeout", 0, 0); return; }
    if (cir_read_long(4, &got) != 0) { test_fail("FNEG readback", 0, 0); return; }
    if ((long)got == -3)
        test_pass("FNEG FP3,FP4 = -3");
    else
        test_fail("FNEG FP3,FP4", got, (unsigned long)-3);
}

static void test_fabs_reg(void)
{
    unsigned long got;
    /* FP4=-3, FABS FP4,FP5 → FP5=3 */
    if (cir_op_reg(4, 5, FPOP_ABS) != 0) { test_fail("FABS timeout", 0, 0); return; }
    if (cir_read_long(5, &got) != 0) { test_fail("FABS readback", 0, 0); return; }
    if (got == 3)
        test_pass("FABS FP4,FP5 = 3");
    else
        test_fail("FABS FP4,FP5", got, 3);
}

static void test_fsub_mem(void)
{
    unsigned long got;
    /* FP0=50 (from FADD test), FSUB.L #13,FP0 → FP0=37 */
    if (cir_op_long(0, FPOP_SUB, 13) != 0) { test_fail("FSUB timeout", 0, 0); return; }
    if (cir_read_long(0, &got) != 0) { test_fail("FSUB readback", 0, 0); return; }
    if (got == 37)
        test_pass("FSUB.L #13 (50-13=37)");
    else
        test_fail("FSUB.L #13", got, 37);
}

static void test_fsin_double(void)
{
    unsigned long got;
    /* FSIN.D 1.0,FP6 → sin(1.0) ≈ 0.8414709848.
     * Readback as long → FINTRZ → 0 (since |sin(x)| < 1 for x=1).
     * Instead, multiply by 1000000 and read as long to check precision. */

    /* Load 1.0 as double into FP6 via FSIN */
    if (cir_op_double(6, FPOP_SIN, 0x3FF00000, 0x00000000) != 0) {
        test_fail("FSIN.D timeout", 0, 0);
        return;
    }

    /* FMUL.L #1000000,FP6 → ~841470 */
    if (cir_op_long(6, FPOP_MUL, 1000000) != 0) {
        test_fail("FSIN*1M timeout", 0, 0);
        return;
    }
    if (cir_read_long(6, &got) != 0) {
        test_fail("FSIN readback", 0, 0);
        return;
    }

    /* sin(1.0) * 1000000 ≈ 841471 = $CD97F, allow ±2 for rounding */
    if (got >= 841469 && got <= 841473) {
        test_pass("FSIN(1.0)*1M ~841471");
    } else {
        test_fail("FSIN(1.0)*1M", got, 841471);
    }
}

static void test_fsqrt_double(void)
{
    unsigned long got;
    /* FSQRT.D 2.0,FP7 → sqrt(2) ≈ 1.41421356
     * Multiply by 1000000 → ~1414213 */
    if (cir_op_double(7, FPOP_SQRT, 0x40000000, 0x00000000) != 0) {
        test_fail("FSQRT.D timeout", 0, 0);
        return;
    }
    if (cir_op_long(7, FPOP_MUL, 1000000) != 0) {
        test_fail("FSQRT*1M timeout", 0, 0);
        return;
    }
    if (cir_read_long(7, &got) != 0) {
        test_fail("FSQRT.D readback", 0, 0);
        return;
    }

    /* sqrt(2.0) * 1000000 ≈ 1414213 = $159545, allow ±2 for rounding */
    if (got >= 1414211 && got <= 1414215) {
        test_pass("FSQRT(2.0)*1M ~1414213");
    } else {
        test_fail("FSQRT(2.0)*1M", got, 1414213);
    }
}

/* ---- Main ---- */

int main(void)
{
    println("CIR Diagnostic Test");
    println("===================");
    pass_cnt = 0;
    fail_cnt = 0;

    println("\r\n-- Integer round-trips --");
    test_fmove_long_roundtrip();  /* FP0=42 */
    test_fmove_negative();        /* FP1=-7 */

    println("\r\n-- Arithmetic (mem-to-reg) --");
    test_fadd_mem();              /* FP0=50 (42+8) */
    test_fmul_mem();              /* FP2=42 (6*7) */
    test_fdiv_mem();              /* FP2=7  (42/6) */
    test_fsub_mem();              /* FP0=30 (43-13) — note FADD reg changes FP0 first */

    println("\r\n-- Arithmetic (reg-to-reg) --");
    /* Reload FP0=42 for the reg-to-reg add test */
    cir_load_long(0, 50);        /* FP0=50 */
    test_fadd_reg();              /* FP0=43 (50+(-7)) */

    println("\r\n-- Unary ops --");
    test_fsqrt_mem();             /* FP3=3  (sqrt(9)) */
    test_fneg_reg();              /* FP4=-3 (neg(3)) */
    test_fabs_reg();              /* FP5=3  (abs(-3)) */

    println("\r\n-- Transcendentals (double precision) --");
    test_fsin_double();           /* sin(1.0)*1M ≈ 841471 */
    test_fsqrt_double();          /* sqrt(2.0)*1M ≈ 1414213 */

    println("");
    {
        volatile unsigned long p = pass_cnt, f = fail_cnt;
        print("Results: "); print_hex(p); print(" passed, ");
        print_hex(f); println(" failed");
    }

    println("\r\nDone.");
    return 0;
}
