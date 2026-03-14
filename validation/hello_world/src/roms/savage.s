*------------------------------------------------------------------------
* Savage Benchmark for MC68881 FPU
*
* The Savage benchmark repeatedly applies the identity function:
*   x = tan(atan(exp(ln(sqrt(x*x)))))
* starting with x=1.0, for 2500 iterations.
*
* If the FPU is perfectly accurate, the result is exactly 1.0.
* Any accumulated rounding error shows as deviation from 1.0.
*
* Exercises: FMUL, FSQRT, FLOGN, FETOX, FATAN, FTAN
*
* Usage: Load via S-record (L command), execute with G 2000.
* Output: Result as extended hex (expect 3FFF 80000000 00000000 = 1.0)
*
* Assemble: vasmm68k_mot -Fbin -m68000 -m68881 -o savage.bin savage.s
*------------------------------------------------------------------------

ITERATIONS  EQU  2500

         ORG     $2000

*------------------------------------------------------------------------
* Entry point
*------------------------------------------------------------------------
START    LEA     msgTitle,A1
         MOVEQ   #13,D0
         TRAP    #15             Print title with CR+LF

* FP0 = 1.0
         FMOVE.L #1,FP0

* Main loop
         MOVE.L  #ITERATIONS,D7

LOOP     FMUL.X  FP0,FP0         x = x*x
         FSQRT.X FP0,FP0         x = sqrt(x)
         FLOGN.X FP0,FP0         x = ln(x)
         FETOX.X FP0,FP0         x = exp(x)
         FATAN.X FP0,FP0         x = atan(x)
         FTAN.X  FP0,FP0         x = tan(x)

         SUBQ.L  #1,D7
         BNE.S   LOOP

*------------------------------------------------------------------------
* Print result
*------------------------------------------------------------------------
         LEA     msgResult,A1
         MOVEQ   #14,D0
         TRAP    #15             Print "Result: " (no CR)

* Store FP0 to memory, print as 3 hex longwords
         LEA     FPTEMP,A0
         FMOVE.X FP0,(A0)

         MOVE.L  FPTEMP,D0
         BSR     PRTHEX32        Sign + exponent
         MOVE.B  #' ',D1
         MOVEQ   #6,D0
         TRAP    #15
         MOVE.L  FPTEMP+4,D0
         BSR     PRTHEX32        Mantissa high
         MOVE.B  #' ',D1
         MOVEQ   #6,D0
         TRAP    #15
         MOVE.L  FPTEMP+8,D0
         BSR     PRTHEX32        Mantissa low

* Newline
         LEA     msgNewline,A1
         MOVEQ   #13,D0
         TRAP    #15

* Print expected value
         LEA     msgExpect,A1
         MOVEQ   #13,D0
         TRAP    #15

* Print iteration count
         LEA     msgIters,A1
         MOVEQ   #14,D0
         TRAP    #15
         MOVE.L  #ITERATIONS,D1
         MOVEQ   #10,D2          Base 10
         MOVEQ   #15,D0
         TRAP    #15
         LEA     msgNewline,A1
         MOVEQ   #13,D0
         TRAP    #15

* Done
         LEA     msgDone,A1
         MOVEQ   #13,D0
         TRAP    #15

         RTS                     Return to monitor

*------------------------------------------------------------------------
* PRTHEX32 — print D0.L as 8 hex digits
*------------------------------------------------------------------------
PRTHEX32 MOVEM.L D2-D3,-(SP)
         MOVE.L  D0,D3
         MOVEQ   #7,D2
.lp      ROL.L   #4,D3
         MOVE.L  D3,D0
         ANDI.B  #$0F,D0
         ADD.B   #'0',D0
         CMP.B   #'9',D0
         BLE.S   .ok
         ADDQ.B  #7,D0
.ok      MOVE.B  D0,D1
         MOVEQ   #6,D0
         TRAP    #15             Print char in D1.B
         DBRA    D2,.lp
         MOVEM.L (SP)+,D2-D3
         RTS

*------------------------------------------------------------------------
* Data
*------------------------------------------------------------------------
         EVEN
FPTEMP   DS.B    12              Temp for FP extended (96 bits)

msgTitle   DC.B  '=== Savage Benchmark ===',0
msgResult  DC.B  'Result: ',0
msgExpect  DC.B  'Expect: 3FFF0000 80000000 00000000  (1.0)',0
msgIters   DC.B  'Iterations: ',0
msgDone    DC.B  'Done.',0
msgNewline DC.B  0

         EVEN
         END     START
