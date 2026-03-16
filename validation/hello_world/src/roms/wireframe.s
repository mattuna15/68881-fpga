*------------------------------------------------------------------------
* 3D Wireframe Surface Plot
*
* Renders a 3D wireframe mesh of z = sin(x) * cos(y) using MC68881
* FPU F-line instructions.  Isometric projection onto 1280x720.
*
* Grid:     32 x 32 points over x,y in [-3, 3]
* Surface:  z = sin(x) * cos(y), amplitude scaled x2
* Projection: azimuth 45 deg, elevation 30 deg
* Colour:   white lines on black background
*
* Usage: Load via S-record (L command), execute with G 2000.
*
* Assemble:
*   vasmm68k_mot -Fsrec -m68000 -m68881 -o wireframe.srec wireframe.s
*------------------------------------------------------------------------

GRID_N      EQU  32
FB_BASE     EQU  $800000
SCREEN_W    EQU  1280
SCREEN_H    EQU  720
ROW_BYTES   EQU  SCREEN_W*4       * 5120

            ORG     $2000

*------------------------------------------------------------------------
* Entry point
*------------------------------------------------------------------------
START
            LEA     msgTitle,A1
            MOVEQ   #13,D0
            TRAP    #15

* Switch to graphics mode and clear to black
            MOVEQ   #17,D0
            MOVEQ   #1,D1
            TRAP    #15
            MOVEQ   #18,D0
            MOVE.L  #$FF000000,D1
            TRAP    #15

            LEA     msgCompute,A1
            MOVEQ   #13,D0
            TRAP    #15

* Record start time
            MOVEQ   #8,D0
            TRAP    #15
            MOVE.L  D1,STIME

*------------------------------------------------------------------------
* Phase 1: Compute grid and project to 2D screen coordinates
*
*   For each (i, j) in 0..31:
*     u = -3.0 + i * step,  v = -3.0 + j * step
*     z = sin(u) * cos(v)
*     sx = K1 * (u - v)              where K1 = cos(45)
*     sy = -K2 * (u + v) + K3 * z   where K2 = cos(45)*sin(30)
*                                          K3 = 2 * cos(30)
*     pixel_x = 640 + sx * SCALE
*     pixel_y = 360 - sy * SCALE
*
* FP register allocation:
*   FP7 = grid step     FP6 = v (current row)
*   FP5 = cos(v)        FP4 = SCALE (55.0)
*   FP0-FP3 = scratch
*
* Integer registers:
*   D5 = j (row),  D4 = i (column)
*   A2 = pointer into GRID_BUF (write)
*------------------------------------------------------------------------

* Compute step = 6.0 / 31
            FMOVE.L #6,FP7
            FMOVE.L #31,FP0
            FDIV    FP0,FP7            * FP7 = step

* Load scale constant
            FMOVE.L #55,FP4           * FP4 = projection scale

            LEA     GRID_BUF,A2        * A2 = output pointer

* --- Row loop (j = 0..31) ---
            CLR.W   D5                 * D5 = j

            FMOVE.S CONST_N3(PC),FP6  * FP6 = v = -3.0

ROWLOOP
* Precompute cos(v) for this row
            FCOS    FP6,FP5            * FP5 = cos(v)

* Progress every 8 rows
            MOVE.W  D5,D0
            ANDI.W  #7,D0
            BNE.S   NOPROG
            LEA     msgRow,A1
            MOVEQ   #14,D0
            TRAP    #15
            CLR.L   D1
            MOVE.W  D5,D1
            MOVEQ   #10,D2
            MOVEQ   #15,D0
            TRAP    #15
            LEA     msgOf,A1
            MOVEQ   #13,D0
            TRAP    #15

NOPROG
* --- Column loop (i = 0..31) ---
            CLR.W   D4

* Compute initial u = -3.0
            FMOVE.S CONST_N3(PC),FP0  * FP0 = u = -3.0

COLLOOP
* --- Compute z = sin(u) * cos(v) ---
            FSIN    FP0,FP1            * FP1 = sin(u)
            FMUL    FP5,FP1            * FP1 = sin(u) * cos(v) = z

* Save u for later advancement
            FMOVE.S FP0,SAVE_U

* --- Projection ---

* sx = K1 * (u - v)
            FMOVE   FP0,FP2            * FP2 = u
            FSUB    FP6,FP2            * FP2 = u - v
            FMUL.S  CONST_K1(PC),FP2   * FP2 = K1 * (u-v) = sx

* sy = -K2 * (u+v) + K3 * z
            FADD    FP6,FP0            * FP0 = u + v  (u no longer needed)
            FMUL.S  CONST_K2(PC),FP0   * FP0 = K2 * (u+v)
            FNEG    FP0                 * FP0 = -K2 * (u+v)
            FMUL.S  CONST_K3(PC),FP1   * FP1 = K3 * z
            FADD    FP1,FP0            * FP0 = -K2*(u+v) + K3*z = sy

* pixel_x = 640 + sx * SCALE
            FMUL    FP4,FP2            * FP2 = sx * 55
            FADD.L  #640,FP2           * FP2 = pixel_x

