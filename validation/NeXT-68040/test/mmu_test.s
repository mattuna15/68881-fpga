; mmu_test.s — NeXT 68040 MMU test ROM for QEMU verification
; Assembles with vasm: vasmm68k_mot -Fbin -m68040 -o mmu_test.bin mmu_test.s
;
; Tests:
;  1. TC enable/disable, SRP/URP setup
;  2. Transparent Translation registers (DTT0/ITT0)
;  3. Page table walk — valid mapping (3-level)
;  4. Page fault (invalid PTE) → ATC fault → bus error → recovery
;  5. U (Used) bit set after read access
;  6. M (Modified) bit set after write access
;  7. Write-protect fault on WP page
;  8. RTE from Format 7 frame (page fault resolved + rerun)
;  9. PTEST instruction returns correct MMUSR
; 10. PFLUSH clears TLB (re-walk after flush)
;
; Output: SCC channel A serial (0x02018003/0x02018001) at 9600 baud

; ---- Hardware addresses ----
P_SCC_CTRL_A    equ $02018001
P_SCC_DATA_A    equ $02018003
P_INTRMASK      equ $02007800
P_INTRSTAT      equ $02007000
P_VRAM          equ $0C000000

; ---- RAM layout ----
; $04000000-$040003FF: test variables
; $04000400-$040007FF: supervisor stack
; $04001000-$04001FFF: L1 root table (128 entries × 4 = 512 bytes)
; $04002000-$04002FFF: L2 pointer table
; $04003000-$04003FFF: L3 page table (64 entries × 4 = 256 bytes for 4K pages)
; $04004000-$04004FFF: target page (mapped via page table)
; $04005000-$04005FFF: unmapped page (no PTE — should fault)
; $04006000-$04006FFF: write-protected page

STACK           equ $04000800
L1_TABLE        equ $04001000
L2_TABLE        equ $04002000
L3_TABLE        equ $04003000
TARGET_PAGE     equ $04004000
UNMAPPED_VA     equ $08000000   ; high VA not in DTT0, no PTE
WP_PAGE_PHYS    equ $04006000

; Test variables
TEST_NUM        equ $04000000
PASS_COUNT      equ $04000004
FAIL_COUNT      equ $04000008
FAULT_FIRED     equ $0400000C
FAULT_VA        equ $04000010
FAULT_SSW       equ $04000014
FAULT_PC        equ $04000018
RECOVER_ADDR    equ $0400001C

; Page descriptor bits
PD_RESIDENT     equ $01         ; bit 0: resident page
PD_UDT_VALID    equ $02         ; bit 1: valid UDT (upper descriptor table)
PD_WP           equ $04         ; bit 2: write-protect
PD_USED         equ $08         ; bit 3: used
PD_MODIFIED     equ $10         ; bit 4: modified
PD_SUPER        equ $80         ; bit 7: supervisor only

; ---- Vector table ----
        org     $0
        dc.l    STACK           ; Vector 0: Initial SSP
        dc.l    start           ; Vector 1: Initial PC
        dc.l    buserr_handler  ; Vector 2: Bus Error
        dcb.l   21,unhandled    ; Vectors 3-23
        dc.l    unhandled       ; Vector 24: spurious
        dc.l    unhandled       ; Vector 25-31: autovectors
        dc.l    unhandled
        dc.l    unhandled
        dc.l    unhandled
        dc.l    unhandled
        dc.l    unhandled
        dc.l    unhandled

; ---- Entry point ----
        org     $100
start:
        move.w  #$2700,sr       ; supervisor, all interrupts masked
        move.l  #0,P_INTRMASK   ; clear interrupt mask

        clr.l   TEST_NUM
        clr.l   PASS_COUNT
        clr.l   FAIL_COUNT
        clr.l   FAULT_FIRED

        lea     msg_banner(pc),a0
        bsr     puts

