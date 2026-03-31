; scsi_test.s — Test ESP/SCSI interrupt-driven flow (like kernel's scsi_pollcmd)
; Assembles with vasm: vasmm68k_mot -Fbin -m68040 -no-opt -o scsi_test.bin scsi_test.s
;
; Reproduces the kernel's SCSI probe sequence:
;  1. Reset ESP, configure
;  2. Bus reset + DELAY(500ms)
;  3. SELECT+ATN with INQUIRY (target 0)
;  4. Poll for interrupt (like scsi_pollcmd)
;  5. Read status/intstatus/seqstep
;  6. If DATA_IN: set up DMA, issue TI
;  7. ICCS for status, MSGACC for disconnect
;
; Output: SCC serial

; NeXT hardware addresses
P_SCR2          equ $0200D000
P_INTRMASK      equ $02007800
P_INTRSTAT      equ $02007000
P_TIMER         equ $02016000
P_TIMER_LO      equ $02016001
P_TIMER_CSR     equ $02016004
P_EVENTC        equ $0201A000
P_SCC_CTRL_A    equ $02018001
P_SCC_DATA_A    equ $02018003

; ESP registers at 0x02014000
ESP_BASE        equ $02014000
ESP_TCL         equ ESP_BASE+0  ; Transfer Count LSB
ESP_TCH         equ ESP_BASE+1  ; Transfer Count MSB
ESP_FIFO        equ ESP_BASE+2  ; FIFO
ESP_CMD         equ ESP_BASE+3  ; Command
ESP_STAT        equ ESP_BASE+4  ; Status (read)
ESP_BUSID       equ ESP_BASE+4  ; Select Bus ID (write)
ESP_INTR        equ ESP_BASE+5  ; Interrupt Status (read, clears IRQ)
ESP_TIMEOUT     equ ESP_BASE+5  ; Select Timeout (write)
ESP_SEQSTEP     equ ESP_BASE+6  ; Sequence Step (read)
ESP_SYNCPER     equ ESP_BASE+6  ; Sync Period (write)
ESP_FIFOFLG     equ ESP_BASE+7  ; FIFO Flags (read)
ESP_SYNCOFF     equ ESP_BASE+7  ; Sync Offset (write)
ESP_CONFIG      equ ESP_BASE+8  ; Configuration
ESP_CLKCONV     equ ESP_BASE+9  ; Clock Conversion

; ESP DMA control
ESP_DMACTRL     equ $02014020
ESP_DMASTATUS   equ $02014021

; DMA registers (SCSI channel)
DMA_CSR         equ $02000010
DMA_NEXT        equ $02004010
DMA_LIMIT       equ $02004014
DMA_START       equ $02004018
DMA_STOP        equ $0200401C

; ESP commands
CMD_NOP         equ $00
CMD_FLUSH       equ $01
CMD_RESET       equ $02
CMD_BUSRESET    equ $03
CMD_TI          equ $10     ; Transfer Info
CMD_ICCS        equ $11     ; Initiator Command Complete Sequence
CMD_MSGACC      equ $12     ; Message Accepted
CMD_SELATN      equ $42     ; Select with ATN
CMD_ENSEL       equ $44     ; Enable Selection
CMD_DMA         equ $80     ; DMA bit

; ESP status bits
STAT_PHASE      equ $07
STAT_TC         equ $10
STAT_INT        equ $80

; ESP interrupt status bits
INTR_BS         equ $04     ; Bus Service
INTR_DC         equ $08     ; Disconnect
INTR_FC         equ $10     ; Function Complete

; SCSI phases
PHASE_DATAOUT   equ $00
PHASE_DATAIN    equ $01
PHASE_CMD       equ $02
PHASE_STATUS    equ $03
PHASE_MSGOUT    equ $06
PHASE_MSGIN     equ $07

; Interrupt bits
I_TIMER         equ $20000000  ; bit 29
I_SCSI          equ $00001000  ; bit 12
I_SCSI_DMA      equ $00040000  ; bit 18

; Timer
TIMER_ENABLE    equ $80
TIMER_LATCH     equ $40
SCR2_TIMERIPL7  equ $00008000

; Turbo DMA CSR bits (write)
TDMA_SETENABLE  equ $00010000
TDMA_SETSUPDATE equ $00020000
TDMA_DEV2M      equ $00040000
TDMA_CLRCOMPLETE equ $00080000
TDMA_RESET      equ $00100000

; DMA buffer in RAM
DMA_BUF         equ $04001000  ; 256 bytes for INQUIRY response

; ---- Vector table ----
        org     $0
        dc.l    $04000400       ; SSP
        dc.l    start           ; PC
        dcb.l   23,unhandled    ; Vectors 2-24
        dc.l    ipl1_handler    ; 25: level 1
        dc.l    ipl2_handler    ; 26: level 2
        dc.l    ipl3_handler    ; 27: level 3 (SCSI)
        dc.l    ipl4_handler    ; 28: level 4
        dc.l    ipl5_handler    ; 29: level 5
        dc.l    ipl6_handler    ; 30: level 6 (timer)
        dc.l    ipl7_handler    ; 31: level 7

; ---- Variables ----
TIMER_COUNT     equ $04000000
SCSI_INTR_COUNT equ $04000004
SCSI_STATUS     equ $04000008   ; captured ESP status
SCSI_INTRSTATUS equ $0400000C   ; captured ESP intstatus
SCSI_SEQSTEP    equ $04000010   ; captured ESP seqstep
DMA_INTR_COUNT  equ $04000014

; ---- Entry ----
        org     $100
start:
        move.w  #$2700,sr
        move.l  #0,P_INTRMASK

        ; Clear variables
        clr.l   TIMER_COUNT
        clr.l   SCSI_INTR_COUNT
        clr.l   DMA_INTR_COUNT
        clr.l   SCSI_STATUS
        clr.l   SCSI_INTRSTATUS
        clr.l   SCSI_SEQSTEP

        ; Clear DMA buffer
        lea     DMA_BUF,a0
        moveq   #63,d0
.clrbuf: clr.l  (a0)+
        dbra    d0,.clrbuf

        lea     msg_banner(pc),a0
        bsr     puts

; ---- Set up timer (like kernel us_timer_init) ----
        lea     msg_timer(pc),a0
        bsr     puts

        ; Timer at IPL6
        move.l  P_SCR2,d0
        and.l   #~SCR2_TIMERIPL7,d0
        move.l  d0,P_SCR2

        ; Period = 10000us (10ms)
        move.b  #(10000>>8),P_TIMER
        move.b  #(10000&$FF),P_TIMER_LO
        move.b  #(TIMER_ENABLE|TIMER_LATCH),P_TIMER_CSR

        lea     msg_ok(pc),a0
        bsr     puts

; ---- Configure ESP (like kernel scsetup) ----
        lea     msg_esp_setup(pc),a0
        bsr     puts

        ; DMA reset
        move.b  #$C0,ESP_DMACTRL      ; NOINTRBITS | RESET
        bsr     delay_10us
        move.b  #$80,ESP_DMACTRL      ; NOINTRBITS only
        bsr     delay_10us

        ; Configure ESP
        move.b  #$17,ESP_CONFIG        ; enable parity, disable reset intr, bus ID 7
        move.b  #5,ESP_CLKCONV         ; 20 MHz clock
        move.b  #$99,ESP_TIMEOUT       ; 250ms timeout
        move.b  #0,ESP_SYNCOFF         ; async
        move.b  #5,ESP_SYNCPER

        ; Clear pending interrupts
        move.b  ESP_INTR,d0

        bsr     delay_10us
        move.b  #$A0,ESP_DMACTRL      ; S5RDMAC_20MHZ | S5RDMAC_INTENABLE

        lea     msg_ok(pc),a0
        bsr     puts

; ---- Bus reset ----
        lea     msg_busreset(pc),a0
        bsr     puts

        move.b  #CMD_BUSRESET,ESP_CMD

        ; Enable timer + SCSI + DMA interrupts in mask
        move.l  #(I_TIMER|I_SCSI|I_SCSI_DMA),P_INTRMASK

        ; DELAY(500000) — 500ms like kernel
        move.w  #$2000,sr       ; enable interrupts
        move.l  #500000,d0
        bsr     delay_us
        move.w  #$2700,sr

        lea     msg_ok(pc),a0
        bsr     puts

        ; Print timer count after delay
        lea     msg_timer_count(pc),a0
        bsr     puts
        move.l  TIMER_COUNT,d0
        bsr     print_hex32
        bsr     putnl

; ---- SELECT+ATN with INQUIRY (like scsi_pollcmd) ----
        lea     msg_select(pc),a0
        bsr     puts

        ; Clear SCSI interrupt counter
        clr.l   SCSI_INTR_COUNT

        ; Flush FIFO
        move.b  #CMD_FLUSH,ESP_CMD

        ; Load FIFO: IDENTIFY message ($80) + INQUIRY CDB (6 bytes)
        move.b  #$80,ESP_FIFO          ; IDENTIFY msg (LUN 0)
        move.b  #$12,ESP_FIFO          ; INQUIRY opcode
        move.b  #$00,ESP_FIFO          ; LUN
        move.b  #$00,ESP_FIFO          ; reserved
        move.b  #$00,ESP_FIFO          ; reserved
        move.b  #$36,ESP_FIFO          ; allocation length (54 bytes)
        move.b  #$00,ESP_FIFO          ; control

        ; Set target ID = 0
        move.b  #0,ESP_BUSID

        ; Set transfer count for CDB
        move.b  #7,ESP_TCL             ; 7 bytes (identify + 6 CDB)
        move.b  #0,ESP_TCH

        ; Issue SELECT with ATN
        move.b  #CMD_SELATN,ESP_CMD

        ; ---- Poll for completion (like scsi_pollcmd) ----
        ; Lower IPL to allow interrupts, then DELAY+check loop
        move.l  #0,d7                  ; retry counter
        move.l  #1000,d6               ; max retries

.poll_loop:
        addq.l  #1,d7
        cmp.l   d6,d7
        bge     .poll_timeout

        ; Lower IPL to let interrupts fire
        move.w  #$2000,sr
        move.l  #1000,d0               ; DELAY(1000) = 1ms
        bsr     delay_us
        move.w  #$2700,sr

        ; Check if SCSI interrupt fired
        tst.l   SCSI_INTR_COUNT
        beq.s   .poll_loop

        ; Got interrupt! Print captured state
        lea     msg_got_intr(pc),a0
        bsr     puts

        lea     msg_status(pc),a0
        bsr     puts
        move.l  SCSI_STATUS,d0
        bsr     print_hex32

        lea     msg_intr_st(pc),a0
        bsr     puts
        move.l  SCSI_INTRSTATUS,d0
        bsr     print_hex32

        lea     msg_seqstep(pc),a0
        bsr     puts
        move.l  SCSI_SEQSTEP,d0
        bsr     print_hex32
        bsr     putnl

        ; Check phase from status
        move.l  SCSI_STATUS,d0
        and.l   #STAT_PHASE,d0

        cmp.b   #PHASE_DATAIN,d0
        beq     .do_datain

        cmp.b   #PHASE_STATUS,d0
        beq     .do_status

        cmp.b   #PHASE_MSGIN,d0
        beq     .do_msgin

        ; Unexpected phase
        lea     msg_bad_phase(pc),a0
        bsr     puts
        bra     .test_done

; ---- DATA IN: transfer INQUIRY data via DMA ----
.do_datain:
        lea     msg_datain(pc),a0
        bsr     puts

        ; Flush FIFO
        move.b  #CMD_FLUSH,ESP_CMD

        ; Set up DMA: next/limit for 54 bytes
        move.l  #DMA_BUF,DMA_NEXT
        move.l  #(DMA_BUF+64),DMA_LIMIT

        ; Reset DMA, set direction dev→mem
        move.l  #(TDMA_RESET|TDMA_DEV2M),DMA_CSR
        ; Enable DMA
        move.l  #(TDMA_SETENABLE|TDMA_DEV2M),DMA_CSR

        ; Set ESP transfer count
        move.b  #54,ESP_TCL
        move.b  #0,ESP_TCH

        ; Set DMA mode on ESP
        move.b  #$E8,ESP_DMACTRL       ; 20MHz + INTENABLE + DMA mode + DMA read

        ; Issue Transfer Info with DMA
        move.b  #(CMD_TI|CMD_DMA),ESP_CMD

        ; Wait for completion (poll)
        clr.l   SCSI_INTR_COUNT
        move.l  #0,d7
.ti_poll:
        addq.l  #1,d7
        cmp.l   d6,d7
        bge     .poll_timeout

        move.w  #$2000,sr
        move.l  #1000,d0
        bsr     delay_us
        move.w  #$2700,sr

        tst.l   SCSI_INTR_COUNT
        beq.s   .ti_poll

        ; TI complete — print status
        lea     msg_ti_done(pc),a0
        bsr     puts
        move.l  SCSI_STATUS,d0
        bsr     print_hex32
        lea     msg_intr_st(pc),a0
        bsr     puts
        move.l  SCSI_INTRSTATUS,d0
        bsr     print_hex32
        bsr     putnl

        ; Exit DMA mode
        move.b  #$A0,ESP_DMACTRL       ; normal bits (20MHz + INTENABLE)

        ; Dump first 8 bytes of INQUIRY data
        lea     msg_inq_data(pc),a0
        bsr     puts
        lea     DMA_BUF,a0
        moveq   #7,d1
.dump:  move.b  (a0)+,d0
        bsr     print_hex8
        move.b  #' ',d0
        bsr     putc
        dbra    d1,.dump
        bsr     putnl

        ; Now check new phase — should be STATUS
        move.l  SCSI_STATUS,d0
        and.l   #STAT_PHASE,d0
        cmp.b   #PHASE_STATUS,d0
        beq     .do_status

        ; Need to poll again for phase change
        lea     msg_waiting_status(pc),a0
        bsr     puts
        bra     .do_iccs

; ---- STATUS phase: ICCS ----
.do_status:
        lea     msg_status_phase(pc),a0
        bsr     puts
.do_iccs:
        ; Flush FIFO, issue ICCS
        move.b  #CMD_FLUSH,ESP_CMD
        move.b  #CMD_ICCS,ESP_CMD

        clr.l   SCSI_INTR_COUNT
        move.l  #0,d7
.iccs_poll:
        addq.l  #1,d7
        cmp.l   d6,d7
        bge     .poll_timeout
        move.w  #$2000,sr
        move.l  #1000,d0
        bsr     delay_us
        move.w  #$2700,sr
        tst.l   SCSI_INTR_COUNT
        beq.s   .iccs_poll

        lea     msg_iccs_done(pc),a0
        bsr     puts
        move.l  SCSI_STATUS,d0
        bsr     print_hex32
        bsr     putnl

        ; Read status and message from FIFO
        move.b  ESP_FIFO,d0
        move.l  d0,d2           ; save status
        move.b  ESP_FIFO,d0
        move.l  d0,d3           ; save message

        lea     msg_scsi_status(pc),a0
        bsr     puts
        move.l  d2,d0
        bsr     print_hex8
        lea     msg_scsi_msg(pc),a0
        bsr     puts
        move.l  d3,d0
        bsr     print_hex8
        bsr     putnl

; ---- MESSAGE ACCEPTED ----
.do_msgin:
        move.b  #CMD_MSGACC,ESP_CMD

        clr.l   SCSI_INTR_COUNT
        move.l  #0,d7
.msgacc_poll:
        addq.l  #1,d7
        cmp.l   d6,d7
        bge     .poll_timeout
        move.w  #$2000,sr
        move.l  #1000,d0
        bsr     delay_us
        move.w  #$2700,sr
        tst.l   SCSI_INTR_COUNT
        beq.s   .msgacc_poll

        lea     msg_msgacc_done(pc),a0
        bsr     puts

        bra     .test_done

.poll_timeout:
        lea     msg_timeout(pc),a0
        bsr     puts
        lea     msg_retries(pc),a0
        bsr     puts
        move.l  d7,d0
        bsr     print_hex32
        bsr     putnl

        ; Dump ESP state
        lea     msg_esp_state(pc),a0
        bsr     puts
        move.b  ESP_STAT,d0
        and.l   #$FF,d0
        bsr     print_hex8
        move.b  #'/',d0
        bsr     putc

        ; Read intstatus (clears interrupt)
        move.b  ESP_INTR,d0
        and.l   #$FF,d0
        bsr     print_hex8
        move.b  #'/',d0
        bsr     putc

        move.b  ESP_SEQSTEP,d0
        and.l   #$FF,d0
        bsr     print_hex8
        bsr     putnl

        ; Dump interrupt status/mask
        lea     msg_irq_state(pc),a0
        bsr     puts
        move.l  P_INTRSTAT,d0
        bsr     print_hex32
        move.b  #'/',d0
        bsr     putc
        move.l  P_INTRMASK,d0
        bsr     print_hex32
        bsr     putnl

.test_done:
        lea     msg_done(pc),a0
        bsr     puts

.halt:  stop    #$2700
        bra.s   .halt

; ======================================================================
; Interrupt handlers
; ======================================================================

ipl6_handler:
        move.b  P_TIMER_CSR,d0
        addq.l  #1,TIMER_COUNT
        rte

ipl3_handler:
        ; Capture ESP state
        move.b  ESP_STAT,d0
        and.l   #$FF,d0
        move.l  d0,SCSI_STATUS

        move.b  ESP_SEQSTEP,d0
        and.l   #$FF,d0
        move.l  d0,SCSI_SEQSTEP

        ; Read IntStatus LAST (clears IRQ)
        move.b  ESP_INTR,d0
        and.l   #$FF,d0
        move.l  d0,SCSI_INTRSTATUS

        addq.l  #1,SCSI_INTR_COUNT
        rte

ipl1_handler:
ipl2_handler:
ipl4_handler:
ipl5_handler:
ipl7_handler:
unhandled:
        rte

; ======================================================================
; Delay routines
; ======================================================================

; delay_us: delay d0 microseconds using event counter
delay_us:
        movem.l d0-d2,-(sp)
        move.l  d0,d2           ; d2 = target delta

        ; Read initial event counter
        move.b  P_EVENTC,d0     ; latch
        move.b  P_EVENTC+1,d0
        lsl.l   #8,d0
        move.b  P_EVENTC+2,d0
        lsl.l   #8,d0
        move.b  P_EVENTC+3,d0
        move.l  d0,d1           ; d1 = start

.dloop: move.b  P_EVENTC,d0     ; latch
        move.b  P_EVENTC+1,d0
        lsl.l   #8,d0
        move.b  P_EVENTC+2,d0
        lsl.l   #8,d0
        move.b  P_EVENTC+3,d0
        sub.l   d1,d0           ; delta
        cmp.l   d2,d0
        blt.s   .dloop

        movem.l (sp)+,d0-d2
        rts

; delay_10us: short ~10us delay via busy loop
delay_10us:
        move.l  d0,-(sp)
        move.l  #250,d0
.d10:   subq.l  #1,d0
        bne.s   .d10
        move.l  (sp)+,d0
        rts

; ======================================================================
; Serial output
; ======================================================================

putc:
        movem.l d1,-(sp)
.txw:   move.b  P_SCC_CTRL_A,d1
        btst    #2,d1
        beq.s   .txw
        move.b  d0,P_SCC_DATA_A
        movem.l (sp)+,d1
        rts

putnl:
        move.l  d0,-(sp)
        move.b  #13,d0
        bsr     putc
        move.b  #10,d0
        bsr     putc
        move.l  (sp)+,d0
        rts

puts:
        movem.l d0/a0,-(sp)
.lp:    move.b  (a0)+,d0
        beq.s   .dn
        bsr.s   putc
        bra.s   .lp
.dn:    movem.l (sp)+,d0/a0
        rts

print_hex32:
        movem.l d0-d2,-(sp)
        move.l  d0,d2
        moveq   #7,d1
.hl:    rol.l   #4,d2
        move.l  d2,d0
        and.l   #$F,d0
        cmp.b   #10,d0
        blt.s   .dig
        add.b   #('A'-10),d0
        bra.s   .ho
.dig:   add.b   #'0',d0
.ho:    bsr     putc
        dbra    d1,.hl
        movem.l (sp)+,d0-d2
        rts

print_hex8:
        movem.l d0-d2,-(sp)
        move.l  d0,d2
        moveq   #1,d1
.h8l:   rol.l   #4,d2
        move.l  d2,d0
        and.l   #$F,d0
        cmp.b   #10,d0
        blt.s   .d8
        add.b   #('A'-10),d0
        bra.s   .o8
.d8:    add.b   #'0',d0
.o8:    bsr     putc
        dbra    d1,.h8l
        movem.l (sp)+,d0-d2
        rts

; ======================================================================
; Strings
; ======================================================================

msg_banner:     dc.b 13,10,"=== NeXT SCSI/ESP Interrupt Test ===",13,10,0
msg_timer:      dc.b "Setting up timer (10ms)... ",0
msg_esp_setup:  dc.b "Configuring ESP... ",0
msg_busreset:   dc.b "Bus reset + DELAY(500ms)... ",0
msg_ok:         dc.b "OK",13,10,0
msg_timer_count: dc.b "  Timer IRQs during delay: ",0
msg_select:     dc.b "SELECT+ATN INQUIRY target 0...",13,10,0
msg_got_intr:   dc.b "  Got SCSI interrupt!",13,10,0
msg_status:     dc.b "  Status=$",0
msg_intr_st:    dc.b " IntStat=$",0
msg_seqstep:    dc.b " SeqStep=$",0
msg_datain:     dc.b "  Phase=DATA_IN, starting DMA TI...",13,10,0
msg_ti_done:    dc.b "  TI done: Status=$",0
msg_inq_data:   dc.b "  INQUIRY data: ",0
msg_waiting_status: dc.b "  Waiting for STATUS phase...",13,10,0
msg_status_phase: dc.b "  Phase=STATUS, issuing ICCS...",13,10,0
msg_iccs_done:  dc.b "  ICCS done: Status=$",0
msg_scsi_status: dc.b "  SCSI status=$",0
msg_scsi_msg:   dc.b " msg=$",0
msg_msgacc_done: dc.b "  MSGACC done — transaction complete!",13,10,0
msg_bad_phase:  dc.b "  ERROR: unexpected phase!",13,10,0
msg_timeout:    dc.b "  TIMEOUT waiting for interrupt!",13,10,0
msg_retries:    dc.b "  Retries: ",0
msg_esp_state:  dc.b "  ESP: stat/intr/seq = ",0
msg_irq_state:  dc.b "  IRQ: status/mask = ",0
msg_done:       dc.b 13,10,"=== Test complete ===",13,10,0

        even
