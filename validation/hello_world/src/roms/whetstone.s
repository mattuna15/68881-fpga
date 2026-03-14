*------------------------------------------------------------------------
* Whetstone Benchmark for MC68881 FPU
*
* Classic floating-point benchmark (1972, H.J. Curnow & B.A. Wichmann).
* Exercises ADD, SUB, MUL, DIV, SQRT, SIN, COS, ATAN, LOG, EXP
* across 8 standard modules with weighted iteration counts.
*
* One pass = 1000 Whetstone instructions (by design).
* KWIPS = NLOOP * 1000 / elapsed_ms
*
* Usage: Load via S-record (L command), execute with G 2000.
*        KWIPS auto-calculated via MFP ms tick counter (TRAP #15 D0=8).
*
* Assemble: vasmm68k_mot -Fsrec -m68000 -m68881 -o whetstone.srec whetstone.s
*------------------------------------------------------------------------

* Iteration counts per pass (standard Whetstone weights)
N1      EQU     0               Module 1: simple identifiers (often skipped)
N2      EQU     12              Module 2: array elements
N3      EQU     14              Module 3: array as parameter
N4      EQU     345             Module 4: conditional jumps
N6      EQU     210             Module 6: standard functions (log/exp/sqrt)
N7      EQU     32              Module 7: procedure calls
N8      EQU     899             Module 8: trig functions

NLOOP   EQU     10              Number of passes

        ORG     $2000

*------------------------------------------------------------------------
* Entry
*------------------------------------------------------------------------
START   LEA     msgTitle,A1
        MOVEQ   #13,D0
        TRAP    #15

* Initialise constants
        FMOVE.D #0.499975,FP4            T
        FMOVE.D #0.50025,FP5            T1
        FMOVE.L #2,FP6                  T2

* Initialise variables
        FMOVE.L #1,FP0
        FMOVE.X FP0,X1
        FMOVE.L #-1,FP0
        FMOVE.X FP0,X2
        FMOVE.X FP0,X3
        FMOVE.X FP0,X4

* Initialise E1 array
        FMOVE.L #1,FP0
        FMOVE.X FP0,E1
        FMOVE.L #-1,FP0
        FMOVE.X FP0,E1+12
        FMOVE.X FP0,E1+24
        FMOVE.X FP0,E1+36

* J=1, K=2, L=3
        MOVE.L  #1,VJ
        MOVE.L  #2,VK
        MOVE.L  #3,VL

* Record start time (ms tick counter in D1)
        MOVEQ   #8,D0
        TRAP    #15
        MOVE.L  D1,TSTART

*------------------------------------------------------------------------
* Module 2: Array elements — N2*NLOOP iterations
* E1[0] = (E1[0] + E1[1] + E1[2] - E1[3]) * T
* E1[1] = (E1[0] + E1[1] - E1[2] + E1[3]) * T
* E1[2] = (E1[0] - E1[1] + E1[2] + E1[3]) * T
* E1[3] = (-E1[0] + E1[1] + E1[2] + E1[3]) * T
*------------------------------------------------------------------------
        LEA     msgM2,A1
        MOVEQ   #14,D0
        TRAP    #15

        MOVE.L  #N2*NLOOP,D7
        BEQ     M2DONE
M2LOOP  FMOVE.X E1,FP0             E1[0]
        FADD.X  E1+12,FP0          + E1[1]
        FADD.X  E1+24,FP0          + E1[2]
        FSUB.X  E1+36,FP0          - E1[3]
        FMUL.X  FP4,FP0            * T
        FMOVE.X FP0,E1             -> E1[0]

        FMOVE.X E1,FP0             E1[0] (updated)
        FADD.X  E1+12,FP0          + E1[1]
        FSUB.X  E1+24,FP0          - E1[2]
        FADD.X  E1+36,FP0          + E1[3]
        FMUL.X  FP4,FP0            * T
        FMOVE.X FP0,E1+12          -> E1[1]

        FMOVE.X E1,FP0             E1[0]
        FSUB.X  E1+12,FP0          - E1[1]
        FADD.X  E1+24,FP0          + E1[2]
        FADD.X  E1+36,FP0          + E1[3]
        FMUL.X  FP4,FP0            * T
        FMOVE.X FP0,E1+24          -> E1[2]

        FNEG.X  E1,FP0             -E1[0]
        FADD.X  E1+12,FP0          + E1[1]
        FADD.X  E1+24,FP0          + E1[2]
        FADD.X  E1+36,FP0          + E1[3]
        FMUL.X  FP4,FP0            * T
        FMOVE.X FP0,E1+36          -> E1[3]

        SUBQ.L  #1,D7
        BNE     M2LOOP
M2DONE  LEA     msgOK,A1
        MOVEQ   #13,D0
        TRAP    #15

*------------------------------------------------------------------------
* Module 3: Array as parameter — N3*NLOOP iterations
* Same computation as module 2 but via BSR (procedure call overhead)
*------------------------------------------------------------------------
        LEA     msgM3,A1
        MOVEQ   #14,D0
        TRAP    #15

        MOVE.L  #N3*NLOOP,D7
        BEQ     M3DONE
M3LOOP  LEA     E1,A0
        BSR     PA                  Call procedure with array
        SUBQ.L  #1,D7
        BNE     M3LOOP
M3DONE  LEA     msgOK,A1
        MOVEQ   #13,D0
        TRAP    #15

*------------------------------------------------------------------------
* Module 4: Conditional jumps — N4*NLOOP iterations
* Tests FCMP and integer branching
*------------------------------------------------------------------------
        LEA     msgM4,A1
        MOVEQ   #14,D0
        TRAP    #15

        MOVE.L  #N4*NLOOP,D7
        BEQ     M4DONE
M4LOOP  MOVE.L  VJ,D0
        CMPI.L  #1,D0
        BNE.S   .m4a
        MOVE.L  #2,VJ
        BRA.S   .m4b
.m4a    MOVE.L  #3,VJ
.m4b    MOVE.L  VJ,D0
        CMPI.L  #2,D0
        BLE.S   .m4c
        MOVE.L  #0,VJ
        BRA.S   .m4d
.m4c    MOVE.L  #1,VJ
.m4d    MOVE.L  VJ,D0
        CMPI.L  #1,D0
        BGE.S   .m4e
        MOVE.L  #1,VJ
        BRA.S   .m4f
.m4e    MOVE.L  #0,VJ
.m4f    SUBQ.L  #1,D7
        BNE     M4LOOP
M4DONE  LEA     msgOK,A1
        MOVEQ   #13,D0
        TRAP    #15

*------------------------------------------------------------------------
* Module 6: Standard functions — N6*NLOOP iterations
* Y = SQRT(EXP(LOG(X) / T1))
* Exercises LOG, DIV, EXP, SQRT
*------------------------------------------------------------------------
        LEA     msgM6,A1
        MOVEQ   #14,D0
        TRAP    #15

* X=1.0, Y=1.0 for module 6
        FMOVE.L #1,FP0
        FMOVE.X FP0,VX
        FMOVE.X FP0,VY

        MOVE.L  #N6*NLOOP,D7
        BEQ     M6DONE
M6LOOP  FMOVE.X VX,FP0             X
        FLOGN.X FP0,FP0            log(X)
        FDIV.X  FP5,FP0            log(X) / T1
        FETOX.X FP0,FP0            exp(log(X) / T1)
        FSQRT.X FP0,FP0            sqrt(...)
        FMOVE.X FP0,VY             -> Y
        SUBQ.L  #1,D7
        BNE     M6LOOP
M6DONE  LEA     msgOK,A1
        MOVEQ   #13,D0
        TRAP    #15

*------------------------------------------------------------------------
* Module 7: Procedure calls — N7*NLOOP iterations
* X = T * (Z + X);  Y = T * (X + Y)
* via procedure P3(X,Y,Z)
*------------------------------------------------------------------------
        LEA     msgM7,A1
        MOVEQ   #14,D0
        TRAP    #15

* X=1.0, Y=1.0 for module 7
        FMOVE.L #1,FP0
        FMOVE.X FP0,VX
        FMOVE.X FP0,VY

        MOVE.L  #N7*NLOOP,D7
        BEQ     M7DONE
M7LOOP  FMOVE.X VX,FP0             X
        FMOVE.X VY,FP1             Y
        FMOVE.X FP4,FP2            Z = T
        BSR     P3
        FMOVE.X FP0,VX             store X
        FMOVE.X FP1,VY             store Y
        SUBQ.L  #1,D7
        BNE     M7LOOP
M7DONE  LEA     msgOK,A1
        MOVEQ   #13,D0
        TRAP    #15

*------------------------------------------------------------------------
* Module 8: Trig functions — N8*NLOOP iterations
* X = T*ATAN(T2*SIN(X)*COS(X)/(COS(X+Y)+COS(X-Y)-1.0))
* Y = T*ATAN(T2*SIN(Y)*COS(Y)/(COS(X+Y)+COS(X-Y)-1.0))
* Exercises SIN, COS, ATAN, ADD, SUB, MUL, DIV
*------------------------------------------------------------------------
        LEA     msgM8,A1
        MOVEQ   #14,D0
        TRAP    #15

* X=1.0, Y=1.0 for module 8
        FMOVE.L #1,FP0
        FMOVE.X FP0,VX
        FMOVE.X FP0,VY

        MOVE.L  #N8*NLOOP,D7
        BEQ     M8DONE

M8LOOP  FMOVE.X VX,FP0             X
        FMOVE.X VY,FP1             Y

* Compute common denominator: cos(X+Y) + cos(X-Y) - 1.0
        FMOVE.X FP0,FP2
        FADD.X  FP1,FP2            FP2 = X+Y
        FCOS.X  FP2,FP2            FP2 = cos(X+Y)
        FMOVE.X FP0,FP3
        FSUB.X  FP1,FP3            FP3 = X-Y
        FCOS.X  FP3,FP3            FP3 = cos(X-Y)
        FADD.X  FP3,FP2            FP2 = cos(X+Y) + cos(X-Y)
        FMOVE.L #1,FP3
        FSUB.X  FP3,FP2            FP2 = cos(X+Y) + cos(X-Y) - 1.0
* FP2 = denominator (keep for Y computation)

* X = T * atan(T2 * sin(X) * cos(X) / denom)
        FSIN.X  FP0,FP3            FP3 = sin(X)
        FCOS.X  FP0,FP0            FP0 = cos(X)
        FMUL.X  FP3,FP0            FP0 = sin(X)*cos(X)
        FMUL.X  FP6,FP0            FP0 = T2*sin(X)*cos(X)
        FDIV.X  FP2,FP0            FP0 = .../denom
        FATAN.X FP0,FP0            FP0 = atan(...)
        FMUL.X  FP4,FP0            FP0 = T*atan(...)
        FMOVE.X FP0,VX             store new X

* Y = T * atan(T2 * sin(Y) * cos(Y) / denom)
        FSIN.X  FP1,FP3            FP3 = sin(Y)
        FCOS.X  FP1,FP1            FP1 = cos(Y)
        FMUL.X  FP3,FP1            FP1 = sin(Y)*cos(Y)
        FMUL.X  FP6,FP1            FP1 = T2*sin(Y)*cos(Y)
        FDIV.X  FP2,FP1            FP1 = .../denom
        FATAN.X FP1,FP1            FP1 = atan(...)
        FMUL.X  FP4,FP1            FP1 = T*atan(...)
        FMOVE.X FP1,VY             store new Y

        SUBQ.L  #1,D7
        BNE     M8LOOP
M8DONE  LEA     msgOK,A1
        MOVEQ   #13,D0
        TRAP    #15

*------------------------------------------------------------------------
* Results
*------------------------------------------------------------------------
* Record end time
        MOVEQ   #8,D0
        TRAP    #15
        MOVE.L  D1,TEND

        LEA     msgNewline,A1
        MOVEQ   #13,D0
        TRAP    #15

        LEA     msgLoops,A1
        MOVEQ   #14,D0
        TRAP    #15
        MOVE.L  #NLOOP,D1
        MOVEQ   #10,D2
        MOVEQ   #15,D0
        TRAP    #15
        LEA     msgNewline,A1
        MOVEQ   #13,D0
        TRAP    #15

* Print elapsed time in ms
        LEA     msgElapsed,A1
        MOVEQ   #14,D0
        TRAP    #15
        MOVE.L  TEND,D1
        SUB.L   TSTART,D1
        MOVE.L  D1,TELAPSED         Save for KWIPS calc
        MOVEQ   #10,D2
        MOVEQ   #15,D0
        TRAP    #15
        LEA     msgMs,A1
        MOVEQ   #13,D0
        TRAP    #15

* KWIPS = NLOOP * 1000 / elapsed_seconds = NLOOP * 1000000 / elapsed_ms
        LEA     msgKWIPS,A1
        MOVEQ   #14,D0
        TRAP    #15

        MOVE.L  TELAPSED,D1
        BEQ.S   .notime             Avoid divide by zero
        SWAP    D1
        TST.W   D1                  Check if elapsed > 65535 ms
        BNE.S   .notime             Too long for 16-bit DIVU
        SWAP    D1                  Restore D1 = elapsed_ms (low word)
        MOVE.L  #NLOOP*1000000,D0   Numerator
        DIVU.W  D1,D0               D0.W = KWIPS
        BVS.S   .notime             Quotient overflow
        AND.L   #$FFFF,D0           Clear remainder in upper word
        MOVE.L  D0,D1
        MOVEQ   #10,D2
        MOVEQ   #15,D0
        TRAP    #15
        LEA     msgNewline,A1
        MOVEQ   #13,D0
        TRAP    #15
        BRA.S   .done

.notime LEA     msgNoTime,A1
        MOVEQ   #13,D0
        TRAP    #15

.done   LEA     msgDone,A1
        MOVEQ   #13,D0
        TRAP    #15

        RTS

*------------------------------------------------------------------------
* PA — Procedure for module 3 (array operations)
* Entry: A0 → E1 array (4 extended values, 12 bytes each)
* Uses: FP0-FP3
*------------------------------------------------------------------------
PA      FMOVE.X (A0),FP0           E1[0]
        FADD.X  12(A0),FP0         + E1[1]
        FADD.X  24(A0),FP0         + E1[2]
        FSUB.X  36(A0),FP0         - E1[3]
        FMUL.X  FP4,FP0            * T
        FMOVE.X FP0,(A0)           -> E1[0]

        FMOVE.X (A0),FP0           E1[0]
        FADD.X  12(A0),FP0         + E1[1]
        FSUB.X  24(A0),FP0         - E1[2]
        FADD.X  36(A0),FP0         + E1[3]
        FMUL.X  FP4,FP0            * T
        FMOVE.X FP0,12(A0)         -> E1[1]

        FMOVE.X (A0),FP0           E1[0]
        FSUB.X  12(A0),FP0         - E1[1]
        FADD.X  24(A0),FP0         + E1[2]
        FADD.X  36(A0),FP0         + E1[3]
        FMUL.X  FP4,FP0            * T
        FMOVE.X FP0,24(A0)         -> E1[2]

        FNEG.X  (A0),FP0           -E1[0]
        FADD.X  12(A0),FP0         + E1[1]
        FADD.X  24(A0),FP0         + E1[2]
        FADD.X  36(A0),FP0         + E1[3]
        FMUL.X  FP4,FP0            * T
        FMOVE.X FP0,36(A0)         -> E1[3]
        RTS

*------------------------------------------------------------------------
* P3 — Procedure for module 7
* Entry: FP0=X, FP1=Y, FP2=Z
* Return: FP0=new X, FP1=new Y
* X = T * (Z + X);  Y = T * (X + Y)
*------------------------------------------------------------------------
P3      FADD.X  FP2,FP0            X = Z + X
        FMUL.X  FP4,FP0            X = T * (Z + X)
        FADD.X  FP0,FP1            Y = X + Y
        FMUL.X  FP4,FP1            Y = T * (X + Y)
        RTS

*------------------------------------------------------------------------
* PRTHEX32 — print D0.L as 8 hex digits
*------------------------------------------------------------------------
PRTHEX32 MOVEM.L D2-D3,-(SP)
        MOVE.L  D0,D3
        MOVEQ   #7,D2
.lp     ROL.L   #4,D3
        MOVE.L  D3,D0
        ANDI.B  #$0F,D0
        ADD.B   #'0',D0
        CMP.B   #'9',D0
        BLE.S   .ok
        ADDQ.B  #7,D0
.ok     MOVE.B  D0,D1
        MOVEQ   #6,D0
        TRAP    #15
        DBRA    D2,.lp
        MOVEM.L (SP)+,D2-D3
        RTS

*------------------------------------------------------------------------
* Data — variables
*------------------------------------------------------------------------
        EVEN
X1      DS.B    12
X2      DS.B    12
X3      DS.B    12
X4      DS.B    12
E1      DS.B    48              4 x 12-byte extended
VX      DS.B    12
VY      DS.B    12
VJ      DS.L    1
VK      DS.L    1
VL      DS.L    1
TSTART  DS.L    1               Start time (ms)
TEND    DS.L    1               End time (ms)
TELAPSED DS.L   1               Elapsed time (ms)

*------------------------------------------------------------------------
* Strings
*------------------------------------------------------------------------
msgTitle  DC.B  '=== Whetstone Benchmark ===',0
msgM2     DC.B  'M2 (array)... ',0
msgM3     DC.B  'M3 (proc array)... ',0
msgM4     DC.B  'M4 (conditionals)... ',0
msgM6     DC.B  'M6 (log/exp/sqrt)... ',0
msgM7     DC.B  'M7 (proc calls)... ',0
msgM8     DC.B  'M8 (trig)... ',0
msgOK     DC.B  'OK',0
msgLoops  DC.B  'Passes: ',0
msgElapsed DC.B 'Elapsed: ',0
msgMs     DC.B  ' ms',0
msgKWIPS  DC.B  'KWIPS: ',0
msgNoTime DC.B  'KWIPS: N/A (timer returned 0)',0
msgDone   DC.B  'Whetstone complete.',0
msgNewline DC.B 0

        EVEN
        END     START