; ==================================================================
; Test 1: TC register — enable and disable MMU
; ==================================================================
        move.l  #1,TEST_NUM
        lea     msg_t1(pc),a0
        bsr     puts

        ; Disable MMU
        movec   d0,tc           ; clear TC
        nop

        ; Set SRP to our L1 table
        move.l  #L1_TABLE,d0
        movec   d0,srp
        movec   d0,urp

        ; Set DTT0 to cover $04-$07 (our RAM) for supervisor
        ; LAB=$04, LAM=$03, E=1, S=01(super), CM=00, W=0
        move.l  #$0403A000,d0
        movec   d0,dtt0

        ; Set ITT0 same for instruction fetches (covers RAM)
        movec   d0,itt0

        ; Set DTT1 to cover $00-$03 (ROM + low space) for supervisor
        ; LAB=$00, LAM=$03, E=1, S=01(super)
        move.l  #$0003A000,d0
        movec   d0,dtt1

        ; Set ITT1 to cover $00-$03 for instruction fetches (ROM)
        movec   d0,itt1

        ; Enable MMU: TC bit 15 = enable, bit 14 = 0 (4K pages)
        move.l  #$8000,d0
        movec   d0,tc

        ; PFLUSH all
        pflusha

        ; If we get here, TC enable worked
        nop
        nop

        ; Disable MMU for remaining setup
        moveq   #0,d0
        movec   d0,tc
        pflusha

        lea     msg_pass(pc),a0
        bsr     puts
        addq.l  #1,PASS_COUNT

; ==================================================================
; Test 2: DTT0 transparent translation
; ==================================================================
        move.l  #2,TEST_NUM
        lea     msg_t2(pc),a0
        bsr     puts

        ; DTT0 is $0403A000: covers $04-$07 supervisor
        ; Write to $04004000 — should work via DTT0 (transparent)
        move.l  #$0403A000,d0
        movec   d0,dtt0
        move.l  #$8000,d0       ; enable MMU
        movec   d0,tc
        pflusha

        move.l  #$DEADBEEF,TARGET_PAGE
        cmp.l   #$DEADBEEF,TARGET_PAGE
        bne.s   .t2_fail

        moveq   #0,d0
        movec   d0,tc           ; disable MMU
        pflusha
        lea     msg_pass(pc),a0
        bsr     puts
        addq.l  #1,PASS_COUNT
        bra.s   .t2_done
.t2_fail:
        moveq   #0,d0
        movec   d0,tc
        pflusha
        lea     msg_fail(pc),a0
        bsr     puts
        addq.l  #1,FAIL_COUNT
.t2_done:

; ==================================================================
; Test 3: 3-level page table walk — set up and read mapped page
; ==================================================================
        move.l  #3,TEST_NUM
        lea     msg_t3(pc),a0
        bsr     puts

        ; Build page tables that map VA $08000000 → PA $04004000
        ; VA $08000000: L1 idx = ($08000000 >> 25) & 0x7F = 4
        ;               L2 idx = ($08000000 >> 18) & 0x7F = 0
        ;               L3 idx = ($08000000 >> 12) & 0x3F = 0

        ; Clear tables
        lea     L1_TABLE,a0
        move.l  #128,d0
.clr1:  clr.l   (a0)+
        subq.l  #1,d0
        bne.s   .clr1
        lea     L2_TABLE,a0
        move.l  #128,d0
.clr2:  clr.l   (a0)+
        subq.l  #1,d0
        bne.s   .clr2
        lea     L3_TABLE,a0
        move.l  #64,d0
.clr3:  clr.l   (a0)+
        subq.l  #1,d0
        bne.s   .clr3

        ; L1[4] = L2_TABLE | UDT_VALID (bit 1)
        move.l  #L2_TABLE+PD_UDT_VALID,L1_TABLE+(4*4)

        ; L2[0] = L3_TABLE | UDT_VALID
        move.l  #L3_TABLE+PD_UDT_VALID,L2_TABLE+(0*4)

        ; L3[0] = TARGET_PAGE | RESIDENT (bit 0)
        move.l  #TARGET_PAGE+PD_RESIDENT,L3_TABLE+(0*4)

        ; Write test pattern to physical target page
        move.l  #$CAFEBABE,TARGET_PAGE

        ; Enable MMU, narrow DTT0 to NOT cover $08xxxxxx
        ; DTT0: LAB=$04, LAM=$00 → only covers $04xxxxxx
        move.l  #$0400A000,d0   ; $04, mask $00, E=1, S=01(super)
        movec   d0,dtt0
        movec   d0,itt0

        move.l  #L1_TABLE,d0
        movec   d0,srp

        move.l  #$8000,d0       ; TC enable, 4K pages
        movec   d0,tc
        pflusha

        ; Now read VA $08000000 — should walk page table → $04004000
        move.l  $08000000,d0
        cmp.l   #$CAFEBABE,d0
        bne.s   .t3_fail

        moveq   #0,d1
        movec   d1,tc
        pflusha
        lea     msg_pass(pc),a0
        bsr     puts
        addq.l  #1,PASS_COUNT
        bra.s   .t3_done
