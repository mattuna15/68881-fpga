*------------------------------------------------------------------------
* Mandelbrot Set Renderer
*
* Renders a 640x640 pixel Mandelbrot set using MC68881 FPU F-line
* instructions.  Centred on the 1280x720 display at offset (320, 40).
*
* View window:  real [-2.0, +0.5], imag [-1.25, +1.25]
* Scale:        2.5 / 640 = 0.00390625
* Max iters:    32
* Palette:      16 colours, cycled via (iter & 15)
*
* Usage: Load via S-record (L command), execute with G 2000.
*
* Assemble:
*   vasmm68k_mot -Fsrec -m68000 -m68881 -o mandelbrot.srec mandelbrot.s
*------------------------------------------------------------------------

IMG_W       EQU  640
IMG_H       EQU  640
SCREEN_W    EQU  1280
FB_BASE     EQU  $800000
OFF_X       EQU  320           * horizontal offset on 1280-wide display
OFF_Y       EQU  40            * vertical offset on 720-high display
MAX_ITER    EQU  32
ROW_BYTES   EQU  SCREEN_W*4   * 5120 bytes per display row
IMG_ROW     EQU  IMG_W*4       * 2560 bytes per image row
ROW_SKIP    EQU  ROW_BYTES-IMG_ROW  * 2560 bytes to skip between rows

            ORG     $2000

*------------------------------------------------------------------------
* Entry point
*------------------------------------------------------------------------
START
            LEA     msgTitle,A1
            MOVEQ   #13,D0
            TRAP    #15

* Switch to graphics mode
            MOVEQ   #17,D0
            MOVEQ   #1,D1
            TRAP    #15

* Clear to black
            MOVEQ   #18,D0
            MOVE.L  #$FF000000,D1
            TRAP    #15

            LEA     msgRender,A1
            MOVEQ   #13,D0
            TRAP    #15

* Record start time
            MOVEQ   #8,D0
            TRAP    #15
            MOVE.L  D1,START_TIME

* Set up FP constants
* FP7 = scale = 0.00390625 (2.5/640)
            FMOVE.S #$3B800000,FP7     * 0.00390625

* Compute framebuffer start address
* FB_START = FB_BASE + OFF_Y * ROW_BYTES + OFF_X * 4
            LEA     FB_BASE,A3
            ADDA.L  #OFF_Y*ROW_BYTES+OFF_X*4,A3

* Outer loop: Y pixels (D5 = 0..639)
            CLR.W   D5                 * D5 = pixel_y

YLOOP
* ci = -1.25 + pixel_y * scale
            FMOVE.W D5,FP3
            FMUL    FP7,FP3            * FP3 = pixel_y * scale
            FSUB.S  #$3FA00000,FP3     * FP3 -= 1.25  =>  ci = y*scale - 1.25

* Progress output every 64 rows
            MOVE.W  D5,D0
            ANDI.W  #63,D0
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
            MOVEQ   #14,D0
            TRAP    #15
            MOVE.L  #IMG_H,D1
            MOVEQ   #10,D2
            MOVEQ   #15,D0
            TRAP    #15
            LEA     msgNewline,A1
            MOVEQ   #13,D0
            TRAP    #15

NOPROG
* Inner loop: X pixels (D4 = 0..639)
            CLR.W   D4                 * D4 = pixel_x

XLOOP
* cr = -2.0 + pixel_x * scale
            FMOVE.W D4,FP2
            FMUL    FP7,FP2            * FP2 = pixel_x * scale
            FSUB.S  #$40000000,FP2     * FP2 -= 2.0  =>  cr = x*scale - 2.0

* z = 0 + 0i
            FMOVE.L #0,FP0              * FP0 = zr = 0
            FMOVE.L #0,FP1              * FP1 = zi = 0

* Iteration loop (D6 = iteration counter)
            MOVEQ   #0,D6

ITERLOOP
* zr_sq = zr * zr
            FMOVE   FP0,FP4
            FMUL    FP0,FP4            * FP4 = zr^2

* zi_sq = zi * zi
            FMOVE   FP1,FP5
            FMUL    FP1,FP5            * FP5 = zi^2

* Check escape: zr^2 + zi^2 > 4.0 ?
            FMOVE   FP4,FP6
            FADD    FP5,FP6            * FP6 = zr^2 + zi^2
            FCMP.S  #$40800000,FP6     * compare with 4.0
            FBGT    ESCAPED

