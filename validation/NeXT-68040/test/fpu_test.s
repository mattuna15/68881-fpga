; fpu_test.s — FPU F-line PC-advancement test ROM
;
; Assembles with vasm:
;   vasmm68k_mot -Fbin -m68040 -o fpu_test.bin fpu_test.s
;
; Purpose: verify that our fline_handler advances PC past the full
; F-line instruction (opword + command word + any operand extension
; words).  On real NeXT, user-mode code hit ILLG $008C at PC=$4EE0 —
; which means an F-line at $4EDE with extension word $008C wasn't
; fully skipped.  This test isolates that case and variants.
;
; Method: each test executes an F-line instruction followed immediately
; by a known marker word.  If PC advances correctly, we reach the
; marker-less "ok" path.  If PC lands on the extension word, it gets
; re-interpreted as an illegal opcode and vec4 fires.
;
; Output: SCC channel A (0x02018003) — same as mmu_test / timer_test.

P_SCC_CTRL_A    equ $02018001
P_SCC_DATA_A    equ $02018003
P_INTRMASK      equ $02007800

STACK_TOP       equ $04000400
USER_STACK_TOP  equ $04000800

; ---- Vector table at $0 ----
        org     $0
        dc.l    STACK_TOP       ; vec 0 SSP
        dc.l    start           ; vec 1 initial PC
        dc.l    vec2_buserr     ; vec 2 bus error
        dc.l    vec3_addrerr    ; vec 3 address error
        dc.l    vec4_illegal    ; vec 4 illegal instruction
        dcb.l   6,vec_unhandled ; vec 5-10
        dc.l    vec11_fline     ; vec 11 F-line
        dcb.l   52,vec_unhandled; vec 12-63 (filler)

; ---- Entry point ----
        org     $100
start:
        move.w  #$2700,sr               ; supervisor, IPL=7
        move.l  #0,P_INTRMASK
        lea     STACK_TOP,sp

        lea     msg_banner(pc),a0
        bsr     puts

; ---- Test 1: FMOVE.L #1, FP0  (immediate long → FP0) ----
        lea     msg_t1(pc),a0
        bsr     puts
t1_start:
        dc.w    $F23C                   ; F-line FMOVE.L #imm,FP0  (ea=#imm)
        dc.w    $4000                   ; cmd: rm=1, fmt=LONG, dst=FP0, op=MOVE
        dc.l    1                       ; long immediate
t1_end:
        bsr     put_ok

; ---- Test 2: FMOVE.W #$008C, FP0  (16-bit imm that matches the bug pattern) ----
        lea     msg_t2(pc),a0
        bsr     puts
t2_start:
        dc.w    $F23C                   ; F-line
        dc.w    $5000                   ; cmd: rm=1, fmt=WORD, dst=FP0, op=MOVE
        dc.w    $008C                   ; word imm — matches the observed ILLG value
t2_end:
        bsr     put_ok

; ---- Test 3: FASIN.X FP0,FP2  — exactly the opword/ext pair seen crashing ----
; opword $F200, ext $008C  (rm=0, src=FP0, dst=FP2, op=$0C=FASIN)
        lea     msg_t3(pc),a0
        bsr     puts
t3_start:
        dc.w    $F200
        dc.w    $008C
t3_end:
        bsr     put_ok

; ---- Test 4: FADD.X FP0,FP0  — dyadic reg-reg ----
        lea     msg_t4(pc),a0
        bsr     puts
t4_start:
        dc.w    $F200
        dc.w    $0022                   ; rm=0, src=FP0, dst=FP0, op=$22=FADD
t4_end:
        bsr     put_ok

; ---- Test 5: FMOVE.L FP0,D0  (FP → Dn, fmt=LONG, type 011) ----
        lea     msg_t5(pc),a0
        bsr     puts
t5_start:
        dc.w    $F200                   ; ea = D0 (mode 0 reg 0)
        dc.w    $6000                   ; cmd: type=3(FMOVE fpn→ea), fmt=LONG, src=FP0
t5_end:
        bsr     put_ok

; ---- Test 6: FMOVEM.X FP0-FP7,-(A0)  (regs→mem predec, static list) ----
        lea     scratch,a0
        add.l   #12*8,a0                ; a0 past end so predec works
        lea     msg_t6(pc),a1
        exg     a0,a1                   ; a0=msg, a1=scratch+96
        bsr     puts
        exg     a0,a1                   ; a0=scratch+96
t6_start:
        dc.w    $F220                   ; ea = -(A0) (mode 4 reg 0)
        dc.w    $E0FF                   ; cmd: FMOVEM regs→mem, static, predec, mask=$FF
t6_end:
        bsr     put_ok