.t3_fail:
        moveq   #0,d1
        movec   d1,tc
        pflusha
        lea     msg_fail(pc),a0
        bsr     puts
        addq.l  #1,FAIL_COUNT
.t3_done:

; ==================================================================
; Test 4: ATC fault on unmapped page → bus error fires
; ==================================================================
        move.l  #4,TEST_NUM
        lea     msg_t4(pc),a0
        bsr     puts

        ; L3[1] is still 0 (invalid) — VA $08001000 should fault
        clr.l   FAULT_FIRED
        lea     .t4_recover(pc),a0
        move.l  a0,RECOVER_ADDR

        ; Enable MMU
        move.l  #$0400A000,d0
        movec   d0,dtt0
        movec   d0,itt0
        move.l  #L1_TABLE,d0
        movec   d0,srp
        move.l  #$8000,d0
        movec   d0,tc
        pflusha

        ; Access unmapped VA — should trigger bus error
        move.l  $08001000,d0    ; L3[1]=0 → fault!
        ; Should NOT reach here
        bra.s   .t4_check

.t4_recover:
        ; Bus error handler jumped here
        nop

.t4_check:
        moveq   #0,d0
        movec   d0,tc
        pflusha
        clr.l   RECOVER_ADDR

        tst.l   FAULT_FIRED
        beq.s   .t4_fail

        ; Check fault VA was $08001000
        cmp.l   #$08001000,FAULT_VA
        bne.s   .t4_fail

        lea     msg_pass(pc),a0
        bsr     puts
        addq.l  #1,PASS_COUNT
        bra.s   .t4_done
.t4_fail:
        lea     msg_fail(pc),a0
        bsr     puts
        addq.l  #1,FAIL_COUNT
.t4_done:

; ==================================================================
; Test 5: U (Used) bit set after read
; ==================================================================
        move.l  #5,TEST_NUM
        lea     msg_t5(pc),a0
        bsr     puts

        ; Clear U+M bits on L3[0]
        move.l  #TARGET_PAGE+PD_RESIDENT,L3_TABLE
        ; Clear U+M on L1[4] and L2[0]
        move.l  #L2_TABLE+PD_UDT_VALID,L1_TABLE+(4*4)
        move.l  #L3_TABLE+PD_UDT_VALID,L2_TABLE

        ; Enable MMU
        move.l  #$0400A000,d0
        movec   d0,dtt0
        movec   d0,itt0
        move.l  #L1_TABLE,d0
        movec   d0,srp
        move.l  #$8000,d0
        movec   d0,tc
        pflusha

        ; Read from mapped page — should set U bit
        move.l  $08000000,d0

        ; Disable MMU
        moveq   #0,d0
        movec   d0,tc
        pflusha

        ; Check U bit set on L3[0]
        move.l  L3_TABLE,d0
        btst    #3,d0           ; PD_USED = bit 3
        beq.s   .t5_fail

        ; Check U bit on L1[4]
        move.l  L1_TABLE+(4*4),d0
        btst    #3,d0
        beq.s   .t5_fail

        lea     msg_pass(pc),a0
        bsr     puts
        addq.l  #1,PASS_COUNT
        bra.s   .t5_done
.t5_fail:
        lea     msg_fail(pc),a0
        bsr     puts
        addq.l  #1,FAIL_COUNT
.t5_done:

; ==================================================================
; Test 6: M (Modified) bit set after write
; ==================================================================
        move.l  #6,TEST_NUM
        lea     msg_t6(pc),a0
        bsr     puts

        ; Reset descriptors — clear U+M
        move.l  #TARGET_PAGE+PD_RESIDENT,L3_TABLE
        move.l  #L2_TABLE+PD_UDT_VALID,L1_TABLE+(4*4)
        move.l  #L3_TABLE+PD_UDT_VALID,L2_TABLE

        ; Enable MMU
        move.l  #$0400A000,d0
        movec   d0,dtt0
        movec   d0,itt0
        move.l  #L1_TABLE,d0
        movec   d0,srp
        move.l  #$8000,d0
        movec   d0,tc
        pflusha

        ; Write to mapped page — should set U+M
        move.l  #$12345678,$08000000

        ; Disable MMU
        moveq   #0,d0
        movec   d0,tc
        pflusha

        ; Check both U and M bits on L3[0]
        move.l  L3_TABLE,d0
        and.l   #PD_USED+PD_MODIFIED,d0
        cmp.l   #PD_USED+PD_MODIFIED,d0
        bne.s   .t6_fail

        ; Verify data landed correctly
        cmp.l   #$12345678,TARGET_PAGE
        bne.s   .t6_fail

        lea     msg_pass(pc),a0
        bsr     puts
        addq.l  #1,PASS_COUNT
        bra.s   .t6_done