* pixel_y = 360 - sy * SCALE
            FMUL    FP4,FP0            * FP0 = sy * 55
            FMOVE.L #360,FP3           * FP3 = 360.0
            FSUB    FP0,FP3            * FP3 = 360 - sy*55 = pixel_y

* Convert to integer with clamping
            FINTRZ  FP2,FP2
            FMOVE.L FP2,D0             * D0.L = pixel_x (integer)
            FINTRZ  FP3,FP3
            FMOVE.L FP3,D1             * D1.L = pixel_y (integer)

* Clamp to screen bounds
            TST.L   D0
            BPL.S   .XL1
            CLR.L   D0
.XL1        CMP.L   #1279,D0
            BLE.S   .XL2
            MOVE.L  #1279,D0
.XL2        TST.L   D1
            BPL.S   .YL1
            CLR.L   D1
.YL1        CMP.L   #719,D1
            BLE.S   .YL2
            MOVE.L  #719,D1
.YL2

* Store (x.w, y.w) into grid buffer
            MOVE.W  D0,(A2)+
            MOVE.W  D1,(A2)+

* Advance u
            FMOVE.S SAVE_U(PC),FP0
            FADD    FP7,FP0            * u += step

            ADDQ.W  #1,D4
            CMP.W   #GRID_N,D4
            BLT     COLLOOP

* Advance v
            FADD    FP7,FP6            * v += step

            ADDQ.W  #1,D5
            CMP.W   #GRID_N,D5
            BLT     ROWLOOP

*------------------------------------------------------------------------
* Phase 2: Draw wireframe
*
* Draw horizontal grid lines (connecting points along rows):
*   For each row j, draw lines from point(i,j) to point(i+1,j)
*
* Draw vertical grid lines (connecting points along columns):
*   For each column i, draw lines from point(i,j) to point(i,j+1)
*
* GRID_BUF layout: row-major, 4 bytes per point (x.w, y.w)
*   Point(i,j) at offset (j * GRID_N + i) * 4
*------------------------------------------------------------------------

            LEA     msgDraw,A1
            MOVEQ   #13,D0
            TRAP    #15

            MOVE.L  #$FFFFFFFF,D5      * D5 = white colour (ARGB)

* --- Draw horizontal grid lines ---
            LEA     GRID_BUF,A3
            CLR.W   D5                 * reuse D5 as j counter? No, need colour.

            MOVE.L  #$FFFFFFFF,D5      * colour
            CLR.W   D7                 * D7 = j (row counter)

HROW        CLR.W   D6                 * D6 = i (column counter)
            LEA     GRID_BUF,A3
            MOVE.W  D7,D0
            MULU.W  #GRID_N*4,D0       * D0 = row offset = j * 128
            ADDA.L  D0,A3              * A3 -> point(0, j)

HSEG        MOVE.W  (A3),D1            * x0
            MOVE.W  2(A3),D2           * y0
            MOVE.W  4(A3),D3           * x1
            MOVE.W  6(A3),D4           * y1
            BSR     DRAWLINE
            ADDQ.L  #4,A3              * advance to next point
            ADDQ.W  #1,D6
            CMP.W   #GRID_N-1,D6
            BLT.S   HSEG

            ADDQ.W  #1,D7
            CMP.W   #GRID_N,D7
            BLT.S   HROW

* --- Draw vertical grid lines ---
            CLR.W   D7                 * D7 = j (row counter)

VROW        CLR.W   D6                 * D6 = i (column counter)
            LEA     GRID_BUF,A3
            MOVE.W  D7,D0
            MULU.W  #GRID_N*4,D0
            ADDA.L  D0,A3              * A3 -> point(0, j)

VSEG        MOVE.W  (A3),D1            * x0 from point(i, j)
            MOVE.W  2(A3),D2           * y0
            MOVE.W  GRID_N*4(A3),D3    * x1 from point(i, j+1)
            MOVE.W  GRID_N*4+2(A3),D4  * y1
            BSR     DRAWLINE
            ADDQ.L  #4,A3
            ADDQ.W  #1,D6
            CMP.W   #GRID_N,D6
            BLT.S   VSEG

            ADDQ.W  #1,D7
            CMP.W   #GRID_N-1,D7
            BLT.S   VROW

*------------------------------------------------------------------------
* Done — flush, timing, wait for key, return to text
*------------------------------------------------------------------------
            MOVE.B  #2,$FD0041         * flush

            MOVEQ   #8,D0
            TRAP    #15
            MOVE.L  D1,ETIME

            LEA     msgDone,A1
            MOVEQ   #13,D0
            TRAP    #15

            LEA     msgTime,A1
            MOVEQ   #14,D0
            TRAP    #15
            MOVE.L  ETIME,D1
            SUB.L   STIME,D1
            MOVEQ   #10,D2
            MOVEQ   #15,D0
            TRAP    #15
            LEA     msgMs,A1
            MOVEQ   #13,D0
            TRAP    #15

            LEA     msgKey,A1
            MOVEQ   #13,D0
            TRAP    #15
            MOVEQ   #5,D0
            TRAP    #15

