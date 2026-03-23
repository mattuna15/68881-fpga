/*
 * cirtest.c -- CIR (Coprocessor Interface Register) diagnostic test.
 *
 * Tests the MC68882 CIR dialog protocol by directly writing to the
 * AXI register file. Run from the Merlin2 monitor (not EmuTOS).
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

#define FPU_BASE  0x80000000u

/* Register offsets */
#define R_OPSEL     (0  * 4)
#define R_OPA_L     (1  * 4)
#define R_OPA_H     (2  * 4)
#define R_OPA_E     (3  * 4)
#define R_OPB_L     (4  * 4)  /* = CIR OpWord in CIR mode */
#define R_OPB_H     (5  * 4)  /* = CIR Command in CIR mode */
#define R_STATUS    (10 * 4)
#define R_FPCR      (11 * 4)
#define R_CIR_MODE  (13 * 4)  /* Write: 0=peripheral, 1=CIR. Read: response */
#define R_FPSR      (14 * 4)

/* CIR protocol offsets (same physical registers, CIR naming) */
#define CIR_OPWORD   (4  * 4)  /* 0x10 */
#define CIR_COMMAND  (5  * 4)  /* 0x14 */
#define CIR_CONDITION (7 * 4)  /* 0x1C */
#define CIR_OPERAND  (8  * 4)  /* 0x20 */
#define CIR_SAVE     (12 * 4)  /* 0x30 */
#define CIR_RESPONSE (13 * 4)  /* 0x34 */
#define CIR_RESTORE  (28 * 4)  /* 0x70 */

/* CIR OpWord types */
#define OPWORD_CPGEN     0x0000
#define OPWORD_CPSAVE    0x0100
#define OPWORD_CPRESTORE 0x0140

/* CIR response primitives */
#define CIR_PRIM_BUSY    0x0000
#define CIR_PRIM_NULL    0x2001

static volatile unsigned long *fpu = (volatile unsigned long *)FPU_BASE;

static void wr(int offset, unsigned long val)
{
    *(volatile unsigned long *)(FPU_BASE + offset) = val;
}

static unsigned long rd(int offset)
{
    return *(volatile unsigned long *)(FPU_BASE + offset);
}

/* Merlin2 TRAP #15 print helpers */
static void print(const char *s)
{
    register const char *a1 __asm__("a1") = s;
    register int d0 __asm__("d0") = 14;  /* PRINT_RAW */
    __asm__ volatile("trap #15" : : "d"(d0), "a"(a1) : "memory");
}

static void println(const char *s)
{
    register const char *a1 __asm__("a1") = s;
    register int d0 __asm__("d0") = 13;  /* PRINT_CRLF */
    __asm__ volatile("trap #15" : : "d"(d0), "a"(a1) : "memory");
}

static void print_hex32(unsigned long v)
{
    register long d1 __asm__("d1") = (long)v;
    register int d2 __asm__("d2") = 16;  /* base 16 */
    register int d0 __asm__("d0") = 15;  /* PRINT_BASE */
    __asm__ volatile("trap #15" : : "d"(d0), "d"(d1), "d"(d2) : "memory");
}

static void test_header(const char *name)
{
    print("\r\n--- ");
    print(name);
    println(" ---");
}

