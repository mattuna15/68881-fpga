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

/* FPU CIR registers mapped at Atari TT address $FFFA40 in 68K space.
 * These are WORD registers (MC68020 coprocessor interface layout).
 * The emu_memory.c handler routes them to AXI CIR registers. */
#define CIR_BASE      0xFFFA40u

/* Offsets from CIR_BASE (word-sized registers) */
#define CIR_RESPONSE  0x00   /* $FFFA40: Response (R) / Control+Mode (W) */
#define CIR_CONTROL   0x02   /* $FFFA42: Control */
#define CIR_SAVE      0x04   /* $FFFA44: Save */
#define CIR_RESTORE   0x06   /* $FFFA46: Restore */
#define CIR_OPWORD    0x08   /* $FFFA48: Operation Word */
#define CIR_COMMAND   0x0A   /* $FFFA4A: Command */
#define CIR_CONDITION 0x0E   /* $FFFA4E: Condition */
#define CIR_OPERAND   0x10   /* $FFFA50: Operand */

/* CIR OpWord types */
#define OPWORD_CPGEN     0x0000
#define OPWORD_CPSAVE    0x0100
#define OPWORD_CPRESTORE 0x0140

/* CIR response primitives */
#define CIR_PRIM_BUSY    0x0000
#define CIR_PRIM_NULL    0x2001

/* Word (16-bit) read/write — matches the 68K coprocessor interface */
static void wr16(int offset, unsigned short val)
{
    *(volatile unsigned short *)(CIR_BASE + offset) = val;
}

static unsigned short rd16(int offset)
{
    return *(volatile unsigned short *)(CIR_BASE + offset);
}

/* Long (32-bit) read/write for operand data transfers */
static void wr32(int offset, unsigned long val)
{
    *(volatile unsigned long *)(CIR_BASE + offset) = val;
}

static unsigned long rd32(int offset)
{
    return *(volatile unsigned long *)(CIR_BASE + offset);
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

    /* ---- Test 1: Read response in current state ---- */
    test_header("Test 1: Read current state");
    print("CIR_RSP = "); print_hex32(rd16(CIR_RESPONSE)); println("");

    /* ---- Test 2: Switch to peripheral mode ---- */
    test_header("Test 2: Peripheral mode");
    wr16(CIR_RESPONSE, 0);
    print("After mode=0: CIR_RSP = "); print_hex32(rd16(CIR_RESPONSE)); println("");

    /* ---- Test 3: Switch to CIR mode ---- */
    test_header("Test 3: CIR mode");
    wr16(CIR_RESPONSE, 1);
    print("After mode=1: CIR_RSP = "); print_hex32(rd16(CIR_RESPONSE)); println("");

    /* ---- Test 4: Command only ---- */
    test_header("Test 4: Command only");
    wr16(CIR_RESPONSE, 1);
    wr16(CIR_COMMAND, 0x0000);
    print("After cmd $0000: CIR_RSP = "); print_hex32(rd16(CIR_RESPONSE)); println("");

    /* ---- Test 5: OpWord only (reset first) ---- */
    test_header("Test 5: OpWord only");
    wr16(CIR_RESPONSE, 0);
    wr16(CIR_RESPONSE, 1);
    wr16(CIR_OPWORD, OPWORD_CPGEN);
    print("After opword $0000: CIR_RSP = "); print_hex32(rd16(CIR_RESPONSE)); println("");

    /* ---- Test 6: Command + OpWord (cpGEN reg-to-reg FMOVE FP0,FP0) ---- */
    test_header("Test 6: cpGEN FMOVE FP0,FP0");
    wr16(CIR_RESPONSE, 0);
    wr16(CIR_RESPONSE, 1);
    wr16(CIR_COMMAND, 0x4000);
    print("After cmd $4000: CIR_RSP = "); print_hex32(rd16(CIR_RESPONSE)); println("");
    wr16(CIR_OPWORD, OPWORD_CPGEN);
    print("After opword: CIR_RSP = "); print_hex32(rd16(CIR_RESPONSE)); println("");
    /* Poll for non-BUSY */
    int i;
    for (i = 0; i < 1000; i++) {
        unsigned short r = rd16(CIR_RESPONSE);
        if (r != CIR_PRIM_BUSY) {
            print("Poll "); print_hex32(i);
            print(": resp=$"); print_hex32(r); println("");
            break;
        }
    }
    if (i == 1000) println("TIMEOUT: still BUSY after 1000 polls");

    /* ---- Test 7: cpGEN FSIN.D (mem-to-reg, like FPU_HARD.PRG) ---- */
    test_header("Test 7: cpGEN FSIN.D <ea>,FP0");
    wr16(CIR_RESPONSE, 0);
    wr16(CIR_RESPONSE, 1);
    wr16(CIR_COMMAND, 0x540E);
    print("After cmd $540E: CIR_RSP = "); print_hex32(rd16(CIR_RESPONSE)); println("");
    wr16(CIR_OPWORD, OPWORD_CPGEN);
    print("After opword: CIR_RSP = "); print_hex32(rd16(CIR_RESPONSE)); println("");
    /* Poll for transfer request or completion */
    for (i = 0; i < 1000; i++) {
        unsigned short r = rd16(CIR_RESPONSE);
        if (r != CIR_PRIM_BUSY && r != CIR_PRIM_NULL) {
            print("Poll "); print_hex32(i);
            print(": resp=$"); print_hex32(r); println("");
            break;
        }
    }
    if (i == 1000) {
        print("Final CIR_RSP = "); print_hex32(rd16(CIR_RESPONSE)); println("");
        println("No change after 1000 polls");
    }

    /* ---- Test 8: Register dump ---- */
    test_header("Test 8: Register dump");
    print("Response ($FFFA40) = "); print_hex32(rd16(CIR_RESPONSE)); println("");
    print("Save     ($FFFA44) = "); print_hex32(rd16(CIR_SAVE));     println("");
    print("OpWord   ($FFFA48) = "); print_hex32(rd16(CIR_OPWORD));   println("");
    print("Command  ($FFFA4A) = "); print_hex32(rd16(CIR_COMMAND));  println("");
    print("Condition($FFFA4E) = "); print_hex32(rd16(CIR_CONDITION));println("");
    print("Operand  ($FFFA50) = "); print_hex32(rd16(CIR_OPERAND)); println("");

    println("\r\nDone.");
    return 0;
}