; ---- Test 7: FMOVEM.X (A0)+,FP0-FP7  (mem→regs postinc, static list) ----
        lea     scratch,a0
        lea     msg_t7(pc),a1
        exg     a0,a1
        bsr     puts
        exg     a0,a1
t7_start:
        dc.w    $F218                   ; ea = (A0)+ (mode 3 reg 0)
        dc.w    $D0FF                   ; cmd: FMOVEM mem→regs, static, postinc, mask=$FF
t7_end:
        bsr     put_ok

; ---- Test 8: FMOVE.S #1.0, FP0  (single imm) ----
        lea     msg_t8(pc),a0
        bsr     puts
t8_start:
        dc.w    $F23C
        dc.w    $4400                   ; cmd: rm=1, fmt=SINGLE, dst=FP0, op=MOVE
        dc.l    $3F800000               ; 1.0f
t8_end:
        bsr     put_ok

; ---- Test 9: FMOVE FPCR/FPSR/FPIAR,$008C(A0)  ----
; This is the EXACT sequence seen at user PC $00004EDE on real hw:
; opword $F228 (mode=5 d16,An,  An=A0), cmd $BC00 (type=5, dir=1, regsel=7),
; displacement $008C.  A 6-byte instruction. If the handler doesn't advance
; PC past the $008C displacement, Musashi re-executes $008C as an opcode
; → BTST D0,A4 = illegal.
        lea     scratch,a0              ; A0 base (scratch+$008C must be writable)
        sub.l   #$8C,a0                 ; so that a0 + $008C = scratch
        lea     msg_t9(pc),a1
        exg     a0,a1
        bsr     puts
        exg     a0,a1
t9_start:
        dc.w    $F228                   ; F-line, ea = (d16,A0)
        dc.w    $BC00                   ; FMOVE FPCR/FPSR/FPIAR → (d16,A0), regsel=111
        dc.w    $008C                   ; displacement — the bytes that were mis-dispatched
t9_end:
        bsr     put_ok

; ---- Test 10: FMOVE (d16,A0),FPCR/FPSR/FPIAR  (load direction) ----
        lea     scratch,a0
        sub.l   #$20,a0
        lea     msg_t10(pc),a1
        exg     a0,a1
        bsr     puts
        exg     a0,a1
t10_start:
        dc.w    $F228                   ; F-line, ea = (d16,A0)
        dc.w    $9C00                   ; cmd: type=4, dir=0, regsel=7
        dc.w    $0020                   ; displacement
t10_end:
        bsr     put_ok

; ---- Test 11: FMOVE FPCR,$XXXXXXXX.L  (mode 7/1 absolute long) ----
; opword $F239 (mode=7 reg=1 abs.L), cmd $B000 (type=5, dir=1, regsel=100)
; 8-byte instruction: opword+cmd+addr(long)
        lea     msg_t11(pc),a0
        bsr     puts
t11_start:
        dc.w    $F239                   ; F-line, ea = (xxx).L
        dc.w    $B000                   ; cmd: type=5, dir=1, regsel=FPCR only
        dc.l    scratch                 ; absolute-long address (32-bit)
t11_end:
        bsr     put_ok

; ---- Supervisor-mode pass complete — now rerun in user mode ----
        lea     msg_user(pc),a0
        bsr     puts

        ; Build RTE frame: format 0, SR = $0000 (user, IPL=0),
        ; PC = user_start.  TRAP #0 vector returns us to supervisor.
        move.l  #trap0_handler,$00000080
        move.l  #vec4_illegal,$00000010         ; in case user tests fail
        move.l  #vec11_fline,$0000002C

        move.l  #USER_STACK_TOP,a0
        move.l  a0,usp
        ; Build a 68040 format 0 frame: format/vector word, PC, SR
        move.w  #$0000,-(sp)                    ; format 0, vector 0
        move.l  #user_start,-(sp)               ; PC (user)
        move.w  #$0000,-(sp)                    ; SR = user, IPL=0
        rte
halt:
        bra.s   halt

; ------------------------------------------------------------------
; User-mode test sequence — same FPU encodings as supervisor pass
; ------------------------------------------------------------------
user_start:
        lea     msg_u_banner(pc),a0
        bsr     puts

u_t1_start:
        dc.w    $F23C, $4000
        dc.l    1
u_t1_end:
        bsr     put_ok_u

u_t2_start:
        dc.w    $F23C, $5000
        dc.w    $008C
u_t2_end:
        bsr     put_ok_u

u_t3_start:
        dc.w    $F200, $008C            ; the exact crashing pair, now user mode
u_t3_end:
        bsr     put_ok_u

u_t4_start:
        dc.w    $F200, $0022
u_t4_end:
        bsr     put_ok_u

; user test 5: the EXACT sequence from the crash
        lea     scratch,a0
        sub.l   #$8C,a0
u_t5_start:
        dc.w    $F228, $BC00, $008C     ; FMOVE ctrl,$008C(A0)