int main(void)
{
    println("CIR Diagnostic Test");
    println("===================");

    /* ---- Test 1: Read status in current mode ---- */
    test_header("Test 1: Read current state");
    print("STATUS  = "); print_hex32(rd(R_STATUS));  println("");
    print("CIR_RSP = "); print_hex32(rd(CIR_RESPONSE)); println("");
    print("FPCR    = "); print_hex32(rd(R_FPCR));   println("");
    print("FPSR    = "); print_hex32(rd(R_FPSR));    println("");

    /* ---- Test 2: Switch to peripheral mode, verify ---- */
    test_header("Test 2: Peripheral mode");
    wr(CIR_RESPONSE, 0);  /* peripheral mode */
    print("After mode=0: CIR_RSP = "); print_hex32(rd(CIR_RESPONSE)); println("");
    print("STATUS = "); print_hex32(rd(R_STATUS)); println("");

    /* ---- Test 3: Switch to CIR mode, verify ---- */
    test_header("Test 3: CIR mode");
    wr(CIR_RESPONSE, 1);  /* CIR mode */
    print("After mode=1: CIR_RSP = "); print_hex32(rd(CIR_RESPONSE)); println("");

    /* ---- Test 4: Write Command only, check response ---- */
    test_header("Test 4: Command only");
    wr(CIR_RESPONSE, 1);
    /* FMOVE.L #0, FP0 = reg-to-reg FMOVE with src=FP0 dst=FP0 */
    wr(CIR_COMMAND, 0x0000);  /* R/M=0, FMOVE FP0→FP0 */
    print("After cmd: CIR_RSP = "); print_hex32(rd(CIR_RESPONSE)); println("");

    /* ---- Test 5: Write OpWord only, check response ---- */
    test_header("Test 5: OpWord only (reset first)");
    wr(CIR_RESPONSE, 0);  /* back to peripheral to reset */
    wr(CIR_RESPONSE, 1);  /* CIR mode */
    wr(CIR_OPWORD, OPWORD_CPGEN);
    print("After opword: CIR_RSP = "); print_hex32(rd(CIR_RESPONSE)); println("");

    /* ---- Test 6: Command + OpWord (cpGEN reg-to-reg) ---- */
    test_header("Test 6: cpGEN FMOVE FP0,FP0");
    wr(CIR_RESPONSE, 0);  /* reset */
    wr(CIR_RESPONSE, 1);  /* CIR mode */
    /* Command: FMOVE FP0→FP0 (R/M=1, src=0, dst=0, op=0) */
    wr(CIR_COMMAND, 0x4000);  /* R/M=1 (reg-to-reg), src=FP0, dst=FP0, FMOVE */
    print("After cmd $4000: CIR_RSP = "); print_hex32(rd(CIR_RESPONSE)); println("");
    wr(CIR_OPWORD, OPWORD_CPGEN);
    print("After opword $0000: CIR_RSP = "); print_hex32(rd(CIR_RESPONSE)); println("");
    /* Poll for completion */
    int i;
    for (i = 0; i < 1000; i++) {
        unsigned long r = rd(CIR_RESPONSE);
        if ((r & 0xFFFF) != CIR_PRIM_BUSY) {
            print("Response after "); print_hex32(i);
            print(" polls: "); print_hex32(r); println("");
            break;
        }
    }
    if (i == 1000) println("TIMEOUT: still BUSY after 1000 polls");

    /* ---- Test 7: cpGEN mem-to-reg (FSIN.D) like FPU_HARD.PRG ---- */
    test_header("Test 7: cpGEN FSIN.D <ea>,FP0");
    wr(CIR_RESPONSE, 0);
    wr(CIR_RESPONSE, 1);
    /* $540E = R/M=0 (mem-to-reg), src_spec=101 (double), dst=FP0, op=$0E (FSIN) */
    wr(CIR_COMMAND, 0x540E);
    print("After cmd $540E: CIR_RSP = "); print_hex32(rd(CIR_RESPONSE)); println("");
    wr(CIR_OPWORD, OPWORD_CPGEN);
    print("After opword: CIR_RSP = "); print_hex32(rd(CIR_RESPONSE)); println("");
    /* Poll */
    for (i = 0; i < 1000; i++) {
        unsigned long r = rd(CIR_RESPONSE);
        if ((r & 0xFFFF) != CIR_PRIM_BUSY && (r & 0xFFFF) != CIR_PRIM_NULL) {
            print("Response after "); print_hex32(i);
            print(" polls: "); print_hex32(r); println("");
            break;
        }
    }
    if (i == 1000) {
        print("Final CIR_RSP = "); print_hex32(rd(CIR_RESPONSE)); println("");
        println("No response change after 1000 polls");
    }

    /* ---- Test 8: Read all CIR registers ---- */
    test_header("Test 8: Register dump");
    print("OpWord   (0x10) = "); print_hex32(rd(CIR_OPWORD));    println("");
    print("Command  (0x14) = "); print_hex32(rd(CIR_COMMAND));   println("");
    print("Condition(0x1C) = "); print_hex32(rd(CIR_CONDITION)); println("");
    print("Operand  (0x20) = "); print_hex32(rd(CIR_OPERAND));   println("");
    print("Save     (0x30) = "); print_hex32(rd(CIR_SAVE));      println("");
    print("Response (0x34) = "); print_hex32(rd(CIR_RESPONSE));  println("");

    println("\r\nDone.");
    return 0;
}