* Back to text
            MOVEQ   #17,D0
            MOVEQ   #0,D1
            TRAP    #15
            LEA     msgBack,A1
            MOVEQ   #13,D0
            TRAP    #15

            RTS

*========================================================================
* DRAWLINE — Bresenham line from (D1.W,D2.W) to (D3.W,D4.W)
*            Colour in D5.L.  Writes directly to framebuffer.
*
* Destroys: D0-D4, D6-D7, A0  (D5 preserved)
*========================================================================
DRAWLINE
            MOVEM.L D0-D4/D6-D7/A0,-(SP)

* Compute starting FB address = FB_BASE + y*5120 + x*4
            CLR.L   D0
            MOVE.W  D2,D0
            MULU.W  #ROW_BYTES,D0      * D0 = y0 * 5120
            MOVE.W  D1,D6
            EXT.L   D6
            ASL.L   #2,D6              * D6 = x0 * 4
            ADD.L   D6,D0
            ADD.L   #FB_BASE,D0
            MOVEA.L D0,A0              * A0 = pixel address

* dx = x1 - x0 (signed), then abs; sx_bytes = +4 or -4
            SUB.W   D1,D3              * D3 = dx (signed)
            MOVEQ   #4,D6              * D6 = sx_bytes
            TST.W   D3
            BPL.S   .XP
            NEG.W   D3                 * D3 = |dx|
            MOVEQ   #-4,D6
.XP
* dy = y1 - y0 (signed), then abs; sy_bytes = +5120 or -5120
            SUB.W   D2,D4              * D4 = dy (signed)
            MOVE.L  #ROW_BYTES,D7      * D7 = sy_bytes
            TST.W   D4
            BPL.S   .YP
            NEG.W   D4                 * D4 = |dy|
            MOVE.L  #-ROW_BYTES,D7
.YP
* Check for zero-length line
            MOVE.W  D3,D0
            OR.W    D4,D0
            BEQ.S   .DOT               * single pixel

            CMP.W   D4,D3
            BLT.S   .STEEP

* --- Shallow line (|dx| >= |dy|) ---
            MOVE.W  D3,D1              * D1 = steps = |dx|
            MOVE.W  D3,D0
            LSR.W   #1,D0              * D0 = err = |dx|/2

.SLP        MOVE.L  D5,(A0)            * plot
            SUBQ.W  #1,D1
            BMI.S   .DN
            SUB.W   D4,D0              * err -= |dy|
            BPL.S   .SNY
            ADD.W   D3,D0              * err += |dx|
            ADDA.L  D7,A0              * y += sy
.SNY        ADDA.L  D6,A0              * x += sx
            BRA.S   .SLP

* --- Steep line (|dy| > |dx|) ---
.STEEP      MOVE.W  D4,D1              * D1 = steps = |dy|
            MOVE.W  D4,D0
            LSR.W   #1,D0              * D0 = err = |dy|/2

.STL        MOVE.L  D5,(A0)            * plot
            SUBQ.W  #1,D1
            BMI.S   .DN
            SUB.W   D3,D0              * err -= |dx|
            BPL.S   .SNX
            ADD.W   D4,D0              * err += |dy|
            ADDA.L  D6,A0              * x += sx
.SNX        ADDA.L  D7,A0              * y += sy
            BRA.S   .STL

.DOT        MOVE.L  D5,(A0)            * single pixel
.DN
            MOVEM.L (SP)+,D0-D4/D6-D7/A0
            RTS

*------------------------------------------------------------------------
* Constants (IEEE 754 single precision)
*------------------------------------------------------------------------
            EVEN

* K1 = cos(45 deg) = 0.70710678
CONST_K1    DC.L    $3F3504F3

* K2 = cos(45 deg) * sin(30 deg) = 0.35355339
CONST_K2    DC.L    $3EB504F3

* K3 = 2.0 * cos(30 deg) = 1.73205081  (z amplitude * cos elevation)
CONST_K3    DC.L    $3FDDB3D7

* -3.0 (range start)
CONST_N3    DC.L    $C0400000

*------------------------------------------------------------------------
* Variables
*------------------------------------------------------------------------
STIME       DS.L    1
ETIME       DS.L    1
SAVE_U      DS.L    1

*------------------------------------------------------------------------
* Strings
*------------------------------------------------------------------------
msgTitle    DC.B    '=== 3D Wireframe: z = sin(x)*cos(y) ===',0
msgCompute  DC.B    'Computing grid (32x32)...',0
msgRow      DC.B    'Row ',0
msgOf       DC.B    '/32',0
msgDraw     DC.B    'Drawing wireframe...',0
msgDone     DC.B    'Rendering complete!',0
msgTime     DC.B    'Elapsed: ',0
msgMs       DC.B    ' ms',0
msgKey      DC.B    'Press any key to return to text mode...',0
msgBack     DC.B    'Back in text mode.',0

*------------------------------------------------------------------------
* Grid buffer: 32 x 32 points, 4 bytes each (x.w, y.w)
*------------------------------------------------------------------------
            EVEN
GRID_BUF    DS.B    GRID_N*GRID_N*4

            END     START