u_t5_end:
        bsr     put_ok_u

; user test 6: load direction
        lea     scratch,a0
        sub.l   #$20,a0
u_t6_start:
        dc.w    $F228, $9C00, $0020     ; FMOVE $20(A0),ctrl
u_t6_end:
        bsr     put_ok_u

        lea     msg_u_done(pc),a0
        bsr     puts

        trap    #0                       ; return to supervisor

put_ok_u:
        lea     msg_uok(pc),a0
        bra     puts

trap0_handler:
        lea     msg_all_done(pc),a0
        bsr     puts
.spin:  bra.s   .spin

; ==================================================================
; Exception vectors — each prints PPC from the stack frame and halts
; Format 0 frame: +0 SR, +2 PC (4 bytes)
; Format 2 (68040 address/bus errors): longer, PC at +4
; We just print whatever's at +2 as a longword for simplicity.
; ==================================================================
vec4_illegal:
        lea     msg_illg(pc),a0
        bsr     puts
        move.l  2(sp),d0
        bsr     put_hex32
        bsr     put_nl
die:    bra.s   die

vec11_fline:
        lea     msg_fline(pc),a0
        bsr     puts
        move.l  2(sp),d0
        bsr     put_hex32
        bsr     put_nl
        bra.s   die

vec2_buserr:
        lea     msg_buserr(pc),a0
        bsr     puts
        bra.s   die

vec3_addrerr:
        lea     msg_addrerr(pc),a0
        bsr     puts
        bra.s   die

vec_unhandled:
        lea     msg_unh(pc),a0
        bsr     puts
        bra.s   die

; ==================================================================
; Helpers
; ==================================================================
put_ok:
        lea     msg_ok(pc),a0
        bra     puts                    ; tail-call

put_nl:
        move.b  #13,P_SCC_DATA_A
        move.b  #10,P_SCC_DATA_A
        rts

putc:
        move.b  d0,P_SCC_DATA_A
        rts

puts:
        move.b  (a0)+,d0
        beq.s   .done
        bsr.s   putc
        bra.s   puts
.done:  rts

put_hex32:
        ; print d0 as 8 hex digits
        moveq   #7,d1
.loop:
        rol.l   #4,d0
        move.l  d0,d2
        and.l   #$F,d2
        cmp.l   #10,d2
        blt.s   .dig
        add.l   #'A'-10,d2
        bra.s   .out
.dig:   add.l   #'0',d2
.out:
        move.b  d2,P_SCC_DATA_A
        dbra    d1,.loop
        rts

; ==================================================================
; Messages
; ==================================================================
msg_banner:   dc.b 13,10,"== FPU F-line PC-advance test ==",13,10,0
msg_t1:       dc.b "T1 FMOVE.L #1,FP0            ",0
msg_t2:       dc.b "T2 FMOVE.W #$008C,FP0        ",0
msg_t3:       dc.b "T3 FASIN.X FP0,FP2 ($F200 $008C) ",0
msg_t4:       dc.b "T4 FADD.X FP0,FP0            ",0
msg_t5:       dc.b "T5 FMOVE.L FP0,D0            ",0
msg_t6:       dc.b "T6 FMOVEM.X FP0-FP7,-(A0)    ",0
msg_t7:       dc.b "T7 FMOVEM.X (A0)+,FP0-FP7    ",0
msg_t8:       dc.b "T8 FMOVE.S #1.0,FP0          ",0
msg_t9:       dc.b "T9 FMOVE ctrl,$008C(A0) ($F228 $BC00 $008C) ",0
msg_t10:      dc.b "T10 FMOVE $20(A0),ctrl        ",0
msg_t11:      dc.b "T11 FMOVE FPCR,abs.L          ",0
msg_ok:       dc.b "OK",13,10,0
msg_uok:      dc.b "uOK",13,10,0
msg_user:     dc.b 13,10,"-- switching to USER mode --",13,10,0
msg_u_banner: dc.b "== USER-mode FPU tests ==",13,10,0
msg_u_done:   dc.b "USER tests passed",13,10,0
msg_all_done: dc.b 13,10,"ALL TESTS PASSED (super+user)",13,10,0
msg_done:     dc.b 13,10,"ALL TESTS PASSED",13,10,0
msg_illg:     dc.b 13,10,"FAIL ILLG @",0
msg_fline:    dc.b 13,10,"FAIL FLINE @",0
msg_buserr:   dc.b 13,10,"FAIL BUSERR",13,10,0
msg_addrerr:  dc.b 13,10,"FAIL ADDRERR",13,10,0
msg_unh:      dc.b 13,10,"FAIL UNHANDLED VEC",13,10,0

        even
scratch:
        dcb.b   12*8,0                  ; 96 bytes for FMOVEM.X FP0-FP7 save area
