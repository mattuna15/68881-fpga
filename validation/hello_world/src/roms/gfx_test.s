*------------------------------------------------------------------------
* Graphics Framebuffer Test Pattern
*
* Sense-check for the pixel-addressable graphics mode.
* Draws colour bars, a border, and a gradient to verify:
*   - Mode switching (text -> graphics -> text)
*   - Framebuffer clear
*   - Direct pixel writes via TRAP #19
*   - Pixel readback via TRAP #20
*   - Screen info query via TRAP #21
*
* Usage: Load via S-record (L command), execute with G 2000.
*
* Assemble: vasmm68k_mot -Fsrec -m68000 -o gfx_test.srec gfx_test.s
*------------------------------------------------------------------------

SCREEN_W    EQU  1280
SCREEN_H    EQU  720
FB_BASE     EQU  $800000
BAR_H       EQU  90          * 720 / 8 bars = 90 pixels each

         ORG     $2000

*------------------------------------------------------------------------
* Entry point
*------------------------------------------------------------------------
START
         LEA     msgTitle,A1
         MOVEQ   #13,D0
         TRAP    #15

* Query screen info (TRAP #15, D0=21)
         MOVEQ   #21,D0
         TRAP    #15
         MOVE.W  D1,GOTW
         MOVE.W  D2,GOTH

* Print dimensions
         LEA     msgDims,A1
         MOVEQ   #14,D0
         TRAP    #15
         CLR.L   D1
         MOVE.W  GOTW,D1
         MOVEQ   #10,D2
         MOVEQ   #15,D0
         TRAP    #15
         MOVE.B  #'x',D1
         MOVEQ   #6,D0
         TRAP    #15
         CLR.L   D1
         MOVE.W  GOTH,D1
         MOVEQ   #10,D2
         MOVEQ   #15,D0
         TRAP    #15
         LEA     msgNewline,A1
         MOVEQ   #13,D0
         TRAP    #15

* Switch to graphics mode
         LEA     msgSwitchGfx,A1
         MOVEQ   #13,D0
         TRAP    #15

         MOVEQ   #17,D0          Set mode
         MOVEQ   #1,D1           1 = graphics
         TRAP    #15

* Clear to dark blue
         LEA     msgClear,A1
         MOVEQ   #13,D0
         TRAP    #15

         MOVEQ   #18,D0          Clear FB
         MOVE.L  #$FF000040,D1   Dark blue ARGB
         TRAP    #15

*------------------------------------------------------------------------
* Draw 8 vertical colour bars across the screen
*   Each bar is 160 pixels wide (1280/8)
*------------------------------------------------------------------------
         LEA     msgBars,A1
         MOVEQ   #13,D0
         TRAP    #15

         LEA     COLOURS,A2      Pointer to colour table
         CLR.W   D6              D6 = bar index (0-7)
         CLR.W   D4              D4 = X start of current bar

BARLOOP  MOVE.L  (A2)+,D3        D3 = ARGB colour for this bar

* Fill bar: X from D4 to D4+159, Y from 0 to BAR_H-1
         MOVE.W  D4,D5           D5 = current X
         CLR.W   D2              D2 = current Y

BARY     MOVE.W  D5,D1           D1 = X (reset to bar start)
BARX     MOVEQ   #19,D0          Set pixel
         TRAP    #15
         ADDQ.W  #1,D1           Next X
         MOVE.W  D1,D0           Use D0 as scratch (consumed by TRAP)
         SUB.W   D4,D0           D0 = relative X within bar
         CMP.W   #160,D0         Reached end of bar?
         BLT.S   BARX            No — keep drawing

         ADDQ.W  #1,D2           Next Y
         CMP.W   #BAR_H,D2
         BLT.S   BARY

         ADD.W   #160,D4         Next bar start X
         ADDQ.W  #1,D6
         CMP.W   #8,D6
         BLT.S   BARLOOP

*------------------------------------------------------------------------
* Draw a 1-pixel white border around the screen
*------------------------------------------------------------------------
         LEA     msgBorder,A1
         MOVEQ   #13,D0
         TRAP    #15

         MOVE.L  #$FFFFFFFF,D3   White

* Top edge (Y=0, X=0..1279)
         CLR.W   D2              Y=0
         CLR.W   D1              X=0
BTOP     MOVEQ   #19,D0
         TRAP    #15
         ADDQ.W  #1,D1
         CMP.W   #SCREEN_W,D1
         BLT.S   BTOP

* Bottom edge (Y=719, X=0..1279)
         MOVE.W  #SCREEN_H-1,D2
         CLR.W   D1
BBOT     MOVEQ   #19,D0
         TRAP    #15
         ADDQ.W  #1,D1
         CMP.W   #SCREEN_W,D1
         BLT.S   BBOT

* Left edge (X=0, Y=0..719)
         CLR.W   D1
         CLR.W   D2
BLFT     MOVEQ   #19,D0
         TRAP    #15
         ADDQ.W  #1,D2
         CMP.W   #SCREEN_H,D2
         BLT.S   BLFT

* Right edge (X=1279, Y=0..719)
         MOVE.W  #SCREEN_W-1,D1
         CLR.W   D2
BRGT     MOVEQ   #19,D0
         TRAP    #15
         ADDQ.W  #1,D2
         CMP.W   #SCREEN_H,D2
         BLT.S   BRGT

*------------------------------------------------------------------------
* Draw a horizontal red gradient bar (Y=100..139, full width)
* Red channel = X * 255 / 1279
*------------------------------------------------------------------------
         LEA     msgGrad,A1
         MOVEQ   #13,D0
         TRAP    #15

         MOVE.W  #100,D2         Y start
GRADY    CLR.W   D1              X=0
GRADX
* Compute red = X / 4, capped at 255 (gradient over first 1024 pixels)
         MOVE.W  D1,D4
         LSR.W   #2,D4           D4 = X/4 (0..319)
         CMP.W   #255,D4
         BLE.S   GROK
         MOVE.W  #255,D4
GROK
* Build ARGB: $FF_RR_00_00
         AND.L   #$FF,D4         Clear high word, keep low byte only
         SWAP    D4              D4 = 0x00RR0000 (red in bits 23..16)
         OR.L    #$FF000000,D4   D4 = 0xFFRR0000 (set alpha)
         MOVE.L  D4,D3           D3 = ARGB colour

         MOVEQ   #19,D0
         TRAP    #15

         ADDQ.W  #1,D1
         CMP.W   #SCREEN_W,D1
         BLT.S   GRADX

         ADDQ.W  #1,D2
         CMP.W   #140,D2
         BLT.S   GRADY

*------------------------------------------------------------------------
* Readback test: read pixel at (0,0) — should be white (border)
*------------------------------------------------------------------------
         LEA     msgReadback,A1
         MOVEQ   #14,D0
         TRAP    #15

         CLR.W   D1              X=0
         CLR.W   D2              Y=0
         MOVEQ   #20,D0          Get pixel
         TRAP    #15
* D1.L now has the ARGB value
         MOVE.L  D1,D0
         BSR     PRTHEX32
         LEA     msgExpWhite,A1
         MOVEQ   #13,D0
         TRAP    #15

*------------------------------------------------------------------------
* Readback test: read pixel at (640, 50) — should be green bar colour
*------------------------------------------------------------------------
         LEA     msgRead2,A1
         MOVEQ   #14,D0
         TRAP    #15

         MOVE.W  #640,D1         X=640 (bar 4 = green, starts at X=640)
         MOVE.W  #50,D2          Y=50 (within bar height)
         MOVEQ   #20,D0
         TRAP    #15
         MOVE.L  D1,D0
         BSR     PRTHEX32
         LEA     msgExpGreen,A1
         MOVEQ   #13,D0
         TRAP    #15

*------------------------------------------------------------------------
* Flush and wait for keypress
*------------------------------------------------------------------------
         LEA     msgKey,A1
         MOVEQ   #13,D0
         TRAP    #15

* Force a flush
         MOVE.B  #2,$FD0041      Flush command

         MOVEQ   #5,D0           Wait for keypress
         TRAP    #15

*------------------------------------------------------------------------
* Switch back to text mode
*------------------------------------------------------------------------
         MOVEQ   #17,D0
         MOVEQ   #0,D1           0 = text mode
         TRAP    #15

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
         TRAP    #15
         DBRA    D2,.lp
         MOVEM.L (SP)+,D2-D3
         RTS

*------------------------------------------------------------------------
* Data
*------------------------------------------------------------------------
         EVEN

* 8 colour bars: Red, Orange, Yellow, Green, Cyan, Blue, Magenta, White
COLOURS  DC.L    $FFFF0000       Red
         DC.L    $FFFF8000       Orange
         DC.L    $FFFFFF00       Yellow
         DC.L    $FF00FF00       Green
         DC.L    $FF00FFFF       Cyan
         DC.L    $FF0000FF       Blue
         DC.L    $FFFF00FF       Magenta
         DC.L    $FFFFFFFF       White

GOTW     DS.W    1
GOTH     DS.W    1

msgTitle     DC.B  '=== Graphics Framebuffer Test ===',0
msgDims      DC.B  'Screen: ',0
msgSwitchGfx DC.B  'Switching to graphics mode...',0
msgClear     DC.B  'Clearing to dark blue...',0
msgBars      DC.B  'Drawing colour bars...',0
msgBorder    DC.B  'Drawing border...',0
msgGrad      DC.B  'Drawing red gradient...',0
msgReadback  DC.B  'Readback (0,0): ',0
msgExpWhite  DC.B  '  (expect FFFFFFFF = white)',0
msgRead2     DC.B  'Readback (640,50): ',0
msgExpGreen  DC.B  '  (expect FF00FF00 = green)',0
msgKey       DC.B  'Press any key to return to text mode...',0
msgDone      DC.B  'Back in text mode. Test complete.',0
msgNewline   DC.B  0

         EVEN
         END     START