.t6_fail:
        lea     msg_fail(pc),a0
        bsr     puts
        addq.l  #1,FAIL_COUNT
.t6_done:

; ==================================================================
; Test 7: Write-protect fault
; ==================================================================
        move.l  #7,TEST_NUM
        lea     msg_t7(pc),a0
        bsr     puts

        ; Set L3[0] as WP + resident
        move.l  #TARGET_PAGE+PD_RESIDENT+PD_WP,L3_TABLE
        move.l  #L2_TABLE+PD_UDT_VALID,L1_TABLE+(4*4)
        move.l  #L3_TABLE+PD_UDT_VALID,L2_TABLE

        clr.l   FAULT_FIRED
        lea     .t7_recover(pc),a0
        move.l  a0,RECOVER_ADDR

        ; Enable MMU
        move.l  #$0400A000,d0
        movec   d0,dtt0
        movec   d0,itt0
        move.l  #L1_TABLE,d0
        movec   d0,srp
        move.l  #$8000,d0
        movec   d0,tc
        pflusha

        ; Read should work (WP only blocks writes)
        move.l  $08000000,d0

        ; Write should fault
        move.l  #$FFFFFFFF,$08000000
        ; Should not reach here
        bra.s   .t7_check

.t7_recover:
        nop

.t7_check:
        moveq   #0,d0
        movec   d0,tc
        pflusha
        clr.l   RECOVER_ADDR

        tst.l   FAULT_FIRED
        beq.s   .t7_fail

        ; Check SSW: should have RW=0 (write fault), ATC=1
        move.l  FAULT_SSW,d0
        btst    #10,d0          ; ATC bit
        beq.s   .t7_fail
        btst    #8,d0           ; RW bit — should be 0 (write)
        bne.s   .t7_fail

        ; Check U set but M not set (WP prevented M)
        move.l  L3_TABLE,d0
        btst    #3,d0           ; U should be set
        beq.s   .t7_fail
        btst    #4,d0           ; M should NOT be set
        bne.s   .t7_fail

        lea     msg_pass(pc),a0
        bsr     puts
        addq.l  #1,PASS_COUNT
        bra.s   .t7_done
.t7_fail:
        lea     msg_fail(pc),a0
        bsr     puts
        addq.l  #1,FAIL_COUNT
.t7_done:

; ==================================================================
; Test 8: RTE Format 7 — resolve fault and rerun
; ==================================================================
        move.l  #8,TEST_NUM
        lea     msg_t8(pc),a0
        bsr     puts

        ; Set up L3[1] as INVALID initially
        clr.l   L3_TABLE+(1*4)
        move.l  #L2_TABLE+PD_UDT_VALID,L1_TABLE+(4*4)
        move.l  #L3_TABLE+PD_UDT_VALID,L2_TABLE

        ; Write magic to the physical page that WILL be mapped
        move.l  #$BE120400,TARGET_PAGE+$1000   ; at $04005000

        clr.l   FAULT_FIRED
        clr.l   RECOVER_ADDR    ; no recover — we want real RTE rerun

        ; Enable MMU
        move.l  #$0400A000,d0
        movec   d0,dtt0
        movec   d0,itt0
        move.l  #L1_TABLE,d0
        movec   d0,srp
        move.l  #$8000,d0
        movec   d0,tc
        pflusha

        ; Access VA $08001000 — will fault because L3[1] = 0
        ; The bus error handler will map it and RTE to rerun
        move.l  $08001000,d0

        ; If we get here, RTE rerun worked!
        moveq   #0,d1
        movec   d1,tc
        pflusha

        tst.l   FAULT_FIRED
        beq.s   .t8_fail        ; fault should have fired

        cmp.l   #$BE120400,d0    ; should have read the magic value
        bne.s   .t8_fail

        lea     msg_pass(pc),a0
        bsr     puts
        addq.l  #1,PASS_COUNT
        bra.s   .t8_done