* zi_new = 2 * zr * zi + ci  (compute before zr, since we need old zr)
            FMUL    FP0,FP1            * FP1 = zr * zi  (old zi destroyed, but zi^2 safe in FP5)
            FADD    FP1,FP1            * FP1 = 2 * zr * zi
            FADD    FP3,FP1            * FP1 = 2*zr*zi + ci  (new zi)

* zr_new = zr^2 - zi^2 + cr
            FMOVE   FP4,FP0            * FP0 = zr^2
            FSUB    FP5,FP0            * FP0 = zr^2 - zi^2
            FADD    FP2,FP0            * FP0 = zr^2 - zi^2 + cr  (new zr)

            ADDQ.W  #1,D6
            CMP.W   #MAX_ITER,D6
            BLT.S   ITERLOOP

* Reached max iterations — pixel is in the set (black)
            MOVE.L  #$FF000000,(A3)+   * opaque black (ARGB)
            BRA.S   NEXTX

ESCAPED
* Pick colour from palette: index = (iter - 1) & 15
            MOVE.W  D6,D0
            SUBQ.W  #1,D0
            ANDI.W  #15,D0
            ASL.W   #2,D0              * D0 = palette offset (4 bytes each)
            LEA     PALETTE,A0
            MOVE.L  (A0,D0.W),(A3)+    * write pixel colour

NEXTX
            ADDQ.W  #1,D4
            CMP.W   #IMG_W,D4
            BLT     XLOOP

* End of row — advance A3 past the unused portion of the display row
            ADDA.L  #ROW_SKIP,A3

            ADDQ.W  #1,D5
            CMP.W   #IMG_H,D5
            BLT     YLOOP

*------------------------------------------------------------------------
* Done — flush, print timing, wait for keypress
*------------------------------------------------------------------------
            MOVE.B  #2,$FD0041         * flush command

* Record end time
            MOVEQ   #8,D0
            TRAP    #15
            MOVE.L  D1,END_TIME

            LEA     msgDone,A1
            MOVEQ   #13,D0
            TRAP    #15

* Print elapsed time
            LEA     msgTime,A1
            MOVEQ   #14,D0
            TRAP    #15
            MOVE.L  END_TIME,D1
            SUB.L   START_TIME,D1
            MOVEQ   #10,D2
            MOVEQ   #15,D0
            TRAP    #15
            LEA     msgMs,A1
            MOVEQ   #13,D0
            TRAP    #15

* Wait for keypress
            LEA     msgKey,A1
            MOVEQ   #13,D0
            TRAP    #15
            MOVEQ   #5,D0
            TRAP    #15

* Switch back to text mode
            MOVEQ   #17,D0
            MOVEQ   #0,D1
            TRAP    #15

            LEA     msgBack,A1
            MOVEQ   #13,D0
            TRAP    #15

            RTS

*------------------------------------------------------------------------
* Data
*------------------------------------------------------------------------
            EVEN

START_TIME  DS.L    1
END_TIME    DS.L    1

* 16-colour palette (ARGB) — classic Mandelbrot colouring
* Dark blues → light blues → greens → yellows → oranges → reds → magentas
PALETTE
            DC.L    $FF000033          *  0: very dark blue
            DC.L    $FF000066          *  1: dark blue
            DC.L    $FF0000CC          *  2: medium blue
            DC.L    $FF0033FF          *  3: blue
            DC.L    $FF0066FF          *  4: light blue
            DC.L    $FF0099CC          *  5: cyan-blue
            DC.L    $FF00CC66          *  6: teal
            DC.L    $FF00FF00          *  7: green
            DC.L    $FF66FF00          *  8: yellow-green
            DC.L    $FFFFFF00          *  9: yellow
            DC.L    $FFFFCC00          * 10: gold
            DC.L    $FFFF9900          * 11: orange
            DC.L    $FFFF6600          * 12: dark orange
            DC.L    $FFFF3300          * 13: red-orange
            DC.L    $FFFF0000          * 14: red
            DC.L    $FFCC0066          * 15: magenta

msgTitle    DC.B    '=== Mandelbrot Set Renderer ===',0
msgRender   DC.B    'Rendering 640x640 Mandelbrot (max 32 iter)...',0
msgRow      DC.B    'Row ',0
msgOf       DC.B    '/',0
msgDone     DC.B    'Rendering complete!',0
msgTime     DC.B    'Elapsed: ',0
msgMs       DC.B    ' ms',0
msgKey      DC.B    'Press any key to return to text mode...',0
msgBack     DC.B    'Back in text mode.',0
msgNewline  DC.B    0

            EVEN
            END     START