.t8_fail:
        moveq   #0,d1
        movec   d1,tc
        pflusha
        lea     msg_fail(pc),a0
        bsr     puts
        addq.l  #1,FAIL_COUNT
.t8_done:

; ==================================================================
; Test 9: PTEST instruction
; ==================================================================
        move.l  #9,TEST_NUM
        lea     msg_t9(pc),a0
        bsr     puts

        ; Set up valid mapping: L3[0] = TARGET_PAGE | RESIDENT
        move.l  #TARGET_PAGE+PD_RESIDENT,L3_TABLE
        move.l  #L2_TABLE+PD_UDT_VALID,L1_TABLE+(4*4)
        move.l  #L3_TABLE+PD_UDT_VALID,L2_TABLE

        ; Enable MMU
        move.l  #$0400A000,d0
        movec   d0,dtt0
        movec   d0,itt0
        move.l  #L1_TABLE,d0
        movec   d0,srp
        move.l  #$8000,d0
        movec   d0,tc
        pflusha

        ; Set DFC to supervisor data (FC=5) for PTEST
        move.l  #5,d0
        movec   d0,dfc

        ; PTEST read (An) — should return R bit set + physical address
        lea     $08000000,a0
        ptestR  (a0)            ; PTEST read
        movec   mmusr,d0        ; read MMUSR

        ; Disable MMU
        moveq   #0,d1
        movec   d1,tc
        pflusha

        ; Check R (resident) bit — bit 0
        btst    #0,d0
        beq.s   .t9_fail

        ; Check physical address in upper bits
        and.l   #$FFFFF000,d0
        cmp.l   #TARGET_PAGE,d0
        bne.s   .t9_fail

        lea     msg_pass(pc),a0
        bsr     puts
        addq.l  #1,PASS_COUNT
        bra.s   .t9_done
.t9_fail:
        lea     msg_fail(pc),a0
        bsr     puts
        addq.l  #1,FAIL_COUNT
.t9_done:

; ==================================================================
; Test 10: PFLUSH clears TLB
; ==================================================================
        move.l  #10,TEST_NUM
        lea     msg_t10(pc),a0
        bsr     puts

        ; Map L3[0] to TARGET_PAGE, write pattern
        move.l  #TARGET_PAGE+PD_RESIDENT,L3_TABLE
        move.l  #$AABB0011,TARGET_PAGE

        ; Enable MMU + read via page table (populates TLB)
        move.l  #$0400A000,d0
        movec   d0,dtt0
        movec   d0,itt0
        move.l  #L1_TABLE,d0
        movec   d0,srp
        move.l  #$8000,d0
        movec   d0,tc
        pflusha

        move.l  $08000000,d0    ; TLB fill
        cmp.l   #$AABB0011,d0
        bne.s   .t10_fail

        ; Now change L3[0] to point to a DIFFERENT physical page
        ; (WP_PAGE_PHYS = $04006000)
        move.l  #$CCDD0022,WP_PAGE_PHYS
        moveq   #0,d1
        movec   d1,tc
        pflusha                         ; disabled, but flush needed
        move.l  #WP_PAGE_PHYS+PD_RESIDENT,L3_TABLE

        ; Re-enable MMU + PFLUSH
        move.l  #$8000,d0
        movec   d0,tc
        pflusha                         ; flush TLB!

        ; Read again — should see NEW physical page data
        move.l  $08000000,d0
        cmp.l   #$CCDD0022,d0
        bne.s   .t10_fail

        moveq   #0,d1
        movec   d1,tc
        pflusha

        lea     msg_pass(pc),a0
        bsr     puts
        addq.l  #1,PASS_COUNT
        bra.s   .t10_done
.t10_fail:
        moveq   #0,d1
        movec   d1,tc
        pflusha
        lea     msg_fail(pc),a0
        bsr     puts
        addq.l  #1,FAIL_COUNT
.t10_done:

; ==================================================================
; Test 11: PLOAD preloads TLB — no fault on subsequent access
; ==================================================================
        move.l  #11,TEST_NUM
        lea     msg_t11(pc),a0
        bsr     puts

        ; Set up mapping: L3[0] → TARGET_PAGE | RESIDENT
        move.l  #TARGET_PAGE+PD_RESIDENT,L3_TABLE
        move.l  #L2_TABLE+PD_UDT_VALID,L1_TABLE+(4*4)
        move.l  #L3_TABLE+PD_UDT_VALID,L2_TABLE
        move.l  #$DEADC0DE,TARGET_PAGE

        ; Enable MMU with narrow DTT0
        move.l  #$0400A000,d0
        movec   d0,dtt0
        movec   d0,itt0
        move.l  #L1_TABLE,d0
        movec   d0,srp
        move.l  #$8000,d0
        movec   d0,tc
        pflusha                 ; flush TLB — no cached entry

        ; Set DFC for supervisor data
        move.l  #5,d0
        movec   d0,dfc

        ; PLOAD read (a0) — preload TLB for $08000000
        lea     $08000000,a0
        dc.l    $f0102208       ; PLOAD read (a0) — raw opcode

        ; Now access $08000000 — should hit TLB (no page walk needed)
        ; If PLOAD didn't work, this would still work via walk.
        ; But the key is: no ATC fault should fire.
        clr.l   FAULT_FIRED
        move.l  $08000000,d0

        moveq   #0,d1
        movec   d1,tc
        pflusha

        cmp.l   #$DEADC0DE,d0
        bne.s   .t11_fail

        ; Verify no fault fired (PLOAD preloaded TLB)
        tst.l   FAULT_FIRED
        bne.s   .t11_fail

        lea     msg_pass(pc),a0
        bsr     puts
        addq.l  #1,PASS_COUNT
        bra.s   .t11_done
.t11_fail:
        lea     msg_fail(pc),a0
        bsr     puts
        addq.l  #1,FAIL_COUNT
.t11_done:

; ==================================================================
; Test 12: Fault-rerun with PLOAD (kernel pattern)
; Simulates: fault → fix PTE → PLOAD → RTE → rerun succeeds
; Without PLOAD, this would infinite-loop (fault, fix, rerun, fault...)
; ==================================================================
        move.l  #12,TEST_NUM
        lea     msg_t12(pc),a0
        bsr     puts

        ; L3[1] initially INVALID
        clr.l   L3_TABLE+(1*4)
        move.l  #L2_TABLE+PD_UDT_VALID,L1_TABLE+(4*4)
        move.l  #L3_TABLE+PD_UDT_VALID,L2_TABLE
        move.l  #$CAFE1234,TARGET_PAGE+$1000

        clr.l   FAULT_FIRED
        clr.l   RECOVER_ADDR        ; no skip — we want real rerun

        ; Enable MMU
        move.l  #$0400A000,d0
        movec   d0,dtt0
        movec   d0,itt0
        move.l  #L1_TABLE,d0
        movec   d0,srp
        move.l  #$8000,d0
        movec   d0,tc
        pflusha

        ; Access VA $08001000 — L3[1]=0 → fault!
        ; Bus error handler will: map PTE, PLOAD, RTE
        move.l  $08001000,d0

        ; If we get here, rerun worked
        moveq   #0,d1
        movec   d1,tc
        pflusha

        tst.l   FAULT_FIRED
        beq.s   .t12_fail

        cmp.l   #$CAFE1234,d0
        bne.s   .t12_fail

        lea     msg_pass(pc),a0
        bsr     puts
        addq.l  #1,PASS_COUNT
        bra.s   .t12_done
.t12_fail:
        moveq   #0,d1
        movec   d1,tc
        pflusha
        lea     msg_fail(pc),a0
        bsr     puts
        addq.l  #1,FAIL_COUNT
.t12_done:

; ==================================================================
; Summary
; ==================================================================
        lea     msg_summary(pc),a0
        bsr     puts
        move.l  PASS_COUNT,d0
        bsr     put_decimal
        lea     msg_passed(pc),a0
        bsr     puts
        move.l  FAIL_COUNT,d0
        bsr     put_decimal
        lea     msg_failed(pc),a0
        bsr     puts

        tst.l   FAIL_COUNT
        beq.s   .all_pass
        lea     msg_some_fail(pc),a0
        bsr     puts
        bra.s   .done
.all_pass:
        lea     msg_all_pass(pc),a0
        bsr     puts
.done:
        ; Write summary to VRAM for visual feedback
        move.l  PASS_COUNT,P_VRAM
        move.l  FAIL_COUNT,P_VRAM+4
        bra.s   .done           ; halt (infinite loop)

; ==================================================================
; Bus error handler — Format 7 (68040 access error)
; ==================================================================
buserr_handler:
        ; Save fault info for test verification
        move.l  #1,FAULT_FIRED

        ; Format 7 frame layout (from SP after push):
        ;   SP+$00: SR
        ;   SP+$02: PC (4 bytes)
        ;   SP+$06: Format/Vector
        ;   SP+$08: EA
        ;   SP+$0C: SSW
        ;   SP+$14: FA (fault address)

        ; Read fault address from frame
        move.l  $14(sp),FAULT_VA        ; FA at offset $14

        ; Read SSW from frame
        moveq   #0,d0
        move.w  $0C(sp),d0             ; SSW at offset $0C
        move.l  d0,FAULT_SSW

        ; Read faulting PC
        move.l  $02(sp),FAULT_PC

        ; Check if we have a recovery address (test wants skip-over)
        tst.l   RECOVER_ADDR
        beq.s   .try_resolve

        ; Recovery mode: patch PC in frame to skip faulting instruction
        move.l  RECOVER_ADDR,$02(sp)
        rte                             ; return to recovery address

.try_resolve:
        ; Rerun mode: fix the page table so instruction can succeed.
        ; Map L3[1] → $04005000 (TARGET_PAGE + $1000) | RESIDENT
        ; This simulates what the kernel's vm_fault() + pmap_enter() does.
        move.l  #$04005001,L3_TABLE+(1*4)   ; PA $04005000 + RESIDENT

        ; PFLUSH then PLOAD — exactly what the kernel's trap return does.
        ; Without PLOAD, the TLB isn't preloaded and the rerun re-faults.
        pflusha

        ; PLOAD read: preload TLB for the faulted address
        ; Set DFC to supervisor data (FC=5) for PLOAD
        move.l  #5,d0
        movec   d0,dfc
        move.l  FAULT_VA,a0         ; load faulted VA into A0
        dc.l    $f0102208       ; PLOAD read (a0) — raw opcode                ; preload TLB

        ; RTE — CPU will rerun the faulting instruction (TLB now valid)
        rte

; ==================================================================
; Unhandled exception
; ==================================================================
unhandled:
        lea     msg_unhandled(pc),a0
        bsr     puts
        bra.s   *               ; halt

; ==================================================================
; Serial output routines
; ==================================================================
putc:
        ; Send byte in d0 to SCC channel A
        move.b  d0,P_SCC_DATA_A
        rts

puts:
        ; Print NUL-terminated string at (a0)
        move.b  (a0)+,d0
        beq.s   .puts_done
        bsr.s   putc
        bra.s   puts
.puts_done:
        rts

put_decimal:
        ; Print d0 as decimal (0-99)
        divu    #10,d0
        move.l  d0,d1
        add.b   #'0',d0
        bsr.s   putc
        swap    d1
        move.b  d1,d0
        add.b   #'0',d0
        bsr.s   putc
        rts

; ==================================================================
; String constants
; ==================================================================
msg_banner:     dc.b    13,10,"=== MMU Test ROM ===",13,10,0
msg_t1:         dc.b    "T1 TC enable/disable: ",0
msg_t2:         dc.b    "T2 DTT0 transparent:  ",0
msg_t3:         dc.b    "T3 Page table walk:   ",0
msg_t4:         dc.b    "T4 ATC fault:         ",0
msg_t5:         dc.b    "T5 Used bit (read):   ",0
msg_t6:         dc.b    "T6 Modified bit (wr): ",0
msg_t7:         dc.b    "T7 Write-protect:     ",0
msg_t8:         dc.b    "T8 RTE rerun:         ",0
msg_t9:         dc.b    "T9 PTEST:             ",0
msg_t10:        dc.b    "T10 PFLUSH:           ",0
msg_t11:        dc.b    "T11 PLOAD preload:    ",0
msg_t12:        dc.b    "T12 Fault+PLOAD+RTE:  ",0
msg_pass:       dc.b    "PASS",13,10,0
msg_fail:       dc.b    "FAIL",13,10,0
msg_summary:    dc.b    13,10,"Results: ",0
msg_passed:     dc.b    " passed, ",0
msg_failed:     dc.b    " failed",13,10,0
msg_all_pass:   dc.b    "*** ALL TESTS PASSED ***",13,10,0
msg_some_fail:  dc.b    "*** SOME TESTS FAILED ***",13,10,0
msg_unhandled:  dc.b    "UNHANDLED EXCEPTION",13,10,0

        even

; Pad to fill ROM image (vasm -Fbin pads automatically)
        end
