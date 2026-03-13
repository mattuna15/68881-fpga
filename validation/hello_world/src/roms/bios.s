* \1,\2 = MNEUMONIC (\2 SIGN BIT SET AS LAST CHARACTER)
* \3    = INDEX TO TABLKEYS
* \4,\5 = FIRST WORD MASK
* \6    = NO OPERAND ALLOWED IF SIGN SET
* \7    = .S ALLOWED (.W NOT ALLOWED)
OPC      MACRO
         DC.B    '\1','\2'+128
         DC.B    \3+\6+\7,$\4,$\5
         ENDM
         
; Use EASy68k Simulator
EASY68K_SIM	EQU 0		; set 0 to use ACIA1
;EASY68K_SIM	EQU 1		; set 1 to use EASy68K Sim68K I/O  
****************************************
*   Addresses			

ROMBAS		EQU	$FE0000		ROM BASE ADDRESS		
RAMBAS		EQU	$400		RAM BASE ADDRESS		
STACK		EQU	$1000	INITIAL STACK POINTER $F007AA	
MFPBAS		EQU	$FD0000		MFP BASE ADDRESS		
MFPVCT		EQU	$40		VECTOR FOR MFP SOURCED INTERRUPT

****************************************
*   Defines			

NOP		EQU	$4E71		STANDARD 68000 NOP INSTRUCTION	
MAX_LINELEN	EQU	80	

****************************************
*   MC68901 MFP Registers	

MFPGPDR		EQU	MFPBAS+$1	GPIO DATA REGISTER		
MFPAER		EQU	MFPBAS+$3	ACTIVE EDGE REGISTER		
MFPDDR		EQU     MFPBAS+$5	DATA DIRECTION REGISTER		
MFPIERA		EQU     MFPBAS+$7	INTERRUPT ENABLE REGISTER A	
MFPIERB 	EQU     MFPBAS+$9	INTERRUPT ENABLE REGISTER B	
MFPIPRA		EQU     MFPBAS+$B	INTERRUPT PENDING REGISTER A	
MFPIPRB		EQU     MFPBAS+$D	INTERRUPT PENDING REGISTER B	
MFPISRA		EQU     MFPBAS+$F	INTERRUPT IN SERVICE REGISTER A	
MFPISRB		EQU     MFPBAS+$11	INTERRUPT IN SERVICE REGISTER B	
MFPIMRA		EQU     MFPBAS+$13	INTERRUPT MASK REGISTER A	
MFPIMRB		EQU     MFPBAS+$15	INTERRUPT MASK REGISTER B	
MFPVR		EQU     MFPBAS+$17	VECTOR REGISTER
MFPTACR		EQU     MFPBAS+$19	TIMER A CONTROL REGISTER	
MFPTBCR		EQU     MFPBAS+$1B	TIMER B CONTROL REGISTER	
MFPTCDCR	EQU     MFPBAS+$1D	TIMER C/D CONTROL REGISTER	
MFPTADR		EQU     MFPBAS+$1F	TIMER A DATA REGISTER		
MFPTBDR		EQU     MFPBAS+$21	TIMER B DATA REGISTER		
MFPTCDR		EQU     MFPBAS+$23	TIMER C DATA REGISTER		
MFPTDDR		EQU     MFPBAS+$25	TIMER D DATA REGISTER		
MFPSCR		EQU     MFPBAS+$27	SYNCHRONOUS CHARACTER REGISTER	
MFPUCR		EQU     MFPBAS+$29	USART CONTROL REGISTER		
MFPRSR		EQU     MFPBAS+$2B	RECEIVER STATUS REGISTER	
MFPTSR		EQU     MFPBAS+$2D	TRANSMITTER STATUS REGISTER	
MFPUDR		EQU     MFPBAS+$2F	USART DATA REGISTER		
	
****************************************
*   ASCII Equates		
NOC      EQU     $80            (BIT 7 SET) NO OPERAND
NW       EQU     $40            (BIT 6 SET) .W NOT ALLOWED

CTRLC		EQU	$03	
BEL		EQU	$07	
BKSP		EQU	$08		CTRL-H
TAB		EQU	$09	
LF		EQU	$0A								     ***********
CR		EQU	$0D
CTRLX		EQU	$18								       *******
ESC		EQU	$1B	
BLANK    EQU     $20
EOT      EQU     $04
BELL     EQU     $07
BKPOINT  EQU     $4AFB
BUFFSIZE EQU     $80
BUFSIZE  EQU     80

CTLC     EQU     $03
CTLD     EQU     $04
CTLH     EQU     $08
CTLW     EQU     $17
CTLX     EQU     $18
DEL      EQU     $7F
DELAYC1  EQU     $1000
LOCVARSZ EQU     16

****************************************
*   Variables			

varCurAddr	EQU	RAMBAS	
varLast		EQU	varCurAddr

		ORG    RAMBAS+2
    
*********************
* SYSTEM STACK AREA *
*********************
BUFFER   DS.B    BUFFSIZE
         DS.W    0              FORCE ON WORD BOUNDRY
         DS.B    300            ROOM FOR STACK
SYSTACK  DS.W    1              START OF STACK (ADDRESS DECREASES)
         DS.B    4              STRETCHED STACK (USED BY 'SAVE')

         DS.B    120            EXTENDED AREA USED IF DISASSEMBLER

    *CODE68K
OFFSET   DS.L    8              ASSUMED OFFSETS (VIA "R@" FORMAT)
DATASTR  EQU *
ESKB     DS      0
TDATA    DS.B    18
TNB      DS.B    1
TLSPEC   DS.B    1
TLENGTH  DS.W    1
PCOUNTER DS.L    1
PTROP    DS.L    1              POINTER TO OPERAND
PENDOP   DS.L    1              POINTER END OF OPERAND
PTRBUFE  DS.L    1              POINTER TO END OF FORMATED SOURCE
LINK     DS.L    1              SAVE FOR UNLINK
FPUSCR   DS.W    2              FPU assembler scratch (opcode + temp)
ESKE     DS.B    0


*DCODE68K
DDATA    DS.L    3
HISPC    DS.L    1

LINEBUF   DS.B    BUFFSIZE
varLineBuf DS.B   MAX_LINELEN+2    Relocated from vector table area
PROGCNT   DS.L   1
ECHO_ON	  DS.B 1
PROMPT_ON DS.B 1
LF_DISPLAY DS.B 1

* Saved registers from last G(o) command
         EVEN
SAVED_D  DS.L    8              D0-D7
SAVED_A  DS.L    7              A0-A6
SAVED_SP DS.L    1              A7/SP
SAVED_PC DS.L    1              PC (return address)
SAVED_SR DS.W    1              SR
SAVED_FP DS.B    12*8           FP0-FP7 (12 bytes each, extended format)
REGS_VALID DS.B  1              Non-zero if saved registers are valid

         EVEN
* Debug/trace state
TRACECNT  DS.W    1              >0=instructions left, 0=stopped, -1=single-step-resume
DEBUG_ON  DS.B    1              Non-zero = debug mode active
         EVEN
* Breakpoint table: 8 regular + 1 temporary
NUMBP     EQU     8
BPADD    DS.L    NUMBP           Breakpoint addresses (0=unused)
BPDATA   DS.W    NUMBP           Saved original words
BPCNT    DS.W    NUMBP           Pass counts (0=break every hit)
BPTADD   DS.L    1               Temporary breakpoint address
BPTDATA  DS.W    1               Temporary BP saved word

*****************************************************************************************************
*	Program section		
*	The ROM in this BIOS is mapped to the variable
*	ROMBAS.  All executable code is resident in ROM.		

START		EQU	ROMBAS
            org ROMBAS	
			or.w #$0700,SR   
ROMSTART	EQU	*		BEGINNING OF PROGRAM SECTION	
	*	MOVE.L	#RAMBAS,D0	POINT TO BASE OF RAM		
	*	MOVEC.L	D0,VBR		AND INITIALIZE VBR TO POINT THERE

****************************************
*	Initialize the MC68901 MFP

		BSR.W	MFPINIT		DO SO AS SUBROUTINE FOR LATER USE

****************************************
*	Initialize the TRAP vectors
		BSR.W	setTrap1	Initialize MFP GPIO TRAP1 vector
		BSR.W	setTrap15	Initialize IO TRAP15 vector
		BSR.W	setExcVectors	Initialize fault vectors 2-7
		BSR.W	setDebugVectors	Install trace + illegal vectors

WARMSTART
	IFEQ	EASY68K_SIM
		MOVE.B #1,ECHO_ON
	ENDC
	IFNE	EASY68K_SIM
		CLR.B  ECHO_ON
	ENDC
		MOVE.B #1,PROMPT_ON
		MOVE.B #1,LF_DISPLAY
		CLR.B  REGS_VALID
		CLR.W  TRACECNT
		CLR.B  DEBUG_ON
		LEA    BPADD,A0
		MOVEQ  #NUMBP-1,D0
.clrbp		CLR.L  (A0)+
		DBRA   D0,.clrbp
		CLR.L  BPTADD

		LEA.L	msgBanner,A0	Print Banner    ****
		BSR.W	printString  **********************
		MOVE.B #1,D1
		MOVE.B #16,D0
		TRAP #15
		
PROMPT		LEA.L	msgPrompt,A0	Print prompt************************
		BSR.W	printString  **********************
		BSR.W	readLine	Get User Input    ****		*****
		BSR.W	convertCase	Convert to upper-case		      **		*****
		BSR.W	parseLine	Then parse user input		

		BRA.S	PROMPT	



*****************************************************************************************************
*****************************************************************************************************
* EXCEPTION HANDLERS		

****************************************
*   Generic Exception Handler	

EXCHND		EQU	*		GENERIC EXCEPTION HANDLER
		RTE

****************************************
*   Fault Exception Handler
*   Prints "FAULT AT $xxxxxx" and returns to monitor prompt

excFault	LEA.L	msgFault,A0
		BSR.W	printString
		MOVE.L	2(A7),D0	Get PC from exception frame
		BSR.W	printHexLong	Print fault PC
		LEA.L	msgNewline,A0
		BSR.W	printString
		BRA	WARMSTART	Return to monitor

****************************************
*   MFP Exception Handler	
MFPEXC		EQU	*
		RTE

*****************************************************************************************************
* DEVICE SECTION		

****************************************
*  MC68901 INITIALIZATION	


MFPINIT		EQU	*		MC68901 INITIALIZATION ROUTINE	
    * GPIOs
    move.b  #$FF,MFPDDR              * All GPIOs are output
	move.b  #$00,MFPGPDR             * Turn off GPIO #0 (Green LED)
    
    * Timer setup - Timer D controls serial clock,C is kernel tick
    move.b  #$5C,MFPTCDR             * Timer C count is 92 for 50Hz (interrupt on rise and fall so 100Hz)
    move.b  #$18,MFPTDDR             * Timer D count is 24 for (19.2KHz,divided by 2 for 9600 baud)
    move.b  #$71,MFPTCDCR            * Enable timer C with /200 and D with /4 prescaler
    
    * USART setup
    move.b  #$08,MFPUCR              * Fundamental clock,async,8N1
    move.b  #$05,MFPTSR              * Set pin state high and enable transmitter

    * Interrupt setup - Enable timer C interrupt for kernel tick
    move.l  #MFPVCT,D0           * Set up the base MFP vector at 0x40 (first 16 user vectors)...
    or.l    #8,D0                     * ... and set software-end-of-interrupt mode
    move.b  D0,MFPVR                 * ... then write to MFP vector register
    or.b    #$20,MFPIERB             * Enable Timer C interrupt,but leave it masked for now
                                      * (kmain will call START_HEART later)
	LEA.L	OKMSG,A0
	BSR.W   printString

    * Indicate success and return
    move.b  #$01,MFPGPDR             * Turn on GPIO #0 (Green LED)
	RTS
												  *
*****************************************************************************************************
* SUBROUTINE SECTION		

*					This is ugly as hell,I am looking at the BCD functions	*****
*					supported by the CPU to clean this up a bit		*****
printVal	MOVEM.L	D1-D3,-(SP)	Store register contents		
			EOR.L	D1,D1		Clear D1,will store character to be written		*****
			EOR.L	D2,D2		Clear D2,will be zero until first character written	*****
.loop10000	CMPI.W	#$2710,D3	Compare to 10000		
			BCS.S	.print10000	Branch if less than		
			SUBI.W	#$2710,D3	Subtract 10000
			ADDI.B	#$1,D1		Increment digit to be written	
			BRA.S	.loop10000	Repeat until less than 10000	

.print10000	BSR.S	.printChar
			EOR.L	D1,D1		Clear D1,will store character to be written		*****
.loop1000	CMPI.W	#$3E8,D3	Compare to 1000
			BLT.S	.print1000	Branch if less than		
			SUBI.W	#$3E8,D3	Subtract 1000
			ADDI.B	#$1,D1		Increment digit to be written	
			BRA.S	.loop1000	Repeat until less than 1000	

.print1000	BSR.S	.printChar
			EOR.L	D1,D1		Clear D1,will store character to be written		*****
.loop100	CMPI.W	#$64,D3		Compare to 100
			BLT.S	.print100	Branch if less than		
			SUBI.W	#$64,D3		Subtract 100
			ADDI.B	#$1,D1		Increment digit to be written	
			BRA.S	.loop100	Repeat until less than 100	

.print100	BSR.S   .printChar      
            EOR.L   D1,D1           Clear D1,will store character to be written		*****
.loop10		CMPI.W	#$A,D3		Compare to 10
			BLT.S	.print10	Branch if less than		
			SUBI.W	#$A,D3		Subtract 10
			ADDI.B	#$1,D1		Increment digit to be written	
			BRA.S	.loop10		Repeate until less than 10	

.print10	BSR.S   .printChar
            MOVE.B   D3,D1		Clear D1,will store character to be written		*****			**
			BSR.S	.continue	No need to loop on 1s digit				****
			MOVEM.L	(SP)+,D1-D3	Restore register contents******
			RTS			GTFO***************************
												
.printChar	TST.B	D1		Test if digit is zero					****
			BNE.S	.continue	Print if not			**
			TST.B	D2		Else test if this would be first printed digit		*****
			BNE.S	.continue	Print if not
			RTS			Else return without zero-padding

.continue	ADDI.B	#'0',D1		Convert to ASCII		
.wait		BTST.B  #7,MFPTSR	Check for empty transmit buffer	
        	BEQ.S   .wait		Loop until ready		
            MOVE.B  D1,MFPUDR	Put character into USART data register
			MOVE.B	#$1,D2		Mark first character as written to avoid zero-padding	*****

.end            RTS                     ELSE RETURN WHEN COMPLETED	


**************************							
* MFP Transmit/Receive										
*	
*************************
printString	EQU	*	
.loop		MOVE.B	(A0)+,D0	Read character data			
		BEQ.S	.printEnd	Check for null terminator			**
		BSR.S	outChar		Write the character				****
		BRA.S	.loop		Loop until null found		*****************
.printEnd	RTS		

    IFEQ	EASY68K_SIM
outChar
    btst.b  #7,MFPTSR                * Is transmit buffer empty?
    beq.s   outChar               * Busywait if not
    
    move.b  D0,MFPUDR
    rts

inChar
    btst.b  #7,MFPRSR                * Is receive buffer empty?
    beq.s   inChar               * Busywait if not
    
    MOVE.B  MFPUDR,D0
    rts
    
    ENDC
    
    IFNE	EASY68K_SIM

outChar   MOVEM.L D0-D1,-(SP)  ; SAVE D1
          MOVE.B D0,D1
          MOVE.B #6,D0
          TRAP #15
          MOVEM.L (SP)+,D0-D1 ; RESTORE D1
          RTS


inChar    MOVE.L D1,-(SP)  ; SAVE D1
          MOVE.B #5,D0
          TRAP #15
          MOVE.B D1,D0  ;ACIAD.L,D0
          MOVE.L (SP)+,D1 ; RESTORE D1
          RTS

    ENDC
**********************
* read line
************************
		
readLine	
			MOVEM.L	D2/A2,-(SP)	Preserve registers which will be modified		
			LEA	varLineBuf,A2	Point to start of lineBuffer	
			EOR.W	D2,D2		Clear the character counter
.loop		BSR.S	inChar		Read a character from the UART buffer
		CMP.B	#BKSP,D0	Is user having difficulty typing?
		BEQ.S	.backspace
		CMP.B	#CTRLX,D0	Is user having second thoughts?	
		BEQ.S	.lineclear
		CMP.B	#CR,D0		Did the user finally make up their mind?		*****
		BEQ.S	.endline
		CMP.B	#LF,D0		We don't care about LFs... everything else continues	*****
		BEQ.S	.loop		and doesn't make this loop back	
.char		CMP.W	#MAX_LINELEN,D2	If the line is too long...
		BGE.S	.loop		...we're going to stop listening to the user		*****
		MOVE.B	D0,(A2)+	Otherwise,store character
		ADDQ.W	#1,D2		...and increment character count
		TST.B	ECHO_ON		Echo enabled?
		BEQ.S	.loop		No — skip echo (Easy68K terminal echoes for us)
		BSR.S	outChar		Local echo
		BRA.S	.loop		Get next character		
.backspace	TST.W	D2		Are we at beginning of the line?
		BEQ.S	.loop		If so,user has doublefailed and we'll ignore BKSP	*****
*					but seriously,we should send a BEL just for insult	*****
		SUBQ.L	#1,A2		Move back in buffer one space
		SUBQ.L	#1,D2		And reduce character count by one
		TST.B	ECHO_ON		Echo enabled?
		BEQ.S	.loop		No — terminal handles its own backspace
		BSR.S	outChar		Remove the previous character from the user's console	*****
		MOVE.B	#' ',D0		*via a complex and convoluted process of writing a space	*****
		BSR.S	outChar		after going back a space...
		MOVE.B	#BKSP,D0	...and going back a space again
		BSR.S	outChar		just to keep things tidy.
		BRA.S	.loop		Get next character		
.lineclear	TST	D2		Is there even data to clear?	
		BEQ.S	.loop		If not,just ignore and fetch next character		*****
		SUBA.L	D2,A2		Return to start of the buffer	
.lineclearloop	MOVE.B	#BKSP,D0
		BSR.W	outChar		Backspace...
		MOVE.B	#' ',D0	
		BSR.W	outChar		Spaaaaaaaaaaaaace....		
		MOVE.B	#BKSP,D0
		BSR.W	outChar		Backspace...
		SUBQ.W	#1,D2		Decrement character count	
		BNE.S	.lineclearloop	Repeat until start of line	
		BRA.S	.loop	
.endline	BSR.W	outChar		Echo the character		
		MOVE.B	#LF,D0	
		BSR.W	outChar		Throwing in a free LF for good measure
		MOVE.B	#0,(A2)		Add null terminator...				**
		MOVEA.L	A2,A0		Ready the pointer to get to the choppah		****
		move.l d2,d1
		MOVEM.L	(SP)+,D2/A2	Restore registers******
		RTS									

convertCase	
		LEA	varLineBuf,A0	Get start of line	
.loop		
		MOVE.B	(A0),D0
		CMP.B	#'a',D0		Check if less than 'a'	
		BLT.S	.next	
		CMP.B	#'z',D0		Check if greater than 'z'	
		BGT.S	.next	
		SUB.B	#$20,D0		Convert to upper-case				**
.next		MOVE.B	D0,(A0)+	Store the character back in A0,move to next		*****		****
		BNE.S	.loop		Loop until null terminator
		RTS									

parseLine	
		MOVEM.L	A2-A3,-(SP)	Save registers
		LEA varLineBuf,A0	Get start of line	
.findCommand	MOVE.B	(A0)+,D0     
		CMP.B	#' ',D0		*Ignore spaces
		BEQ.W	.findCommand
		CMP.B	#'E',D0		EXAMINE
		BEQ.W	.examine
		CMP.B	#'D',D0		DEPOSIT
		BEQ.W	.deposit
		CMP.B	#'G',D0		GO (execute)
		BEQ.W	.run
		CMP.B	#'R',D0		REGISTERS
		BEQ.W	.regs
		CMP.B	#'H',D0		HELP
		BEQ.W	.help	
		CMP.B	#'L',D0		*LOAD
		BEQ.W	load
		CMP.B	#'A',D0		*Assemble
		Beq  	assemble
		CMP.B	#'T',D0		TRACE
		BEQ.W	.trace
		CMP.B	#'B',D0		BREAKPOINT
		BEQ.W	.breakpoint
		CMP.B	#'N',D0		NO BREAKPOINT (clear)
		BEQ.W	.noBreak
		CMP.B	#0,D0		BLANK LINE
		BEQ.S	.exit
	
.invalid	LEA	msgNoCMD,A0		**
		BSR.W	printString		****			
.exit		MOVEM.L	(SP)+,A2-A3	Restore registers		*****************		
		RTS	

****************************************		**
*   Examine			
*
*   Modes:	e ADDR			Display a single byte		
*		e ADDR.			Display a single page (16 lines,256 bytes)		*****
*		e ADDR-ADDR		Display all bytes between the two addresses		*****
*		e ADDR+LEN		Displays LEN bytes following ADDR
*		e ADDR;			Interactive mode: SPACE shows 16 lines,ENTER shows 1	*****

.examine	BSR.W	parseNumber	Read start address			
		TST.B	D1		Non-zero return on invalid address
		BNE.W	.invalidAddr
		MOVE.L	D0,A3		Save the start address		
.exloop		MOVE.B	(A0)+,D0
		CMP.B	#' ',D0		Ignore spaces
		BEQ.S	.exloop	
		CMP.B	#'-',D0		Check if range specified	
		BEQ.S	.exrange
		CMP.B	#'+',D0		Check if lenth specified	
		BEQ.S	.exlength
		CMP.B	#';',D0		Check if interactive requested	
		BEQ.S	.exinter
		CMP.B	#'.',D0		Check if quick 16 is requested	
		BEQ.S	.exquick
		MOVE.L	#1,D0		Otherwise read a single byte	
		BRA.S	.exend	
.exrange	BSR.W	parseNumber	Find the ending address		
		TST.B	D1		Non-zero return on invalid address
		BNE.W	.invalidAddr
		SUB.L	A3,D0		Get the length
		BRA.S	.exend	
.exquick	MOVE.L	#$10,D0	
		BRA.S	.exend	
.exlength	BSR.W	parseNumber	Find the length
		TST.B	D1		Non-zero return on invalid address
		BNE.W	.invalidAddr
.exend		MOVE.L	A3,A0		Parameter parsing complete,pass to dumpRAM and return	*****
		BSR.W	dumpRAM	
		BRA.S	.exit	
.exinter	MOVE.L	A3,A0		Interactive mode,set current address
		MOVE.L	#$10,D0		16 bytes
		BSR.W	dumpRAM	
		ADD.L	#$10,A3		Move current address up 16 bytes
.exinterend	BSR.W	inChar	
		CMP.B	#CR,D0		Display another line		
		BEQ.S	.exinter
		CMP.B	#' ',D0		Display a page (256 bytes)	
		BEQ.S	.exinterpage
		CMP.B	#LF,D0		Disregard linefeeds		
		BEQ.S	.exinterend	Fetch new character on LF	
		BRA.S	.exit		Else exit on any other character
.exinterpage	MOVE.L	A3,A0	
		MOVE.L	#$100,D0	256 bytes
		BSR.W	dumpRAM		Dump 16 lines
		ADD.L	#$100,A3	Adjust current address to match	
		BRA.S	.exinterend
												  *
												  *
.deposit	MOVE.B	(A0),D0	
		CMP.B	#':',D0		Check if continuing from previous address		*****
		BEQ.S	.depCont

		BSR.W	parseNumber	Read the address		
		TST.B	D1		Make certain that it is valid	
		BNE	.invalidAddr

		MOVE.L	D0,A3		Save starting address		
.depLoop	MOVE.B	(A0),D0	
		CMP.B	#';',D0		Check for multi-line continuation
		BEQ.S	.depMultiline
		TST	D0		Check for end of line		
		BEQ	.depEnd	

		BSR.W	parseNumber	Read value
		TST.B	D1		Test for validity
		BNE.W	.invalidVal

		MOVE.B	D0,(A3)+	Store the value into memory	
		BRA.S	.depLoop	...and fetch next value		

.depCont	MOVE.L	varCurAddr,A3	Read in the previous address	
		ADDQ.L	#1,A0		Skip over the ':'		
		BRA.S	.depLoop	...and fetch next value		

.depMultiline	LEA	msgDepPrompt,A0
		BSR.W	printString
		BSR.W	readLine	Read in the next line to be parsed
		BSR.W	convertCase	Convert case
		LEA	varLineBuf,A0	Reset buffer pointer		
		BRA.S	.depLoop	Jump back to decoding		

.depEnd		MOVE.L	A3,varCurAddr
		BRA.W	.exit	
												  *
												  *
.run		BSR.W	parseNumber	Read in the address
		TST.B	D1		Test for validity
		BNE 	.invalidAddr
		MOVE.L	D0,SAVED_PC     Save target PC
* Check if any breakpoints are active
		LEA	BPADD,A2
		MOVEQ	#NUMBP-1,D1
.gChk		TST.L	(A2)+
		BNE.S	.runDebug
		DBRA	D1,.gChk
* No breakpoints — simple JSR mode (backward compatible)
		MOVE.L	SAVED_PC,A0
		JSR	(A0)		Wheeeeeeeeeeeeeeeeeeeee!!!!
* Save registers from user program return
		MOVEM.L	D0-D7/A0-A6,SAVED_D Save D0-D7 and A0-A6
		MOVE.L	A7,SAVED_SP     Save SP
		MOVE.W	SR,SAVED_SR     Save SR
* Save FP0-FP7 via FMOVE.X FPn,d(A0) — hand-encoded F-line opcodes
* (vasm M68000 mode doesn't support FPU mnemonics)
* Opword=$F228 (FPU, EA=d16(A0)), Cmdword=$6800|(n<<7), Disp=offset
	IFEQ	EASY68K_SIM
		LEA	SAVED_FP,A0
		DC.W	$F210,$6800             FMOVE.X FP0,(A0)
		DC.W	$F228,$6880,$000C       FMOVE.X FP1,12(A0)
		DC.W	$F228,$6900,$0018       FMOVE.X FP2,24(A0)
		DC.W	$F228,$6980,$0024       FMOVE.X FP3,36(A0)
		DC.W	$F228,$6A00,$0030       FMOVE.X FP4,48(A0)
		DC.W	$F228,$6A80,$003C       FMOVE.X FP5,60(A0)
		DC.W	$F228,$6B00,$0048       FMOVE.X FP6,72(A0)
		DC.W	$F228,$6B80,$0054       FMOVE.X FP7,84(A0)
	ENDC
		MOVE.B	#1,REGS_VALID   Mark registers as valid
		BRA.W	.exit           Return to prompt (not WARMSTART)
.runDebug
* Debug mode — RTE-based execution with breakpoints
		MOVE.W	SR,SAVED_SR
		ANDI.W	#$7FFF,SAVED_SR  Clear T bit initially
		TST.B	REGS_VALID
		BNE.S	.gKeep
* First run — zero out saved regs
		LEA	SAVED_D,A0
		MOVEQ	#14,D0		15 longs (D0-D7 + A0-A6)
.gClr		CLR.L	(A0)+
		DBRA	D0,.gClr
.gKeep		MOVE.B	#1,REGS_VALID
		MOVE.B	#1,DEBUG_ON
		ORI.W	#$8000,SAVED_SR  Set T bit for single-step past potential BP at PC
		MOVE.W	#-1,TRACECNT     -1 = single-step-then-SWAPIN
		LEA	SYSTACK,A7
		BRA	unstack
*
* Trace command
*
.trace		TST.B	REGS_VALID
		BEQ.S	.traceNeedPC
* Parse optional count (default 1)
		BSR.W	parseNumber
		TST.B	D1		Non-zero = no number provided
		BEQ.S	.traceGo
		MOVEQ	#1,D0		Default: trace 1 instruction
.traceGo	MOVE.W	D0,TRACECNT
		ORI.W	#$8000,SAVED_SR  Set T bit
		LEA	SYSTACK,A7	Reset stack (won't return to parseLine)
		BRA	unstack
.traceNeedPC	LEA	msgNoRegs,A0
		BSR.W	printString
		BRA.W	.exit
*
* Breakpoint command
*
.breakpoint	MOVE.B	(A0),D0
		BEQ.S	.bpDisplay	No arg = display
		CMP.B	#' ',D0
		BNE.S	.bpParse
		ADDQ.L	#1,A0		Skip space
		MOVE.B	(A0),D0
		BEQ.S	.bpDisplay	Space only = display
.bpParse	BSR.W	parseNumber
		TST.B	D1
		BNE.W	.invalidAddr
		MOVE.L	D0,D3		Save address
		MOVEQ	#0,D4		Default pass count = 0
		CMP.B	#';',(A0)
		BNE.S	.bpSet
		ADDQ.L	#1,A0		Skip semicolon
		BSR.W	parseNumber
		MOVE.W	D0,D4
.bpSet		LEA	BPADD,A2
		LEA	BPCNT,A3
		MOVEQ	#NUMBP-1,D1
.bpFind		CMP.L	(A2),D3
		BEQ.S	.bpUpdate	Already exists — update count
		TST.L	(A2)
		BEQ.S	.bpSlot		Empty slot
		ADDQ.L	#4,A2
		ADDQ.L	#2,A3
		DBRA	D1,.bpFind
		LEA	msgBPfull,A0
		BSR.W	printString
		BRA.W	.exit
.bpSlot		MOVE.L	D3,(A2)
.bpUpdate	MOVE.W	D4,(A3)
		BRA.W	.exit
.bpDisplay	LEA	BPADD,A2
		LEA	BPCNT,A3
		MOVEQ	#0,D4
.bpDlp		MOVE.L	(A2)+,D0
		BEQ.S	.bpDnx
		BSR.W	printHexLong
		MOVE.W	(A3),D1
		BEQ.S	.bpDnc
		LEA	msgBPcnt,A0
		BSR.W	printString
		CLR.L	D0
		MOVE.W	(A3),D0
		BSR.W	printHexWord
.bpDnc		LEA	msgNewline,A0
		BSR.W	printString
.bpDnx		ADDQ.L	#2,A3
		ADDQ.L	#1,D4
		CMP.B	#NUMBP,D4
		BNE.S	.bpDlp
		BRA.W	.exit
*
* No-breakpoint (clear) command
*
.noBreak	MOVE.B	(A0),D0
		BEQ.S	.nbrAll		No arg = clear all
		BSR.W	parseNumber
		TST.B	D1
		BNE.W	.invalidAddr
		LEA	BPADD,A2
		MOVEQ	#NUMBP-1,D1
.nbrFind	CMP.L	(A2),D0
		BEQ.S	.nbrGot
		ADDQ.L	#4,A2
		DBRA	D1,.nbrFind
		BRA.W	.exit		Not found — silently ignore
.nbrGot		CLR.L	(A2)
		BRA.W	.exit
.nbrAll		LEA	BPADD,A2
		MOVEQ	#NUMBP-1,D1
.nbrClr		CLR.L	(A2)+
		DBRA	D1,.nbrClr
		CLR.L	BPTADD
		BRA.W	.exit
*
* Register dump
*
.regs		TST.B	REGS_VALID
		BEQ.S	.regsNone
		BSR.W	regDump
		BRA.W	.exit
.regsNone	LEA	msgNoRegs,A0
		BSR.W	printString
		BRA.W	.exit

.help		LEA	msgHelp,A0
		BSR.W	printString
		BRA.W	.exit	
												  *
												  *
.invalidVal	LEA	msgBadVal,A0
		BSR.W	printString
		BRA.W	.exit	

.invalidAddr LEA	msgBadAddr,A0
        BSR.W	printString
        BRA.W	.exit	

parseNumber	EOR.L	D0,D0		Clear D0*******************
		MOVE.B	(A0)+,D0           *******************
		CMP.B	#' ',D0		*Ignore leading spaces	
		BEQ.S	parseNumber
		CMP.B	#'0',D0		Look for hex digits 0-9		
		BLT.S	.invalid
		CMP.B	#'9',D0	
		BLE.S	.firstdigit1
		CMP.B	#'A',D0		Look for hex digits A-F		
		BLT.S	.invalid
		CMP.B	#'F',D0	
		BLE.S	.firstdigit2
.invalid	MOVE.L	#1,D1	
		RTS		
.firstdigit2	SUB.B	#'7',D0		Convert 'A' to 10,and so on	
		BRA.S	.loop	
.firstdigit1	SUB.B	#'0',d0		Convert '0' to 0,and so on	
.loop		MOVE.B	(A0)+,D1	Read in a digit
		CMP.B	#'0',D1		Look for hex digits 0-9		
		BLT.S	.end		End loop on anything else	
		CMP.B	#'9',D1	
		BLE.S	.digit1	
		CMP.B	#'A',D1		Look for hex digits A-F		
		BLT.S	.end	
		CMP.B	#'F',D1	
		BLE.S	.digit2			**
.end		SUBQ.L	#1,A0		Non-hex digit encountered,end parsing		****
		MOVE.L	#0,D1		Move pointer back and clear D1	*****************
		RTS	
.digit2		SUB.B	#'7',D1		Convert 'A' to 10,and so on	*****************
		BRA.S	.digit3			****
.digit1		SUB.B	#'0',D1		Convert '0' to 0,and so on			**
.digit3		LSL.L	#4,D0		Shift to the next nybble	
		ADD.B	D1,D0		Place in our current nybble	
		BRA.S	.loop	

dumpRAM		MOVEM.L	D2-D4/A2,-(SP)	Save registers*******************
		MOVE.L	A0,A2		Save start address	
		MOVE.L	D0,D2		Save number of bytes	
.line		MOVE.L	A2,D0	
		BSR.W	printHexLong	Starting address of the line	
		LEA	msgColonSpc,A0
		BSR.W	printString
		MOVE.L	#16,D3		16 bytes printed on a line	
		MOVE.L	D3,D4		Save number of bytes on this line
.hexbyte	TST.L	D2		Check if out of bytes		
		BEQ.S	.endbytesShort
		TST.B	D3		Check if line is finished	
		BEQ.S	.endbytes
		MOVE.B	(A2)+,D0	Read in a byte from RAM		
		BSR.W	printHexByte	Display it
		MOVE.B	#' ',D0	
		BSR.W	outChar		Separate bytes for readability	
		SUBQ.L	#1,D3	
		SUBQ.L	#1,D2	
		BRA.S	.hexbyte
.endbytesShort	SUB.B	D3,D4		Set D4 to actual number of bytes on this line		*****
		MOVE.B	#' ',D0	
.endbytesShrtLp	TST.B	D3		Check if line ended		
		BEQ.S	.endbytes
		MOVE.B	#' ',D0	
		BSR.W	outChar		Pad end with spaces		
		MOVE.B 	#' ',D0	
		BSR.W	outChar		Pad end with spaces		
		MOVE.B 	#' ',D0	
		BSR.W	outChar		Pad end with spaces		
		SUBQ.B	#1,D3	
		BRA.S	.endbytesShrtLp
.endbytes	SUBA.L	D4,A2		Return to the start address of this line		*****
.endbytesLoop	TST.B	D4		Check if done printing ASCII	
		BEQ	.endline
		SUBQ.B	#1,D4	
		MOVE.B	(A2)+,D0	Read the byte
		CMP.B	#' ',D0		Check if character is in printable range		*****
		BLT.S	.unprintable
		CMP.B	#'~',D0		Highest printable character	
		BGT.S	.unprintable
		BSR.W	outChar	
		BRA.S	.endbytesLoop
.unprintable	MOVE.B	#'.',D0	
		BSR.W	outChar	
		BRA.S	.endbytesLoop
.endline	LEA	msgNewline,A0
		BSR.W	printString
		TST.L	D2	
		BLE.S	.end			**
		BRA.W	.line			****
.end		MOVEM.L	(SP)+,D2-D4/A2	Restore registers		*****************		
		RTS		
	**************

printHexWord	MOVE.L	D2,-(SP)	Save D2
		MOVE.L	D0,D2		Save address in D2		
		ROL.L	#8,D2		4321 -> 3214
		ROL.L	#8,D2		3214 -> 2143
		BRA.S	printHex_WrdEnt	Print last 16 bits		
												 ***
												  *
printHexAddr	MOVE.L	D2,-(SP)	Save D2
		MOVE.L	D0,D2		Save address in D2		
		ROL.L	#8,D2		4321 -> 3214
		BRA.S	printHex_AddEnt	Print last 24 bits		
												 ***
												  *
printHexLong	MOVE.L  D2,-(SP)	Save D2
		MOVE.L  D0,D2		Save the address in D2		
		ROL.L   #8,D2		4321 -> 3214 high byte in low	
		MOVE.L  D2,D0	
		BSR.S   printHexByte	Print the high byte (24-31)	

printHex_AddEnt ROL.L   #8,D2		3214 -> 2143 middle-high byte in low
		MOVE.L  D2,D0              
		BSR.S   printHexByte	Print the high-middle byte (16-23)

printHex_WrdEnt ROL.L   #8,D2		2143 -> 1432 Middle byte in low	
		MOVE.L  D2,D0	
		BSR.S   printHexByte	Print the middle byte (8-15)	
		ROL.L   #8,D2	
		MOVE.L  D2,D0			**
		BSR.S   printHexByte	Print the low byte (0-7)			****			
    		MOVE.L	(SP)+,D2	Restore D2*****************
    		RTS	

printHexByte	MOVE.L	D2,-(SP) *******************
		MOVE.B	D0,D2
		LSR.B	#$4,D0
		ADD.B	#'0',D0	
		CMP.B	#'9',D0		
		BLE.S	.second	
		ADD.B	#7,D0	
.second		BSR.W	outChar	
		ANDI.B	#$0F,D2	
		ADD.B	#'0',D2	
		CMP.B	#'9',D2	
		BLE.S	.end	
		ADD.B	#7,D2	
.end		MOVE.B	D2,D0			**
		BSR.W	outChar			****
		MOVE.L	(SP)+,D2   *****************
		RTS		

****************************************
*  regDump — print saved registers from last G(o) command
*
*  Format:
*    D0=xxxxxxxx D1=xxxxxxxx D2=xxxxxxxx D3=xxxxxxxx
*    D4=xxxxxxxx D5=xxxxxxxx D6=xxxxxxxx D7=xxxxxxxx
*    A0=xxxxxxxx A1=xxxxxxxx A2=xxxxxxxx A3=xxxxxxxx
*    A4=xxxxxxxx A5=xxxxxxxx A6=xxxxxxxx  SP=xxxxxxxx
*      PC=xxxxxxxx SR=xxxx
*     FP0=xxxxxxxx xxxxxxxx xxxxxxxx
*     ...
*     FP7=xxxxxxxx xxxxxxxx xxxxxxxx
*
regDump		MOVEM.L	D3-D5/A2,-(SP)
* --- Data registers D0-D7 ---
		LEA	SAVED_D,A2
		MOVEQ	#0,D4		D4 = register counter
.dloop		MOVE.B	#'D',D0
		BSR.W	outChar
		MOVE.L	D4,D0
		ADD.B	#'0',D0
		BSR.W	outChar
		MOVE.B	#'=',D0
		BSR.W	outChar
		MOVE.L	(A2)+,D0
		BSR.W	printHexLong
		ADDQ.L	#1,D4
		MOVE.L	D4,D3
		ANDI.B	#3,D3		Newline every 4 regs
		BNE.S	.dsp
		LEA	msgNewline,A0
		BSR.W	printString
		BRA.S	.dnext
.dsp		MOVE.B	#' ',D0
		BSR.W	outChar
.dnext		CMPI.B	#8,D4
		BNE.S	.dloop
* --- Address registers A0-A6 ---
		LEA	SAVED_A,A2
		MOVEQ	#0,D4
.aloop		MOVE.B	#'A',D0
		BSR.W	outChar
		MOVE.L	D4,D0
		ADD.B	#'0',D0
		BSR.W	outChar
		MOVE.B	#'=',D0
		BSR.W	outChar
		MOVE.L	(A2)+,D0
		BSR.W	printHexLong
		ADDQ.L	#1,D4
		MOVE.L	D4,D3
		ANDI.B	#3,D3
		BNE.S	.asp
		LEA	msgNewline,A0
		BSR.W	printString
		BRA.S	.anext
.asp		MOVE.B	#' ',D0
		BSR.W	outChar
.anext		CMPI.B	#7,D4
		BNE.S	.aloop
* --- SP ---
		LEA	msgSP,A0
		BSR.W	printString
		MOVE.L	SAVED_SP,D0
		BSR.W	printHexLong
		LEA	msgNewline,A0
		BSR.W	printString
* --- PC and SR ---
		LEA	msgPC,A0
		BSR.W	printString
		MOVE.L	SAVED_PC,D0
		BSR.W	printHexLong
		LEA	msgSR,A0
		BSR.W	printString
		CLR.L	D0
		MOVE.W	SAVED_SR,D0
		BSR.W	printHexWord
		LEA	msgNewline,A0
		BSR.W	printString
* --- FP0-FP7 (extended: 3 x 32-bit words each) ---
	IFEQ	EASY68K_SIM
		LEA	SAVED_FP,A2
		MOVEQ	#0,D4
.fploop		LEA	msgFPpfx,A0
		BSR.W	printString
		MOVE.L	D4,D0
		ADD.B	#'0',D0
		BSR.W	outChar
		MOVE.B	#'=',D0
		BSR.W	outChar
		MOVE.L	(A2)+,D0	Exponent word (sign+exp in upper 16)
		BSR.W	printHexLong
		MOVE.B	#' ',D0
		BSR.W	outChar
		MOVE.L	(A2)+,D0	Significand high
		BSR.W	printHexLong
		MOVE.B	#' ',D0
		BSR.W	outChar
		MOVE.L	(A2)+,D0	Significand low
		BSR.W	printHexLong
		LEA	msgNewline,A0
		BSR.W	printString
		ADDQ.L	#1,D4
		CMPI.B	#8,D4
		BNE.S	.fploop
	ENDC
*
		MOVEM.L	(SP)+,D3-D5/A2
		RTS

****************************************
*  setDebugVectors — install trace and illegal instruction vectors
*
setDebugVectors
		LEA	traceHandler,A0
		MOVE.L	A0,$0024	Vector 9: Trace
		LEA	illegalHandler,A0
		MOVE.L	A0,$0010	Vector 4: Illegal instruction
		RTS

****************************************
*  saveRegs — save all registers from exception context
*  Called via BSR from handler, so stack is:
*    (A7)+0: BSR return address (4 bytes)
*    (A7)+4: SR from exception  (2 bytes)
*    (A7)+6: PC from exception  (4 bytes)
*
saveRegs	MOVEM.L	D0-D7/A0-A6,SAVED_D
		MOVE.L	A7,A0
		ADDQ.L	#4,A0		Skip BSR return address
		MOVE.W	(A0),SAVED_SR	SR from exception frame
		MOVE.L	2(A0),SAVED_PC	PC from exception frame
		ADDQ.L	#6,A0		Skip exception frame
		MOVE.L	A0,SAVED_SP	Save user SP (past all frames)
	IFEQ	EASY68K_SIM
		LEA	SAVED_FP,A0
		DC.W	$F210,$6800             FMOVE.X FP0,(A0)
		DC.W	$F228,$6880,$000C       FMOVE.X FP1,12(A0)
		DC.W	$F228,$6900,$0018       FMOVE.X FP2,24(A0)
		DC.W	$F228,$6980,$0024       FMOVE.X FP3,36(A0)
		DC.W	$F228,$6A00,$0030       FMOVE.X FP4,48(A0)
		DC.W	$F228,$6A80,$003C       FMOVE.X FP5,60(A0)
		DC.W	$F228,$6B00,$0048       FMOVE.X FP6,72(A0)
		DC.W	$F228,$6B80,$0054       FMOVE.X FP7,84(A0)
	ENDC
		MOVE.B	#1,REGS_VALID
		RTS

****************************************
*  unstack — restore all registers and RTE to user code
*
unstack
	IFEQ	EASY68K_SIM
		LEA	SAVED_FP,A0
* FMOVE.X d(A0),FPn — hand-encoded (EA=d16(A0), direction=memory-to-reg)
		DC.W	$F210,$4800             FMOVE.X (A0),FP0
		DC.W	$F228,$4880,$000C       FMOVE.X 12(A0),FP1
		DC.W	$F228,$4900,$0018       FMOVE.X 24(A0),FP2
		DC.W	$F228,$4980,$0024       FMOVE.X 36(A0),FP3
		DC.W	$F228,$4A00,$0030       FMOVE.X 48(A0),FP4
		DC.W	$F228,$4A80,$003C       FMOVE.X 60(A0),FP5
		DC.W	$F228,$4B00,$0048       FMOVE.X 72(A0),FP6
		DC.W	$F228,$4B80,$0054       FMOVE.X 84(A0),FP7
	ENDC
		MOVE.L	SAVED_SP,A7	Set SSP to user's stack
		MOVE.L	SAVED_PC,-(A7)	Push PC for RTE frame
		MOVE.W	SAVED_SR,-(A7)	Push SR for RTE frame
		MOVEM.L	SAVED_D,D0-D7/A0-A6  Restore all work regs (absolute EA, A7 preserved)
		RTE			Pop SR+PC, jump to user

****************************************
*  swapIn — plant breakpoint opcodes into user code
*
swapIn		MOVEM.L	D0-D1/A0-A2,-(A7)
		LEA	BPADD,A0
		LEA	BPDATA,A1
		MOVEQ	#NUMBP-1,D0
.loop		MOVE.L	(A0)+,D1
		BEQ.S	.skip
		MOVE.L	D1,A2
		MOVE.W	(A2),(A1)	Save original word
		MOVE.W	#BKPOINT,(A2)	Plant $4AFB
.skip		ADDQ.L	#2,A1
		DBRA	D0,.loop
		MOVE.L	BPTADD,D1	Temporary BP
		BEQ.S	.done
		MOVE.L	D1,A2
		MOVE.W	(A2),BPTDATA
		MOVE.W	#BKPOINT,(A2)
.done		MOVEM.L	(A7)+,D0-D1/A0-A2
		RTS

****************************************
*  swapOut — restore original code at breakpoint locations
*
swapOut		MOVEM.L	D0-D1/A0-A2,-(A7)
		LEA	BPADD,A0
		LEA	BPDATA,A1
		MOVEQ	#NUMBP-1,D0
.loop		MOVE.L	(A0)+,D1
		BEQ.S	.skip
		MOVE.L	D1,A2
		MOVE.W	(A1),(A2)	Restore original word
.skip		ADDQ.L	#2,A1
		DBRA	D0,.loop
		MOVE.L	BPTADD,D1
		BEQ.S	.done
		MOVE.L	D1,A2
		MOVE.W	BPTDATA,(A2)
		CLR.L	BPTADD		One-shot
.done		MOVEM.L	(A7)+,D0-D1/A0-A2
		RTS

****************************************
*  disasmNext — disassemble instruction at SAVED_PC using DCODE68K
*
disasmNext	MOVEM.L	D0-D2/A3-A6,-(A7)
		MOVE.L	SAVED_PC,A4
		MOVE.L	(A4),D0		Load 12 bytes of code
		MOVE.L	4(A4),D1
		MOVE.L	8(A4),D2
		LEA	SYSTACK+17,A5	Output buffer
		JSR	DCODE68K
* A3 = start of formatted line, A6 = end
		MOVE.B	#0,(A6)		Null-terminate
		MOVE.L	A3,A0
		BSR.W	printString	Print disassembled line
		LEA	msgNewline,A0
		BSR.W	printString
		MOVEM.L	(A7)+,D0-D2/A3-A6
		RTS

****************************************
*  traceHandler — vector 9: Trace exception
*
traceHandler
		MOVE.W	#$2700,SR	Mask interrupts
		BSR.W	saveRegs
		ANDI.W	#$7FFF,SAVED_SR	Clear T bit in saved SR
* Check trace count
		MOVE.W	TRACECNT,D0
		BMI.S	.resume		Negative = single-step-then-continue (BP resume)
		BEQ.S	.stopped	Zero = shouldn't happen, stop
		SUBQ.W	#1,D0
		MOVE.W	D0,TRACECNT
		BEQ.S	.stopped	Count reached zero
* Still tracing — display and continue
		BSR.W	regDump
		BSR.W	disasmNext
		ORI.W	#$8000,SAVED_SR	Re-set T bit
		BRA.W	unstack		RTE back to user (BPs already planted)
.resume
* Single-step past breakpoint complete — now install BPs and continue
		CLR.W	TRACECNT
		BSR.W	swapIn
		BRA.W	unstack
.stopped
		BSR.W	swapOut
		BSR.W	regDump
		BSR.W	disasmNext
		LEA	SYSTACK,A7
		BRA	PROMPT

****************************************
*  illegalHandler — vector 4: Illegal instruction (breakpoint trap)
*
illegalHandler
		TST.B	DEBUG_ON
		BNE.S	.debugIll
* Not in debug mode — fall through to excFault behavior
		LEA.L	msgFault,A0
		BSR.W	printString
		MOVE.L	2(A7),D0	Get PC from exception frame (skip SR word)
		BSR.W	printHexLong
		LEA.L	msgNewline,A0
		BSR.W	printString
		BRA	WARMSTART
.debugIll
		MOVE.W	#$2700,SR
		BSR.W	saveRegs
		BSR.W	swapOut		Restore original code
* On 68000, illegal instruction exception PC points AT the illegal word
		MOVE.L	SAVED_PC,D0
* Check temporary BP
		CMP.L	BPTADD,D0
		BEQ.S	.tmpHit
* Search regular BPs
		LEA	BPADD,A0
		LEA	BPCNT,A1
		MOVEQ	#NUMBP-1,D1
.search		CMP.L	(A0)+,D0
		BEQ.S	.found
		ADDQ.L	#2,A1
		DBRA	D1,.search
* Not a known BP — genuine illegal instruction
		LEA	msgIllegal,A0
		BSR.W	printString
		MOVE.L	SAVED_PC,D0
		BSR.W	printHexLong
		LEA	msgNewline,A0
		BSR.W	printString
		BRA.S	.toMonitor
.found
		MOVE.W	(A1),D1		Check pass count
		BEQ.S	.doBreak	0 = break every time
		SUBQ.W	#1,(A1)
		BNE.S	.passThru	Count not zero — skip
.doBreak
		LEA	msgBreak,A0
		BSR.W	printString
		MOVE.L	SAVED_PC,D0
		BSR.W	printHexLong
		LEA	msgNewline,A0
		BSR.W	printString
		BSR.W	regDump
		BSR.W	disasmNext
		BRA.S	.toMonitor
.tmpHit
		CLR.L	BPTADD
		BRA.S	.doBreak
.passThru
* Step past BP: trace 1 instruction, then re-SWAPIN in trace handler
		ORI.W	#$8000,SAVED_SR	Set T bit
		MOVE.W	#-1,TRACECNT	Special: resume after single-step
		BRA.W	unstack		RTE (BPs are already swapped out)
.toMonitor
		CLR.B	DEBUG_ON
		LEA	SYSTACK,A7
		BRA	PROMPT

****************************************
*  LOAD  Loads data formatted in hexadecimal "S" format from Port 2
*        NOTE - I/O is automatically redirected to the aux port for
*        loader functions. S1 or S2 records accepted
*
   *ADD.B    #1,ECHO(A6)       Turn off character echo
load    	LEA	msgNewline,A0		
		 BSR.W	printString
load2    BSR      inChar           Records from the host must begin
         CMP.B    #'S',D0           with S1/S2 (data) or S9/S8 (term)
         BNE.S    load2             Repeat GETCHAR until char = "S"
         BSR      inChar           Get character after "S"
         CMP.B    #'9',D0           Test for the two terminators S9/S8
         BEQ.S    load3             If S9 record then exit else test
         CMP.B    #'8',D0           for S8 terminator. Fall through to
         BEQ.S    load3             exit on S8 else continue search
         CMP.B    #'7',D0           for S8 terminator. Fall through to
         BNE.S    load6             exit on S8 else continue search
load3    EQU      *                 Exit point from LOAD
*         CLR.B    ECHO(A6)          Restore input character echo
         BTST     #0,D7             Test for input errors
         BEQ.S    load4             If no I/P error then look at checksum
         LEA.L    ERMES1,A0         Else point to error message
         BSR      printString       Print it
load4    BTST     #3,D7             Test for checksum error
         BEQ.S    load5             If clear then exit
         LEA.L    ERMES3,A0         Else point to error message
         BSR      printString       Print it and return
load5    LEA	msgNewline,A0		
	     BSR.W	printString
		 JMP WARMSTART
		 RTS

load6    CMP.B    #'1',D0           Test for S1 record
         BEQ.S    load6a            If S1 record then read it
         CMP.B    #'2',D0           Else test for S2 record
         BEQ.S    load6b             Repeat until valid header found
		 CMP.B    #'3',D0           * Else test for S3 record
         BNE.S    load2             * Repeat until valid header found
         * S3 record processing starts here
         CLR.B    D3                * Clear checksum
         BSR.S    load8             * Get byte and update checksum
         SUB.B    #5,D0             * Subtract 5 from record length for S3
         MOVE.B   D0,D2             * Save byte count in D2
         CLR.L    D0                * Clear address accumulator
         * Read four bytes of address for S3
         BSR.S    load8             * Get MS byte of load address
         ASL.L    #8,D0             * Shift left
         BSR.S    load8
         ASL.L    #8,D0             * Repeat for all four bytes
         BSR.S    load8
         ASL.L    #8,D0
         BSR.S    load8
         MOVE.L   D0,A2             * A2 points to destination of data
         BRA.S    load7             * Continue to data processing
load6b   CLR.B    D3                Read the S2 byte count and address,
         BSR.S    load8             clear the checksum
         SUB.B    #4,D0             Calculate size of data field
         MOVE.B   D0,D2             D2 contains data bytes to read
         CLR.L    D0                Clear address accumulator
         BSR.S    load8             Read most sig byte of address
         ASL.L    #8,D0             Move it one byte left
         BSR.S    load8             Read the middle byte of address
         ASL.L    #8,D0             Move it one byte left
         BSR.S    load8             Read least sig byte of address
         MOVE.L   D0,A2             A2 points to destination of record
         BRA.S    load7             Skip past S1 header loader
load6a   CLR.B    D3                S1 record found - clear checksum
         BSR.S    load8             Get byte and update checksum
         SUB.B    #3,D0             Subtract 3 from record length
         MOVE.B   D0,D2             Save byte count in D2
         CLR.L    D0                Clear address accumulator
         BSR.S    load8             Get MS byte of load address
         ASL.L    #8,D0             Move it to MS position
         BSR.S    load8             Get LS byte in D2
         MOVE.L   D0,A2             A2 points to destination of data
load7    BSR.S    load8             Get byte of data for loading
         MOVE.B   D0,(A2)+          Store it
         SUB.B    #1,D2             Decrement byte counter
         BNE      load7             Repeat until count = 0
         BSR.S    load8             Read checksum
         ADD.B    #1,D3             Add 1 to total checksum
         BEQ      load2             If zero then start next record
         OR.B     #%00001000,D7     Else set checksum error bit,
         BRA      load3             restore I/O devices and return
load8   BSR     BYTE               Get a byte
         ADD.B   D0,D3              Update checksum
         RTS                         and return


HEX      BSR      inChar           Get a character from input device
         SUB.B    #$30,D0           Convert to binary
         BMI.S    NOT_HEX           If less than $30 then exit with error
         CMP.B    #$09,D0           Else test for number (0 to 9)
         BLE.S    HEX_OK            If number then exit - success
         SUB.B    #$07,D0           Else convert letter to hex
         CMP.B    #$0F,D0           If character in range "A" to "F"
         BLE.S    HEX_OK            then exit successfully
NOT_HEX  OR.B     #1,D7             Else set error flag
HEX_OK   RTS                        and return

BYTE     MOVE.L   D1,-(A7)          Save D1
         BSR      HEX               Get first hex character
         ASL.B    #4,D0             Move it to MS nybble position
         MOVE.B   D0,D1             Save MS nybble in D1
         BSR      HEX               Get second hex character
         ADD.B    D1,D0             Merge MS and LS nybbles
         MOVE.L   (A7)+,D1          Restore D1
         RTS

WORD     BSR      BYTE              Get upper order byte
         ASL.W    #8,D0             Move it to MS position
         BRA      BYTE              Get LS byte and return

LONGWD   BSR      WORD              Get upper order word
         SWAP     D0                Move it to MS position
         BRA      WORD              Get lower order word and return

OUT1X    MOVE.W   D0,-(A7)          Save D0
         AND.B    #$0F,D0           Mask off MS nybble
         ADD.B    #$30,D0           Convert to ASCII
         CMP.B    #$39,D0           ASCII = HEX + $30
         BLS.S    OUT1X1            If ASCII <= $39 then print and exit
         ADD.B    #$07,D0           Else ASCII := HEX + 7
OUT1X1   BSR      outChar           Print the character
         MOVE.W   (A7)+,D0          Restore D0
         RTS

OUT2X    ROR.B    #4,D0             Get MS nybble in LS position
         BSR      OUT1X             Print MS nybble
         ROL.B    #4,D0             Restore LS nybble
         BRA      OUT1X             Print LS nybble and return

OUT4X    ROR.W    #8,D0             Get MS byte in LS position
         BSR      OUT2X             Print MS byte
         ROL.W    #8,D0             Restore LS byte
         BRA      OUT2X             Print LS byte and return

OUT8X    SWAP     D0                Get MS word in LS position
         BSR      OUT4X             Print MS word
         SWAP     D0                Restore LS word
         BRA      OUT4X             Print LS word and return

    
*****************
** Print a digit
****************
digit:
		CMP.B   #10,D0         * Compare the digit with 10
		BLO     digit_is_number * If less than 10,it's a numeric digit

		* Convert alphabetic digits (10-35) to ASCII 'A'-'Z'
		SUBI.B  #10,D0         * Adjust digit to 0-25 range for 'A'-'Z'
		ADDI.B  #'A',D0        * Convert to ASCII 'A' to 'Z'
		BRA     digit_done

digit_is_number:
* Convert numeric digits (0-9) to ASCII '0'-'9'
		ADDI.B  #'0',D0        * Convert to ASCII '0' to '9'

digit_done:
		RTS                     * Return from subroutine

    
* Assuming value is in D1,and buffer pointer in A0
* Return value will be in A0
print_signed:

    MOVEQ   #0,D5            * Clear negative flag
    lea.l   BUFFER,A0
    MOVE.B  #0,-(A0)          * Null-terminate the string
    MOVE.L  D1,D3            * Copy value to D3 for manipulation
    TST.L   D3                * Test the sign of the value
    BMI     handle_negative   * If negative,handle negation

process_value:
    MOVE.L  D3,D1            * Copy value to D0 for division
    MOVE.W  #10,D4            * Copy base to D4 for division
    EXT.L   D4                * Extend D4 to long

process_loop:
    MOVE.L  D1,D0            * Copy value to D0 for division
    DIVU    D4,D0            * Divide D0 by base
    move.l  #0,d1
    move.w  d0,d1              * store result back into d1

    SWAP    D0                * Swap to get the remainder in the lower 16 bits
    ANDI.W  #$00FF,D0        * Isolate the lower 8 bits (remainder)
    JSR     digit             * Call 'digit' subroutine

    MOVE.B  D0,-(A0)         * Store the ASCII character in the buffer and decrement the pointer

    TST.W   D1                * Check if quotient is 0
    BNE     process_loop      * If not 0,continue the loop

    BRA     finalize

handle_negative:
    NOT.L   D3                * Two's complement negation
    ADDQ.L  #1,D3            * Increment to complete two's complement
    MOVEQ   #1,D5            * Set flag for negative number
    BRA     process_value

finalize:
    TST.W   D5
    BEQ     no_negative_sign
    MOVE.B  #'-',-(A0)       * Insert negative sign

no_negative_sign:
    move.l  a0,A1         * Set return pointer to right position
    jsr printString
    RTS                       * Return from subroutine

*****************************************************************************************************
   
print_unsigned:
    lea.l   BUFFER,A0
    MOVE.B  #0,-(A0)          * Null-terminate the string
    CMP.B   #2,D2            * Compare base with 2
    BLO     exit_function     * If less than 2,exit
    CMP.B   #36,D2           * Compare base with 36
    BHI     exit_function     * If greater than 36,exit

    TST.L   D1                * Check if num in D1 is 0
    BEQ     handle_zero       * If zero,handle separately

convert_loop:
    MOVE.L  D1,D0            * Copy num to D0 for division
    DIVU    D2,D0            * Divide D0 by base,upper 16 bits = remainder,lower 16 bits = quotient
    move.l  #0,d1
    move.w  d0,d1              * store result back into d1

    SWAP    D0                * Swap to get the remainder in the lower 16 bits
    ANDI.W  #$00FF,D0        * Isolate the lower 8 bits (remainder)
    JSR     digit             * Call 'digit' subroutine

    MOVE.B  D0,-(A0)         * Store the ASCII character in the buffer and decrement the pointer

    TST.W   D1                * Check if quotient is 0
    BNE     convert_loop      * If not 0,continue the loop
    BRA     call_fw_print

handle_zero:
    MOVE.B  #'0',-(A0)      * Store '0' in buffer (pre-decrement like convert_loop)

call_fw_print:
    MOVE.L  A0,A1     * Set up pointer for FW_PRINT
    jsr printString
exit_function:
    RTS                       * Return from subroutine

*****************************************************************************************************
* TRAPS SECTION							

setExcVectors
		LEA.L	excFault,A1	Fault handler address
		MOVEQ	#2,D0		Start at vector 2 (bus error)
.excLoop	MOVE.L	D0,D1
		ASL.L	#2,D1		Multiply by 4 for vector offset
		MOVE.L	D1,A0
		MOVE.L	A1,(A0)		Store handler address
		ADDQ.L	#1,D0
		CMP.B	#8,D0		Vectors 2-7
		BNE.S	.excLoop
		RTS

setTrap0	RTS

setTrap1	MOVEQ	#32,D0		Traps start at vector 32	
		ADDI.B	#1,D0		Add 1 for TRAP 1		
		ASL.L	#2,D0		Multiply by 4 since each vector occupies 2 words	*****
		MOVE.L	D0,A0		Put final location into address register		*****
		MOVE.L	#trap1,(A0)	Initialize with exception handler address		*****
		RTS			Return from subroutine		

setTrap15	MOVEQ	#32,D0		Traps start at vector 32	
		ADDI.B	#15,D0		Add 15 for TRAP 15,this number chosen to be in line	*****
		ASL.L	#2,D0		with the EAsy68k simulator	- multiply by 4		*****
		MOVE.L	D0,A0		Put final location into address register		*****
		MOVE.L	#trap15,(A0)	Initialize with IO exception handler address		*****
		RTS			Return from subroutine		
* TRAP 0			


* TRAP 1				MFP GPIO Exception		
*					Value in D0 represents a GPIO 8 bit mask		*****
*					Value in D1 determines status of GPIO,0=off,other=on	*****
trap1		TST.B	D1		Check if turning GPIO pins on or off
		BNE.S	.gpio1		Jump to pin assertion if not zero
		NOT.B	D0		Invert mask to clear selected bits
		AND.B	D0,MFPGPDR	Clear the masked bits in GPIO Data Register
		NOT.B	D0		Restore D0
		RTE			Return from exception
.gpio1		OR.B	D0,MFPGPDR	Logical OR to assert all pins in mask if not already 1	*****
		RTE			Return from exception			


* TRAP 15				IO Exception
*					15 Chosen to match functionality with the EAsy68k sim	*****
*					Value of D0 determines function	
*

trap15		CMP.B	#0,D0		D0= 0 Display string at (A1),D1.W bytes long w/CR+LF	*****
		BEQ	.io0		Branch to subroutine		

		CMP.B	#1,D0		D0= 1 Display string at (A1),D1.W bytes long w/o CR+LF	*****
		BEQ	.io1		Branch to subroutine		

		CMP.B	#2,D0		D0= 2 Read UART string,store in (A1),null terminated	*****
		BEQ	.io2		Branch to subroutine		

		CMP.B	#3,D0		D0= 3 Display signed number D1.L dec in smallest field	*****
		BEQ	.io3		Branch to subroutine		

		CMP.B	#4,D0		D0= 4 Read number from UART into D1.L
		BEQ	.io4		Branch to subroutine		

		CMP.B	#5,D0		D0= 5 Read single char from UART into D1.B		*****
		BEQ	.io5		Branch to subroutine		

		CMP.B	#6,D0		D0= 6 Display single character in D1.B
		BEQ	.io6		Branch to subroutine		

		CMP.B	#7,D0		D0= 7 Set D1.B to 1 if UART RX buffer full,otherwise 0	*****
		BEQ	.io7		Branch to subroutine

		CMP.B	#8,D0		D0= 8 Get time from MFP timer
		BEQ	.io8		Branch to subroutine

		CMP.B	#12,D0		D0= 12 Set echo on/off (D1.B)
		BEQ	.io12

		CMP.B	#13,D0		D0= 13 Print string at (A1) with CR+LF
		BEQ   .io13

		CMP.B	#14,D0		D0= 14 Print string at (A1) without CR+LF
		BEQ  .io14

		CMP.B	#15,D0		D0= 15 Print unsigned D1.L in base D2.B
		BEQ  .io15
	
		CMP.B	#16,D0		d0 = 16  Adjust display properties
		BEQ .io16

.ioExcEnd	RTE			Return from exception		

.io0		move.l	A0,-(A7)	Save A0
		move.l	A1,A0		Source pointer
		move.w	D1,-(A7)	Save length counter
.io0lp		tst.w	D1		Any chars left?
		beq.s	.io0crlf	No, send CR+LF
		MOVE.B	(A0)+,D0	Get next char
		BSR.W	outChar		Print it
		subq.w	#1,D1		Decrement count
		bra.s	.io0lp		Loop
.io0crlf	MOVE.B	#CR,D0
		BSR.W	outChar
		MOVE.B	#LF,D0
		BSR.W	outChar
		move.w	(A7)+,D1	Restore length
		move.l	(A7)+,A0	Restore A0
		BRA	.ioExcEnd	Return from exception

.io1		move.l	A0,-(A7)	Save A0
		move.l	A1,A0		Source pointer
		move.w	D1,-(A7)	Save length counter
.io1lp		tst.w	D1		Any chars left?
		beq.s	.io1done	No, done
		MOVE.B	(A0)+,D0	Get next char
		BSR.W	outChar		Print it
		subq.w	#1,D1		Decrement count
		bra.s	.io1lp		Loop
.io1done	move.w	(A7)+,D1	Restore length
		move.l	(A7)+,A0	Restore A0
		BRA	.ioExcEnd	Return from exception
         
.io2		
    move.l  A1,-(A7)                    * Store buffer start
    move.l  D2,-(A7)                    * Store scratch register

    move.b  PROMPT_ON,D2                * Get display prompt flag
    tst.b   D2                          * Is it non-zero?
    beq.s   .READ                       * Nope,skip prompt display

    lea.l   msgPrompt,A0            * Get prompt into A0...
    JSR printString                    * ... and print it

.READ
    move.b  ECHO_ON,D2                  * Get echo flag into D2
    move.w  #79,D1                      * Max len into D1 (DBRA loops N+1 times)
    bra.s   .LOOP                       * Start looping...

.RECV:
    BTST.B  #7,MFPRSR	Check for empty receive buffer	
	BEQ.S	.RECV    	Bail if nothing to return	
	MOVE.B  MFPUDR,D0	Else move character to D0
    cmp.b   #$0D,D0                     * Is it CR?
    beq.s   .DONE                       * Done if so,else
    move.b  D0,(A1)+                    * Store char in buffer and advance

    tst.b   D2                          * Is echo flag non-zero?
    beq.s   .LOOP         
	              * Nope,just loop...
.xmit:	BTST.B  #7,MFPTSR	Check for empty transmit buffer	
	BEQ.S   .xmit	Loop until ready		
	MOVE.B  D0,MFPUDR	Put character into USART data register

.LOOP:
    dbra    D1,.RECV                    * Go again?

.DONE:
    move.b  #0,(A1)+                    * Null-terminate
    move.b  LF_DISPLAY,D2               * Get LF_DISPLAY flag
    tst.b   D2                          * Is it non-zero?
    beq.s   .RETURN                     * Nope,skip CRLF...
.cr
    move.b  #$0D,D0                     * Finish with CR...
    BTST.B  #7,MFPTSR	Check for empty transmit buffer	
	BEQ.S   .cr	Loop until ready		
	MOVE.B  D0,MFPUDR	Put character into USART data register
    move.b  #$0A,D0                     * .. and LF
.lf    BTST.B  #7,MFPTSR	Check for empty transmit buffer	
	BEQ.S   .lf	Loop until ready		
	MOVE.B  D0,MFPUDR	Put character into USART data register

.RETURN
    move.w  #79,D0                      * Compute length (79 = max_count, not 80)
    add.w   #1,D1
    sub.w   D1,D0
    move.w  D0,D1                       * Shuffle around to stay compatible...
    move.l  (A7)+,D2                    * ... restore scratch reg
    move.l  (A7)+,A1                    * ... and buffer pointer
	BRA	.ioExcEnd	Return from exception		

.io3		jsr print_signed
			BRA	.ioExcEnd	Return from exception		

.io4		CLR.L	D1		Unimplemented — clear D1
		BRA	.ioExcEnd	Return from exception


.io5		BTST.B  #7,MFPRSR	Check for empty receive buffer
			BEQ.S	.io5		Busy-wait until data available
			MOVE.B  MFPUDR,D1	Else move character to D1
.end		BRA	.ioExcEnd	Return from exception		

.io6		BTST.B  #7,MFPTSR	Check for empty transmit buffer	
			BEQ.S   .io6	Loop until ready		
			MOVE.B  D1,MFPUDR	Put character into USART data register
			BRA	.ioExcEnd	Return from exception		

.io7
		EOR.L   D1,D1		D1 will store return,1 = buffer full
		BTST.B	#7,MFPRSR	Check if character is still in RX buffer		*****
		BEQ	.ioExcEnd	Bail if empty
		MOVEQ	#1,D1		Set return to indicate character waiting		*****
		bra	.ioExcEnd	Return from exception		

.io8	CLR.L	D1		Unimplemented — clear D1
	BRA	.ioExcEnd	Return from exception

.io12
		move.b  D1,ECHO_ON
		BRA	.ioExcEnd	Return from exception

.io13	move.l a1,a0
		jsr printString
		MOVE.B	#CR,D0	
		BSR.W	outChar		Pad end with spaces	
		MOVE.B	#LF,D0	
		BSR.W	outChar		Pad end with spaces
		bra	.ioExcEnd	Return from exception			

.io14	move.l a1,a0
		jsr printString
		BRA	.ioExcEnd	Return from exception	

.io15	jsr print_unsigned
		BRA	.ioExcEnd	Return from exception	

.io16
* D1.B = 0 to turn off the display of the input prompt.
* D1.B = 1 to turn on the display of the input prompt. (default)
* D1.B = 2 do not display a line feed when Enter pressed during Trap task #2 input
* D1.B = 3 display a line feed when Enter key pressed during Trap task #2 input (default)
	cmp.b   #0,D1                       * Is D1 0?
    beq     .PROMPT_OFF                 *   Prompt disable if so,else...
    cmp.b   #1,D1                       * Is D1 1?
    beq     .PROMPT_ON                  *   Prompt enable if so,else...
    cmp.b   #2,D1                       * Is D1 2?
    beq     .LF_OFF                     *   Linefeed disable if so,else...
    cmp.b   #3,D1                       * Is D1 3?
    beq     .LF_ON                      *   Linefeed enable if so,else...
	BRA	.ioExcEnd	Return from exception

.PROMPT_OFF
    move.b  #0,PROMPT_ON
	BRA	.ioExcEnd	Return from exception

.PROMPT_ON
    move.b  #1,PROMPT_ON
	BRA	.ioExcEnd	Return from exception

.LF_OFF
    move.b  #0,LF_DISPLAY
	BRA	.ioExcEnd	Return from exception

.LF_ON
    move.b  #1,LF_DISPLAY
	BRA	.ioExcEnd	Return from exception
	
cvtCase
		LEA	LINEBUF,A0	Get start of line
* Skip leading spaces
.skip		MOVE.B	(A0),D0
		BEQ.S	.done		Null — empty line
		CMP.B	#' ',D0
		BNE.S	.mnem		Found mnemonic start
		ADDQ.L	#1,A0
		BRA.S	.skip
* Convert mnemonic + suffix (up to first space) to upper-case
.mnem		MOVE.B	(A0),D0
		BEQ.S	.done		Null terminator
		CMP.B	#' ',D0
		BEQ.S	.oper		Space — mnemonic ends, operand begins
		CMP.B	#'a',D0
		BLT.S	.mnext
		CMP.B	#'z',D0
		BGT.S	.mnext
		SUB.B	#$20,D0
		MOVE.B	D0,(A0)
.mnext		ADDQ.L	#1,A0
		BRA.S	.mnem
* Convert operand — uppercase everything except quoted strings and comments
.oper		MOVE.B	(A0),D0
		BEQ.S	.done		Null terminator
		CMP.B	#';',D0
		BEQ.S	.done		Semicolon comment — stop converting
		CMP.B	#'''',D0
		BEQ.S	.quote		Start of quoted string — skip it
		CMP.B	#'a',D0
		BLT.S	.onext
		CMP.B	#'z',D0
		BGT.S	.onext
		SUB.B	#$20,D0
		MOVE.B	D0,(A0)
.onext		ADDQ.L	#1,A0
		BRA.S	.oper
* Skip past quoted string (single-quote delimited)
.quote		ADDQ.L	#1,A0		Skip opening quote
.qloop		MOVE.B	(A0),D0
		BEQ.S	.done		Null — unterminated quote
		CMP.B	#'''',D0
		BEQ.S	.qend		Closing quote
		ADDQ.L	#1,A0
		BRA.S	.qloop
.qend		ADDQ.L	#1,A0		Skip closing quote
		BRA.S	.oper		Continue with operand
.done		RTS	

assemble        
				   BSR.W	parseNumber	Read start address			
				   TST.B	D1		Non-zero return on invalid address
				   BEQ .startAddr
				   
				   LEA	msgBadAddr,A0
                   BSR.W	printString
                   bra .quitASM
				   
.startAddr	       MOVEa.L	D0,A4		Save the start address	
.loopasm           LEA       PROGCNT,A0
                   MOVE.L    A4,(A0)
                   
                   MOVE.L    A4,-(SP)
                   MOVE.L    (A4)+,D0
                   MOVE.L    (A4)+,D1
                   MOVE.L    (A4)+,D2
                   MOVEA.L   (SP)+,A4

                   LEA     SYSTACK+17,A5  STORE BUFFER


*        CALLING SEQUENCE:
*   D0,D1,D2 = CODE TO BE DISASSEMBLED
*   A4 = VALUE OF PROGRAM COUNTER FOR THE CODE
*   A5 = POINTER TO STORE DATA (BUFSIZE = 80 ASSUMED)
                   JSR       DCODE68K

*        RETURN:
*   A4 = VALUE OF PROGRAM COUNTER FOR NEXT INSTRUCTION
*   A5 = POINTER TO LINE AS DISASSEMBLED
*   A6 = POINTER TO END OF LINE
*
* 01234567890123456789012345678901234567890123456789
* AAAAAA FDATA.DDDDDDDDDDDDDD FOC.... FOP.....
                   move.l a4,-(sp)
                   MOVE.B #BLANK,(A6)+
*                   MOVE.B #$3E,(A6)+
                   MOVE.B #0,(A6)+
                   MOVE.L A3,A1
                   MOVE.L #14,D0
                   TRAP #15

                   LEA       PROGCNT,A0
                   MOVEA.L    (A0),A4

                   LEA.L     LINEBUF,A1
                   MOVE.B #BLANK,(A1)+
                   move.b #2,d0
                   trap #15
                   
                   LEA.L LINEBUF,a0
                   bsr cvtCase
                   LEA.L LINEBUF,a0
                   move.b 1(a0),d0
                   cmp.b #$58,d0
                   beq .quitASM
                   
                   cmp.b #CR,d0
                   bne .nullcheck
                   movea.l (sp)+,a4
                   bra .loopasm
                   
.nullcheck         cmp.b #0,d0
                   bne .next
                   movea.l (sp)+,a4
                   bra .loopasm

.next              lea.l LINEBUF,A5
                   MOVEA.L A5,A6    * Copy the address from A5 to A6
                   ADD.W   D1,A6    * Add the value in D1 to the address in A6
                   ADD.L   #1,A6

*                  A3 = STORE POINTER
*                  A4 = PROGRAM COUNTER
*                  A5 = POINTER TO DATA TO ASSEMBLE
*                  A6 = POINTER TO END OF SOURCE DATA
                   
                   BSR     CODE68K        ASSEMBLE
         
*                  A3 = POINTER TO LINE ASSEMBLED
*                  A4 = PROGRAM COUNTER
*                  A6 = POINTER END OF LINE ASSEMBLED
*                  D0-D2 = DATA ASSEMBLED
*                  D6 = NUMBER OF BYTES ASSEMBLED
*                  D7 = ERROR FLAG & POSITION OF ERROR

                   * STORE RESPONSE
                   lea LINEBUF,A1
                   MOVE.L D0,(A1)+
                   MOVE.L D1,(A1)+
                   MOVE.L D2,(A1)+
                   MOVE.L D3,(A1)+
                   lea LINEBUF,A1

* MOVE DATA FROM THE LINE TO MEMORY

.LOOP
                 TST D6
                 BEQ .PRINTRESULT
                 
                 MOVE.B (A1)+,(A4)+         * Move byte to D0
                 
    * Decrement counter and loop back if not done
                 DBRA   D6,.LOOP
                 
.PRINTRESULT
                   MOVE.B #0,(A6)+
                   MOVE.L A3,A1
                   MOVE.L #13,D0
                   TRAP #15
                   
                   addq.l  #4,sp
                   BRA .loopasm

.quitASM           addq.l  #4,sp
                   MOVEM.L	(SP)+,A2-A3
                   jmp $fe0000
*-------------------------------------------------------------------------
* File CODE68K   68K ONE LINE ASSEMBLER                           07/23/82

* EVALUATE EXPRESSION
*  NUMBER PLUS OR MINUS NUMBER....
*
EV      
         MOVE.L  D7,-(A7)       SAVE D7
         CLR.L   D7
EV21     BSR.S   GETFIELD       GET NUMBER
         ADD.L   D0,D7          D7 = NUMBER BEING BUILT
EV15     MOVE.B  (A5)+,D1       D1 = TERMINATING CHAR
         CLR.L   D0             D0 = NEXT NUMBER (=0 1ST TIME)
         CMPI.B  #'+',D1
         BEQ     EV21           PLUS
         CMPI.B  #'-',D1
         BNE.S   EV39           NOT MINUS
         BSR.S   GETFIELD       GET NEXT NUMBER
         SUB.L   D0,D7
         BRA     EV15

EV39     MOVE.L  D7,D0          D0 = VALUE BUILT
         SUBQ.L  #1,A5          A5 = CHAR AFTER EXPRESSION
         MOVE.L  (A7)+,D7       RESTORE D7
         RTS

GETFIELD 
         CMPI.B  #'*',(A5)
         BNE.S   GETF305

         MOVE.L  D4,D0          D0 = PROGRAM COUNTER
         ADDQ.L  #1,A5
         BRA.S   GETF333

GETF305  CMPI.B  #$27,(A5)
         BNE.S   GETF325        NOT LITERAL

         ADDQ.L  #1,A5
         CLR.L   D0

         MOVE.W  TLENGTH(A1),D1  D1 = SIZE
         BEQ.S   GETF308        .B = 0
         LSR.W   #5,D1          .W = 1
         SUBQ.L  #1,D1          .L = 3
GETF308

GETF311  LSL.L   #8,D0
         MOVE.B  (A5)+,D0
         CMPI.B  #$27,(A5)
         BEQ.S   GETF312        CLOSING QUOTE
         DBF     D1,GETF311
         BRA.S   ER1            OVERFLOW

GETF312  ADDQ.L  #1,A5          MOVE PAST CLOSING QUOTE
         BRA.S   GETF314

GETF313  LSL.L   #8,D0
GETF314  DBF     D1,GETF313     LEFT NORNALIZE
         BRA.S   GETF333

GETF325  BSR     GETDECNU       GET DECIMAL NUMBER
         BNE.S   ER1            MESSED UP NUMBER

GETF333  RTS

XBASE    DS        0

* FIND AND SET SIZE
* BIT 5432109876543210
*     ........00......  = BYTE
*     ........01......  = WORD
*     ........10......  = LONG
*
FSIZE    OR.W    TLENGTH(A1),D2  SET SIZE BITS
         RTS

*  D0 = VALUE 0 - 7
*  D1 = 0 IF D@     = 1 IF A@
GETREGD  CLR.L   D1
         CMPI.B  #'D',(A5)+
         BNE.S   ER1
GET41    CLR.L   D0
         MOVE.B  (A5)+,D0
         SUBI.B  #'0',D0
         BMI.S   ER1
         CMPI.B  #$7,D0
         BGT.S   ER1
         RTS

GETREGA  CLR.L   D1
         MOVE.B  #8,D1
         CMPI.B  #'A',(A5)+
         BNE.S   ER1
         BRA     GET41

GETREGAD CLR     D1
         MOVE.B  (A5)+,D0
         CMPI.B  #'D',D0
         BEQ     GET41
         MOVE.B  #8,D1
         CMPI.B  #'A',D0
         BEQ     GET41
ER1      BRA     ER

EADA     MOVE.W  #$1FD,D7       DATA ALTERABLE ONLY
         BRA.S   EA

EAC      MOVE.W  #$7E4,D7       CONTROL ONLY
         BRA.S   EA

EAM      MOVE.W  #$1FC,D7       MEMORY ALTERABLE ONLY
         BRA.S   EA

EAZ      MOVE.W  #$800,D7       IMMEDIATE ONLY
         BRA.S   EA

EADADDR  MOVE.W  #$FFD,D7       DATA ADDRESSING
         BRA.S   EA

EAA      MOVE.W  #$1FF,D7       ALTERABLE ADDRESSING
         BRA.S   EA

EAALL    MOVE.W  #$FFF,D7       ALL MODES

*  ...............1  D@                DATA REGISTER
*  ..............1.  A@
*  .............1..  (A@)
*  ............1...  -(A@)
*  ...........1....  (A@)+
*  ..........1.....  DATA(A@)
*  .........1......  DATA(A@,R@)
*  ........1.......  DATA  (SHORT)
*  .......1........  DATA  (LONG)
*  ......1.........  DATA(PC)
*  .....1..........  DATA(PC,R@)
*  ....1...........  #DATA
*  1...............  SPECIAL CASE JMP.L

* D0 = VALUE CALCULATED
* D2 = MASK WORD (1ST WORD OF INSTRUCTION)
* D3 = OFFSET FOR DATA STORE (TDATA+..)
* D4 = EXTENSION WORD
* D5 = <DATA>
* D6 = MODE AS BUILT   .........XXXXXX
* D7 = MODES ALLOWED
*
* A4 = BASE ADDRESS FOR DATA STORE (TDATA+..)[A4,D3]
EA       DS      0
         CLR.L   D5             ZERO VALUE
         CLR.L   D6             MODE = 000000
         MOVE.B  (A5),D0
         CMPI.B  #'#',D0
         BNE.S   EA10

* IMMEDIATE MODE

         BTST    #11,D7
         BEQ     ER1

         MOVE.B  #$3C,D6        D6 = MODE  111100
         ADDQ.L  #1,A5

         BSR     EV             EVALUATE EXPRESSION
         MOVE.L  D0,D5          D5 = VALUE

         TST.B   TLSPEC(A1)
         BEQ.S   EA0633         .SIZE NOT SPECIFIED (.W ASSUMED)

         MOVE.W  TLENGTH(A1),D0
         BEQ.S   EA0635         .BYTE

         TST.B   D0
         BMI.S   EA0637         .LONG

EA0633   BSR     EA16BIT        .WORD     -32K TO +64K
EA0634   MOVE.W  D5,(A4,D3)
         ADDQ.B  #2,TNB(A1)     BYTE COUNT
         ADDQ.L  #2,D3          OFFSET
         RTS

EA0635   BSR     EA8BIT         -127 TO +255
         BNE     ER1
         BRA     EA0634

EA0637   MOVE.L  D5,(A4,D3)
         ADDQ.B  #4,TNB(A1)
         ADDQ.L  #4,D3
         RTS

EA10     DS      0
         CMPI.B  #'-',(A5)
         BNE.S   EA11

         CMPI.B  #'(',1(A5)
         BNE     EA41           MAY BE "-<DATA>

         ADDQ.L  #2,A5
         MOVE.W  #$0020,D6      MODE = -(A@)    100AAA

         BTST    #4,D7
         BEQ     ER1            THIS MODE NOT ALLOWED

         BSR     GETREGA
         OR.W    D0,D6

         CMPI.B  #')',(A5)+
         BNE.S   ER3            NO CLOSING PAREN
         RTS

EA11     CMPI.B  #'A',D0
         BNE.S   EA21

         MOVE.B  #$08,D6        MODE = 001...
         BTST    #1,D7
         BEQ.S   ER3            MODE NOT ALLOWED

         BSR     GETREGA
         OR.W    D0,D6
         RTS

EA21     CMPI.B  #'D',D0
         BNE.S   EA31

         BTST    #0,D7
         BEQ.S   ER3            MODE NOT ALLOWED

         BSR     GETREGD        MODE = D@   000AAA
         OR.W    D0,D6
         RTS

EA31     CMPI.B  #'(',D0
         BNE.S   EA41

* POSSIBLE
*  (A@)
*  (A@)+
*  (A@,R@)  IMPLIED ZERO DISPLACEMENT
*
         ADDQ.L  #1,A5
         BSR     GETREGA
         OR.W    D0,D6

         MOVE.B  (A5)+,D0
         CMPI.B  #',',D0
         BEQ     EA5116         MODE = (A@,R@)  ;IMPLIED D5 = 0 DATA

         CMPI.B  #')',D0        LOOK FOR CLOSING )
         BNE.S   ER3

         CMPI.B  #BLANK,(A5)    LOOK FOR BLANK
         BEQ.S   EA35           MODE = (A@)

         CMPI.B  #'+',(A5)
         BNE.S   EA35
         ADDQ.L  #1,A5

         ORI.W   #$18,D6        MODE = 011...    (A@)+

         BTST    #3,D7
         BEQ.S   ER3            MODE NOT ALLOWED

EA34     RTS

EA35     ORI.W   #$10,D6        MODE = 010...   (A@)

         BTST    #2,D7
         BNE     EA34           MODE ALLOWED
ER3      BRA     ER             MODE NOT ALLOWED

* POSSIBLE
*   <DATA>   SHORT
*   <DATA>   LONG
*   <DATA>(A@)
*   <DATA>(A@,R@)
*   <DATA>(A@,R@.W)
*   <DATA>(A@,R@.L)
*   <DATA>(PC)
*   <DATA>(PC,R@)
*   <DATA>(PC,R@.W)
*   <DATA>(PC,R@.L)
*
EA41     BSR     EV             EVALUATE EXPRESSION
         MOVE.L  D0,D5          D5 = <DATA>

         MOVE.B  (A5),D0
         CMPI.B  #',',D0
         BEQ.S   EA4102
         CMPI.B  #BLANK,D0
         BNE.S   EA4120

*  <DATA>         ONLY
* CHECK IF NEGATIVE NUMBER

EA4102   MOVE.L  D5,D0
         BPL.S   EA4105         POSITIVE NUMBER
         NOT.L   D0
EA4105   ANDI.W  #$8000,D0
         TST.L   D0
         BNE.S   EA4135         .LONG

*  <DATA>.W
         BTST    #7,D7
         BNE.S   EA4127         SHORT ALLOWED
         BTST    #15,D7
         BEQ     ER3            MODE NOT ALLOWED
         BRA.S   EA4135         SPECIAL CASE (JMP.L)

EA4127   ORI.W   #$38,D6        EA = ABSOULTE SHORT
         MOVE.W  D5,(A4,D3)     D5 = DATA
         ADDQ.B  #2,TNB(A1)     BYTE COUNT
         ADDQ.L  #2,D3
         RTS

*EA4134  CMPI.B  #'L',D0
*        BNE     ER3

*  <DATA>.L
EA4135   ORI.W   #$39,D6        EA = ABSOLUTE LONG
         MOVE.L  D5,(A4,D3)
         ADDQ.B  #4,TNB(A1)     BYTE COUNT
         ADDQ.L  #4,D3
         BTST    #8,D7
         BEQ     ER3            MODE NOT ALLOWED
         RTS

EA4120   ADDQ.L  #1,A5
         CMPI.B  #'(',D0
         BNE     ER3

         CMPI.B  #'P',(A5)
         BEQ     EA61

* <DATA>(A@.......
         BSR     EA16BITS       -32K TO +32K

         BSR     GETREGA
         OR.W    D0,D6

         MOVE.B  (A5),D0
         CMPI.B  #')',D0
         BNE.S   EA5115

* <DATA>(A@)
         ADDQ.L  #1,A5

         BTST    #5,D7
         BEQ     ER4            MODE NOT ALLOWED

         ORI.W   #$0028,D6      MODE = 101AAA

         CMPI.L  #$10000,D5
         BPL     ER4

         MOVE.W  D5,(A4,D3)
         ADDQ.B  #2,TNB(A1)
         ADDQ.L  #2,D3
         RTS

EA5115   BSR     COMMA

*  <DATA>(A@,-----    ADDRESS REGISTER WITH INDEX
EA5116   EXT.L   D5
         BSR     EA8BITS        -128 TO +127
         BNE.S   ER4
         ANDI.W  #$00FF,D5
         ORI.W   #$0030,D6      MODE  110---

         BTST    #6,D7
         BEQ.S   ER4            MODE NOT ALLOWED

         BSR     GETREGAD
         OR.W    D1,D0
         ROR.W   #4,D0
         OR.W    D0,D5          EXTENSION WORD

* BIT 11 EXTENSION WORD
*   0 = SIGN EXTENDED,LOW ORDER INTEGER IN INDEX REGISTER
*   1 = LONG VALUE IN INDEX REGISTER  (DEFAULT)
*
         MOVE.B  (A5)+,D0
         CMPI.B  #')',D0
         BEQ.S   EA5119         DEFAULT   .W

         CMPI.B  #'.',D0
         BNE.S   ER4

         MOVE.B  (A5)+,D0
         CMPI.B  #'W',D0
         BEQ.S   EA5118

         CMPI.B  #'L',D0
         BNE.S   ER4            NEITHER .W NOR .L

         ORI.W   #$0800,D5      EXTENSION WORD,W/L BIT = .L

EA5118   CMPI.B  #')',(A5)+
         BNE.S   ER4            NO CLOSING ")"

EA5119   MOVE.W  D5,(A4,D3)
         ADDQ.B  #2,TNB(A1)
         ADDQ.L  #2,D3
EA5119E  RTS

*  <DATA>(P-----
EA61     ADDQ.L  #1,A5
         CMPI.B  #'C',(A5)+
         BNE     ER

         SUB.L   PCOUNTER(A1),D5  D5 = D5 - PC
         SUBQ.L  #2,D5          D5 = D5 - (PC + 2)

         MOVE.B  (A5)+,D0
         CMPI.B  #')',D0
         BNE.S   EA71

*  <DATA>(PC)
         ORI.W   #$3A,D6        MODE = 111010

         BSR.S   EA16BITS       -32K TO +32K
         MOVE.W  D5,(A4,D3)
         ADDQ.B  #2,TNB(A1)
         ADDQ.L  #2,D3

         BTST    #9,D7
         BNE     EA5119E
ER4      BRA     ER

*  <DATA>(PC----          PROGRAM COUNTER WITH INDEX
EA71     MOVE.W  #$003B,D6      MODE = 111011

         CMPI.B  #',',D0
         BNE     ER4

         BTST    #10,D7
         BEQ     ER4            MODE NOT ALLOWED

         BSR.S   EA8BITS        -128 TO +127
         BNE     ER4

         ANDI.W  #$00FF,D5      D5 = VALUE
         BSR     GETREGAD
         OR.W    D1,D0

         ROR.W   #4,D0
         OR.W    D0,D5          D5 = EXTENSION WORD

         MOVE.B  (A5)+,D0
         CMPI.B  #')',D0
         BEQ.S   EA7115         DEFAULT  .W

         CMPI.B  #'.',D0
         BNE     ER4

         MOVE.B  (A5)+,D0
         CMPI.B  #'W',D0
         BEQ.S   EA7113

         CMPI.B  #'L',D0
         BNE     ER4
         ORI.W   #$0800,D5      EXTENSION WORD W/L = .L

EA7113   CMPI.B  #')',(A5)+
         BNE     ER4            NO CLOSING ")"

EA7115   MOVE.W  D5,(A4,D3)
         ADDQ.B  #2,TNB(A1)
         ADDQ.L  #2,D3
         RTS

****************************************************************************
*
*        ROUTINES TO TEST FOR VALID EFFECTIVE ADDRESSES
*
*        EA16BIT   tests that -32768 <= D5 <= 65535.  (signed or unsigned)
*        EA16BITS  tests that -32768 <= D5 <= 32767.  (signed only)
*        EA8BIT    tests that   -128 <= D5 <=   255.  (signed or unsigned)
*        EA8BITS   tests that   -128 <= D5 <=   127.  (signed only)
*
*        The 16-bit tests branch to ER if invalid,else return.
*        The  8-bit tests return condition codes <EQ> if valid,else <NE>.
*        D5 is preserved unless a branch to ER results.
*        D1 is destroyed.
*
****************************************************************************

EA16BIT:
         BSR.S   EA16BITC       CHECK RANGE -32768 TO 32767.  IF
         MOVE.L  D5,D1          INVALID,CHECK WHETHER THE HIGH 16
         SWAP    D1             BITS ARE 0 (WHICH IMPLIES THAT
         TST.W   D1             D5 <= 65535).  IF NOT,FALL THRU TO
         BEQ.S   EASEX          THE 16-BIT SIGNED TEST--WE WILL
*                               FAIL AND GO TO ER.

EA16BITS:
         PEA     ER(PC)         SET UP TO RETURN TO ER IF INVALID.

EA16BITC MOVE.L  #$7FFF,D1      D1  <--  2^16-1.
         BRA.S   EAS            GO TO THE COMMON TEST ROUTINE.


EA8BIT:
         BSR.S   EA8BITC        CHECK RANGE -128 TO 127.  IF INVALID,
         MOVE.L  D5,D1          CHECK WHETHER THE HIGH 24 BITS ARE
         LSR.L   #8,D1          0 (WHICH IMPLIES THAT D5 <= 255).
         RTS

EA8BITS:
         BSR.S   EA8BITC        JUST CHECK FOR -127 <= D5 <= 128.
         RTS                    *(BSR PUTS NEEDED ADDRESS ON STACK!)

EA8BITC  MOVEQ   #$7F,D1        D1  <--  2^8 - 1.

*                  *** NOTE: THIS ROUTINE PLAYS WITH THE STACK ***
EAS      CMP.L   D1,D5          IF D5 > 2^N-1,RETURN WITH <NE> (INVAL).
         BGT.S   EASEX
         NOT.L   D1             IF D5 < -2^N, RETURN WITH <NE> (INVAL).
         CMP.L   D1,D5
         BLT.S   EASEX

         ADDQ.L  #4,A7          POP THE RETURN ADDRESS OFF THE STACK,
         CLR.L   D1             SET <EQ> (VALID),AND RETURN.

EASEX    RTS


* WITHOUT LABEL FIELD
* 012345678901234567890123456789012345678901234567890
* AAAAAA DDDDDDDDDDDDDDDDDDDD OPCODE  OPERAND
*        FDATA                FOC     FOP

* 012345678901234567890123456789012345678901234567890
* AAAAAA DDDDDDDDDDDDDDDDDDDD LLLLLLLL OPCODE  OPERAND
*        FDATA                FOL      FOC     FOP

* A3 = STORE POINTER
* A4 = PROGRAM COUNTER
* A5 = SOURCE PTR BEGINNING
* A6 = SOURCE PTR END+1
*
OUTBSIZE EQU     80        BUFFER SIZE
FDATA    EQU     10        OFFSET TO DATA
FOL      EQU     31        OFFSET TO LABEL
FOC      EQU     31        OFFSET TO OP-CODE (NO LABEL FIELD)
FOP      EQU     39        OFFSET TO OPERAND (NO LABEL FIELD)

CODE68K  *LINK    A1,#0-(ESKE-ESKB)
         *MOVE.L  A1,LINK(A7)    SAVE LINKAGE
         LEA.L   DATASTR,A1          A1 = BASE REGISTER TO DATA
         MOVE.L  A7,LINK(A1)    SAVE SP FOR ERROR PATH STACK CLEANUP

         MOVE.B  #BLANK,(A6)    INSURE LAST CHAR IS SPACE

         MOVE.L  A3,A0
         MOVEQ   #OUTBSIZE-1,D0
M300     MOVE.B  #BLANK,(A0)+   SPACE FILL BUFFER
         DBRA    D0,M300
         SUBQ.L  #2,A0
         MOVE.L  A0,PTRBUFE(A1) PTR TO END OF BUFFER

         MOVE.L  A4,PCOUNTER(A1)  FORMAT PC
         MOVE.L  A4,D4          D4 = P-COUNTER
         MOVE.L  A4,D0

         MOVE.L  A6,-(A7)       SAVE A6
         MOVE.L  A3,A6
         BSR     FRELADDR       FORM RELATIVE ADDRESS
         MOVE.L  (A7)+,A6       RESTORE A6

         MOVEQ   #1,D7          POSSIBLE ERROR CODE
         MOVE.L  A4,D0
         ROR.L   #1,D0
         BMI     ERDONE         PC ODD ADDRESS

         MOVEQ   #FOL,D7        POSSIBLE ERROR CODE
         CMPI.B  #BLANK,(A5)+
         BNE     ERDONE         1ST CHAR NOT SPACE

         MOVE.B  #2,TNB(A1)     INZ # OF BYTES
         MOVE.W  #$40,TLENGTH(A1)  SIZE = .W (DEFAULT)
         CLR.B   TLSPEC(A1)     DEFAULT (SIZE NOT SPECIFIED)

         MOVE.L  A3,A0          A0 = STORE ADDRESS
         ADD.L   #FOC,A0

M340     BSR     GETCHARF       GET PAST SPACES
         CMPI.B  #BLANK,D0
         BEQ     M340

         SUBQ.L  #1,A5          FORMAT OP-CODE
M350     BSR     GETCHARF
         MOVE.B  D0,(A0)+
         CMPI.B  #'.',D0
         BNE.S   M352

         MOVE.B  (A5),TLSPEC(A1)  NOT DEFAULT
         CMPI.B  #'W',(A5)
         BEQ.S   M352
         CMPI.B  #'S',(A5)
         BEQ.S   M352           .SHORT = .WORD
         CLR.W   TLENGTH(A1)
         CMPI.B  #'B',(A5)
         BEQ.S   M352           SIZE = .W
         MOVE.W  #$80,TLENGTH(A1)
         CMPI.B  #'L',(A5)
         BEQ.S   M352
         CMPI.B  #'D',(A5)      FPU double
         BEQ.S   M352
         CMPI.B  #'X',(A5)      FPU extended
         BEQ.S   M352
         CMPI.B  #'P',(A5)      FPU packed BCD
         BNE     ERF

M352     CMPI.B  #BLANK,D0
         BNE     M350           NOT SPACE CONTINUE

* SEARCH OP-CODE TABLE
         LEA     TBLOPC(PC),A0  A0 = PTR TO TABLE OF CODES
M410     MOVE.L  A3,A2          A3 = START OF STORE BUFFER
         ADD.L   #FOC,A2        A2 = PTR TO OP-CODE JUST FORMATTED

M415     MOVE.B  (A0)+,D0       XXXXXXDD
         EXT.W   D0             XXXXSSDD  SIGN EXTENDED
         ANDI.B  #$7F,D0
         CMP.B   (A2)+,D0
         BNE.S   M420           NON-MATCH
         TST.W   D0
         BPL     M415           SIGN RESET* CONTINUE
         BRA.S   M430           MATCH COMPLETE

M420     TST.W   D0             SEQUENCE TO NEXT CODE
         BMI.S   M426
M424     MOVE.B  (A0)+,D0
         BPL     M424           FINISH THIS OP-CODE
M426     ADDQ.L  #3,A0          ADJUST PTR TO TABLE
         LEA     TBLOPCE(PC),A2
         CMP.L   A0,A2
         BNE     M410

M428     MOVEQ   #FOC,D7        ERROR CODE
         BRA     ERDONE

* GET GOTO INDEX
* GET FIRST WORD MASK
M430     MOVE.B  (A2),D0        MUST TERMINATE OP-CODE
         CMPI.B  #BLANK,D0        WITH SPACE OR PERIOD
         BEQ.S   M432
         CMPI.B  #'.',D0
         BNE     M428           ERROR
M432

         CLR.L   D0
         MOVE.B  (A0)+,D0       D0 =  KEYS  INDEX
         MOVE.B  D0,D1          D1 =  KEYS (INDEX)
         ANDI.B  #$3F,D0        D0 =        INDEX
         ASL.L   #1,D0          INDEX * TWO
         MOVE.B  (A0)+,D2
         LSL.W   #8,D2
         MOVE.B  (A0)+,D2       D2 = FIRST WORD MASK
         MOVE.W  D2,(A1)        *D2,TDATA(A1)

* INSURE .S .W MATCH OP-CODE

         MOVE.B  TLSPEC(A1),D3  D3 = .n SPECIFIED
         BEQ.S   M4326          NOT SPECIFIED
         BTST    #6,D1
         BEQ.S   M4324          .W ALLOWED (.S NOT ALLOWED)
         CMPI.B  #'W',D3
         BEQ     M428           .W NOT ALLOWED
         CMPI.B  #'B',D3
         BEQ     M428           .B NOT ALLOWED
         BRA.S   M4326

M4324    CMPI.B  #'S',D3
         BNE.S   M4326          Not .S, continue
* .S specified — allow for FPU instructions (index >= 38)
         MOVE.W  D1,D3
         ANDI.B  #$3F,D3
         CMPI.B  #38,D3
         BCC.S   M4326          FPU: .S allowed (single precision)
         BRA     M428           non-FPU: .S not allowed
M4326

* CALCULATE GOTO ADDRESS

         LEA     TBLKEYS(PC),A0 A0 = PTR TO KEYS
         MOVE.W  (A0,D0),D0     D0 = 16 BIT OFFSET
         LEA     XBASE(PC),A2   A2 = BASE ADDRESS
         ADD.L   D0,A2          A2 = COMPUTED GO TO  ADDRESS

* FORMAT OPERAND IF REGUIRED

         TST.B   D1             LOOK AT KEY
         BMI.S   M440NOC        OPERAND NOT REQUIRED

         MOVE.L  A3,A0
         ADD.L   #FOP,A0        STORE POINTER
         MOVE.L  A0,PTROP(A1)   POINTER TO OPERAND (FORMATED)
M435     BSR.S   GETCHARF       D0 = CHAR
         CMPI.B  #BLANK,D0
         BEQ     M435           SKIP SPACES

M437     MOVE.B  D0,(A0)+       MOVE REST OF SOURCE LINE
         BSR.S   GETCHARF       D0 = CHAR
         CMP.L   A5,A6
         BPL     M437
         MOVE.L  A0,PTRBUFE(A1) POINTER TO END FORMATED SOURCE
         MOVE.L  A0,A6          A6 = POINTER TO END OF SOURCE
         BRA.S   M440
M440NOC
* No operand — point PTROP at a null so CMMD2 termination check passes
         MOVE.L  A6,PTROP(A1)   A6 = end of source (points at null/space)
M440
         MOVE.L  PTROP(A1),A5   A5 = PTR TO OPERAND
         LEA.L   DATASTR+2,A4 A4 = BASE ADDR FOR DATA STORE
         CLR.L   D3             D3 = OFFSET FOR DATA STORE
         JMP     (A2)           GOTO ROUTINE
*                               D2 = MASK
*                               D4 = P-COUNTER

COMMA    CMPI.B  #BLANK,(A5)
         BNE.S   COMMA1
         ADDQ.L  #1,A5          SKIP SPACE BEFORE COMMA
         BRA.S   COMMA
COMMA1   CMPI.B  #',',(A5)+
         BNE.S   ER             NOT COMMA
COMMA2   CMPI.B  #BLANK,(A5)
         BNE.S   COMMA3
         ADDQ.L  #1,A5          SKIP SPACE AFTER COMMA
         BRA.S   COMMA2
COMMA3   RTS

GETCHAR  CMP.L   A5,A6
         BMI.S   ER
         MOVE.B  (A5)+,D0
         RTS

GETCHARF CMP.L   A5,A6
         BMI.S   ERF
         MOVE.B  (A5)+,D0
         RTS

ERF      MOVE.L  A0,A5

ER       MOVE.L  A5,D7          D7 = ERROR FLAG
         SUB.L   A3,D7          ..& POSITION OF ERROR
ERDONE   CLR.L   D6             D6 = (ZERO) BYTE COUNT
         BRA.S   CMMD35

CMMD2    CMPI.B  #BLANK,(A5)
         BEQ.S   MCMMD2         SPACE — VALID TERMINATION
         TST.B   (A5)
         BEQ.S   MCMMD2         NULL — VALID TERMINATION (END OF INPUT)
         CMP.L   A6,A5          AT OR PAST END OF BUFFER?
         BPL.S   MCMMD2         YES — VALID TERMINATION
         BRA     ER             OPERAND DID NOT END CLEANLY

MCMMD2   DS      0              NO OPERAND SEQUENCE
         MOVE.W  D2,(A1)        *D2,TDATA(A1)

         CLR.L   D3
         MOVE.B  TNB(A1),D3     FORMAT DATA
         MOVE.L  D3,D6          D7 = NUMBER OF BYTES
         LEA     (A1),A2        A2 = PTR TO HEX DATA  *TDATA(A1),A2
         MOVE.L  A3,A6          D3 = NUMBER OF BYTES
         ADD.L   #FDATA,A6      A6 = STORE PTR
FPR315   MOVE.B  (A2)+,D0
         BSR     PNT2HX
         SUBQ.L  #1,D3
         BNE     FPR315         MORE BYTES

         CLR.L   D7             RESET ERROR FLAG

CMMD35   MOVEM.L (A1),D0-D3       D0-D3 = DATA   *TDATA(A1),D0-D3

         MOVE.L  PTRBUFE(A1),A6   A6 = POINTER TO END OF BUFFER

         MOVE.L  PCOUNTER(A1),A4  A4 = ORGINAL PC

  *       MOVE.L  LINK(A1),A1
  *       UNLK    A1
         MOVE.L  LINK(A1),A7    RESTORE SP (CLEANS UP NESTED BSR RETURNS ON ERROR PATH)
         RTS                    RETURN TO REQUESTOR
*                               A3 = POINTER TO START OF BUFFER
*                               D6 = NUMBER OF BYTES ASSEMBLED
*                               D7 = ERROR FLAG (POSITION)


*  SIZE = BYTE
*    DY,DX
*    -(AY),-(AX)
*    ....RX@.SS...RY@
MABCD    DS      0              (INDEX 0) ABCD SBCD
         TST.B   TLSPEC(A1)
         BEQ.S   MABCD9         DEFAULT SIZE = BYTE
         CMPI.W  #$00,TLENGTH(A1)
         BNE     ER             NOT .B
MABCD9

         MOVE.W  #$11,D7
         BSR     EA

         BSR     COMMA

         MOVE.L  D6,D0
         ANDI.W  #7,D0
         OR.W    D0,D2

         BTST    #5,D6
         BEQ.S   MABCD55        D@,D@ MODE

         ORI.W   #$0008,D2      -(A@),-(A@) MODE

         MOVE.W  #$10,D7
         BSR     EA

         ANDI.W  #7,D6
         ROR.W   #7,D6
         OR.W    D6,D2
         BRA     CMMD2

MABCD55  BSR     GETREGD        D@,D@
         ROR.W   #7,D0
         OR.W    D0,D2
CMMD2S10 BRA     CMMD2


MCMP     DS      0              (INDEX 34)
         BSR     EAALL
         MOVE.L  D6,D4          D4 = SOURCE MODE

         BSR.S   COMMAS20

         CMPI.B  #'A',(A5)
         BEQ     MADDA21        DESTINATION = A@

         CMPI.B  #$3C,D4
         BEQ.S   MCMP56         SOURCE  ....I  #<DATA>,...

         BSR     FSIZE

         MOVE.W  #$009,D7
         BSR     EA             D@ + (A@)+
         MOVE.L  D6,D0          MMMRRR
         ANDI.W  #$38,D0        MMM...

         BEQ.S   MCMP39         DESTINATION  D@

         CMPI.B  #$18,D0
         BNE     ER

         ANDI.W  #$F,D6         (AY)+,(AX)+
         ROR.W   #7,D6
         OR.W    D6,D2          ....AX@.........
         ORI.W   #$0100,D2      ...1AX@.........

         MOVE.L  D4,D0
         ANDI.W  #$38,D0
         CMPI.W  #$18,D0
         BNE     ER             NOT (A@)+
         ANDI.W  #$F,D4         ............1AY@
         OR.W    D4,D2
         BRA     CMMD2

*  <EA>,D@
MCMP39   ROR.W   #7,D6
         OR.W    D6,D2

         OR.W    D4,D2
         BRA.S   CMMD2S11

MCMP56   MOVE.W  #$0C00,D2      #<DATA>,<EA>      MASK = CMPI

         BSR     FSIZE

         BSR     EADA
         OR.W    D6,D2
CMMD2S11 BRA     CMMD2S10

COMMAS20 BRA     COMMA

MADD     DS      0              (INDEX 1)
         BSR     EAALL
         MOVE.L  D6,D4          D4 = SOURCE MODE

         BSR     COMMAS20

         CMPI.B  #'A',(A5)
         BEQ     MADDA21        DESTINATION = A@

         CMPI.B  #$3C,D4
         BEQ.S   MADD56         SOURCE  ....I  #<DATA>,...

         BSR     FSIZE

         MOVE.W  #$1FF,D7
         BSR     EA             ALTERABLE + D@
         MOVE.L  D6,D0          MMMRRR
         ANDI.W  #$38,D0        MMM...
         BNE.S   MADD46         DESTINATION NOT  D@

*  <EA>,D@
         ROR.W   #7,D6
         OR.W    D6,D2

         OR.W    D4,D2
         BRA     CMMD2S11

MADD46   DS      0              D@,<EA>
         ORI.W   #$100,D2

         ROR.W   #7,D4
         OR.W    D4,D2          <EA> AS DESTINATION

         OR.W    D6,D2          D@  AS SOURCE
         BRA     CMMD2S11

MADD56   MOVE.L  D2,D0          #<DATA>,<EA>
         MOVE.W  #$0600,D2      MASK = ADDI

         CMPI.W  #$D000,D0
         BEQ.S   MADD58
         MOVE.W  #$400,D2       MASK = SUBI
MADD58

         BSR     FSIZE

         BSR     EADA           DATA ALTERABLE ONLY
         OR.W    D6,D2
         BRA     CMMD2S11

MADDI    MOVE.L  PTROP(A1),A5   (INDEX 3) CMPI
         BSR     FSIZE

         BSR     EAZ

         BSR     COMMAS20

         BSR     EADA           DATA ALTERABLE ONLY
         OR.W    D6,D2
         BRA     CMMD2S11

*  SIZE =  BYTE,WORD,LONG
*  #<DATA>,SR
*  #<DATA>,<EA>    DATA ALTERABLE ONLY
MANDI    DS      0              (INDEX 28) ANDI EORI ORI
         BSR     FSIZE

         BSR     EAZ

         BSR     COMMAS20

         CMPI.B  #'S',(A5)
         BEQ.S   MANDI23

         BSR     EADA
         OR.W    D6,D2
         BRA     CMMD2S11

MANDI23  CMPI.B  #'R',1(A5)     #<DATA>,SR
         BNE     ER
         CMPI.W  #$0080,TLENGTH(A1)
         BEQ     ER             .L NOT ALLOWED WITH SR
         ORI.W   #$003C,D2
         ADDQ.L  #2,A5          POINTER TO END OF OPERAND
         BRA     CMMD2

MADDA    DS      0              (INDEX 2)
         BSR     EAALL
         OR.W    D6,D2

         BSR     COMMA

MADDA21  OR.W    D6,D2
         MOVE.W  TLENGTH(A1),D0
         BEQ     ER             .BYTE NOT ALLOWED
         LSL.W   #1,D0          .W = 011......
         ORI.W   #$00C0,D0      .L = 111......
         OR.W    D0,D2

         BSR     GETREGA
         ROR.W   #7,D0
         OR.W    D0,D2
         BRA     CMMD2

MADDQ    DS      0              (INDEX 4)
         BSR     FSIZE

         BSR     GETIMM

         TST.L   D0
         BEQ     ER             DATA = ZERO
         CMPI.B  #9,D0
         BPL     ER             VALUE TOO BIG
         ANDI.W  #$7,D0         MAKE 8 = 0
         ROR.W   #7,D0          SHIFT DATA TO BITS 9-11
         OR.W    D0,D2

         BSR     COMMA

         BSR     EAA            ALTERABLE ADDRESSING

         OR.W    D6,D2
         MOVE.L  D2,D0
         ANDI.W  #$C0,D0
         BNE.S   MADDQ25

* BYTE SIZE* ADDRESS REGISTER DIRECT NOT ALLOWED
         MOVE.L  D2,D0
         ANDI.W  #$38,D0
         CMPI.B  #$08,D0
         BEQ     ER
MADDQ25  BRA     CMMD2

* SIZE = BYTE,WORD,LONG
*    DY,DX
*    -(AY),-(AX)
*    ....RX@.SS...RY@
MADDX    DS      0              (INDEX 5)
         BSR     FSIZE

         MOVE.W  #$11,D7
         BSR     EA

         BSR     COMMA

         MOVE.L  D6,D0
         ANDI.W  #7,D0
         OR.W    D0,D2

         BTST    #5,D6
         BEQ.S   MADDX5         D@,D@ MODE

         ORI.W   #$0008,D2      -(A@),-(A@) MODE

         MOVE.W  #$10,D7
         BSR     EA

         ANDI.W  #7,D6
         ROR.W   #7,D6
         OR.W    D6,D2
         BRA     CMMD2

MADDX5   BSR     GETREGD        D@,D@
         ROR.W   #7,D0
         OR.W    D0,D2
         BRA     CMMD2

*  SIZE = BYTE,WORD,LONG
*         <EA>,D@
*         D@,<EA>
MAND     BSR     FSIZE          (INDEX 6)

         CMPI.B  #'#',(A5)
         BEQ.S   MAND90

         BSR     A5TODEST       MOVE A5 TO DESTINATION

         MOVE.B  (A5),D0        D0 = 1ST CHAR OF DESTINATION
         MOVE.L  PTROP(A1),A5   A5 = POINTER TO OPERAND
         CMPI.B  #'D',D0
         BEQ.S   MAND77

         ORI.W   #$0100,D2       D@,<EA>

         BSR     GETREGD
         ROR.W   #7,D0
         OR.W    D0,D2

         BSR     COMMA

         BSR     EAM            ALTERABLE MEMORY
         OR.W    D6,D2
         BRA     CMMD2

MAND77   BSR     EADADDR        <EA>,D@
         OR.W    D6,D2

         BSR     COMMA

         BSR     GETREGD
         ROR.W   #7,D0
         OR.W    D0,D2
         BRA     CMMD2

MAND90   ANDI.W  #$F000,D2
         CMPI.W  #$C000,D2
         BEQ.S   MAND97          AND
         MOVE.W  #$0000,D2      CHANGE TO "ORI"
MAND91   BRA     MANDI
MAND97   MOVE.W  #$0200,D2      CHANGE TO "ADDI"
         BRA     MAND91

MEOR     BSR     FSIZE          (INDEX 35)

         CMPI.B  #'#',(A5)
         BEQ.S   MEOR90

         BSR     GETREGD
         ROR.W   #7,D0
         OR.W    D0,D2

         BSR     COMMA

         BSR     EADA           DATA ALTERABLE ADDRESSING
         OR.W    D6,D2
         BRA     CMMD2

MEOR90   MOVE.L  PTROP(A1),A5   A5 = POINTER TO OPERAND
         MOVE.W  #$0A00,D2      CHANGE TO "EORI"
         BRA     MANDI

A5TODEST CLR.L   D1             MOVE A5 TO DESTINATION
A5300    BSR     GETCHAR
         CMPI.B  #'(',D0
         BNE.S   A5305
         MOVE.L  D0,D1
A5305    CMPI.B  #')',D0
         BEQ     A5TODEST
         CMPI.B  #',',D0
         BNE     A5300
         TST     D1
         BNE     A5300
         RTS

MASL     DS      0              (INDEX 7)

*         ASL     LSL     ROL     ROXL
*  MASKS  E000    E008    E018    E010
*         E0C0    E2C0    E6C0    E4C0   SHIFT MEMORY

         BSR     FSIZE

         MOVE.B  (A5)+,D0
         CMPI.B  #'#',D0
         BNE.S   MSL200

*  #<COUNT>,D@
         BSR     EV
         CMPI.L  #8,D0
         BGT     ER             GREATER THAN 8

         ANDI.B  #$7,D0         MAKE 8 INTO 0
MSL150   ROR.W   #7,D0
         ANDI.W  #$F1FF,D2
         OR.W    D0,D2          COUNT/REG

         BSR     COMMA

         BSR     GETREGD
         OR.W    D0,D2
         BRA     CMMD2

MSL200   DS      0              D@,D@
         CMPI.B  #'D',D0
         BNE.S   MSL300

*        D@,D@
         ORI.W   #$20,D2
         SUBQ.L  #1,A5
         BSR     GETREGD
         BRA     MSL150

MSL300   DS      0              <EA>      SHIFT MEMORY
         SUBQ.L  #1,A5
         ORI.W   #$00C0,D2      SIZE = MEMORY

         ANDI.W  #$FFC0,D2      REMOVE "SHIFT MEMORY" BITS

         CMPI.W  #$0040,TLENGTH(A1)
         BNE.S   ER2            NOT .WORD

         BSR     EAM
         OR.W    D6,D2
         BRA     CMMD2

MSCC     BSR     SIZEBYTE       (INDEX 29) NBCD SCC TAS

         BSR     EADA           DATA ALTERABLE ONLY
         OR.W    D6,D2
         BRA     CMMD2

MBCHG    DS      0              (9)
         CMPI.B  #'#',(A5)
         BNE.S   MB200

         MOVE.W  #$0840,D2      NEW OP-CODE MASK

MB100    ADDQ.L  #1,A5
         BSR     EV             EVALUATE EXPRESSION
         CMPI.L  #33,D0
         BGT.S   ER2            (MODULO 32)
         MOVE.W  D0,2(A1)
         ADDQ.L  #2,D3          STORE POINTER

         ADDQ.B  #2,TNB(A1)

MB105    BSR     COMMA

         BSR     EADA           DESTINATION
         OR.W    D6,D2

         TST.B   TLSPEC(A1)     ..
         BEQ.S   MB185          DEFAULT

         ANDI.W  #$0038,D6
         BNE.S   MB145          DESTINATION <EA> WAS NOT D@

         CMPI.W  #$80,TLENGTH(A1)  DESTINATION <EA> WAS D@
         BEQ.S   MB185          LENGTH IS .L
ER2      BRA     ER

MB145    TST.W   TLENGTH(A1)
         BNE     ER2            NOT BYTE LENGTH

MB185    BRA     CMMD2

MB200    BSR     GETREGD        DYNAMIC
         ROR.W   #7,D0
         OR.W    D0,D2

         BRA     MB105

MBSET    CMPI.B  #'#',(A5)      (INDEX 11) BCLR BSET
         BNE     MB200

         MOVE.W  #$08C0,D2
         BRA     MB100

MBCLR    CMPI.B  #'#',(A5)      (INDEX 30)
         BNE     MB200

         MOVE.W  #$0880,D2
         BRA     MB100

MBTST    CMPI.B  #'#',(A5)      (INDEX 31)
         BNE     MB200

         MOVE.W  #$0800,D2
         BRA     MB100

MDBCC    DS      0              (INDEX 8)
         BSR     GETREGD
         OR.W    D0,D2

         BSR     COMMA
         BSR.S   EVSR
         BRA.S   MBRA23

*  SIZE   .S  =  .W   (DEFAULT)
*         .L  =  .L
MBRA     DS      0              (INDEX 10)
         BSR.S   EVSR

         CMPI.W  #$0080,TLENGTH(A1)
         BEQ.S   MBRA23         FORCED LONG

         BSR     EA8BITS        -128 TO +127
         BNE.S   MBRA23         NOT 8 BIT VALUE

         OR.B    D5,D2
         BRA     CMMD2          .SHORT

EVER     BRA     ER             ERROR HANDLER

MBRA23   TST.B   TLSPEC(A1)
         BEQ.S   MBRA27
         CMPI.W  #$0040,TLENGTH(A1)
         BEQ     EVER           .S SPECIFIED
MBRA27

         MOVE.L  D4,D5          RESTORE D5
         BSR     EA16BITS       -32K TO +32K
         MOVE.W  D5,2(A1)
         ADDQ.B  #2,TNB(A1)
         BRA     CMMD2

EVSR     BSR     EV
         CMPI.B  #BLANK,(A5)
         BNE     EVER           DID NOT TERMINATE WITH SPACE

         MOVE.L  D0,D5
         ASR.L   #1,D0
         BCS     EVER           ODD VALUE
         MOVE.L  PCOUNTER(A1),D4
         ADDQ.L  #2,D4          D4 = PC + 2
         SUB.L   D4,D5
         BEQ     EVER           ZERO* SPECIAL CASE ERROR
         MOVE.L  D5,D4
         RTS

MCHK     DS      0              (INDEX 12) CHK DIV MUL
         BSR     SIZEWORD

         BSR     EADADDR        DATA ADDRESSING ONLY
         OR.W    D6,D2

         BSR     COMMA

         BSR     GETREGD
         ROR.W   #7,D0
         OR.W    D0,D2

         BRA     CMMD2

MCLR     DS      0              (INDEX 13)
         BSR     FSIZE

         BSR     EADA           DATA ALTERABLE ONLY
         OR.W    D6,D2
         BRA     CMMD2

* SIZE = BYTE,WORD,LONG
MCMPM    DS      0              (INDEX 14)
         BSR     FSIZE

         MOVE.W  #$0008,D7
         BSR     EA             -(A@)   ONLY
         ANDI.W  #7,D6
         OR.W    D6,D2

         BSR     COMMA

         MOVE.W  #$0008,D7
         BSR     EA
         ANDI.W  #7,D6
         ROR.W   #7,D6
         OR.W    D6,D2
         BRA     CMMD2

MEXG     DS      0              (INDEX 16)
         BSR     SIZELONG

         BSR     GETREGAD
         MOVE.L  D0,D4          D4 = REG NUMBER
         MOVE.L  D1,D5          D5 = REG TYPE

         BSR     COMMA          TEST FOR COMMA

         BSR     GETREGAD

         CMP.L   D1,D5
         BEQ.S   MEXG35         BOTH REGS THE SAME

*  DX,AY  OR  AY,DX
         ORI.W   #$88,D2        MODE
         TST.B   D1
         BNE.S   MEXG25

         EXG     D0,D4          SWAP SOURCE & DESTINATION

MEXG25   OR.W    D0,D2          .......MMMMMYYY
         ROR.W   #7,D4
         OR.W    D4,D2          ....XXXMMMMMYYY
         BRA     CMMD2

MEXG35   ORI.W   #$0040,D2      OP-MODE
         TST.B   D1
         BEQ     MEXG25         DX,DY

         ORI.W   #$0048,D2      AX,AY
         BRA     MEXG25


MEXT     DS      0              (INDEX 17)
         TST.W   TLENGTH(A1)
         BEQ     ER             BYTE SIZE NOT ALLOWED

         BSR     FSIZE          .W = ........10......
         ADDI.W  #$0040,D2      .L = ........11......

         BSR     GETREGD
         OR.W    D0,D2
         BRA     CMMD2

MMOVEM   DS      0              (INDEX 27)
         MOVE.W  TLENGTH(A1),D0 SIZE BITS  76 TO 6
         BEQ     ER             BYTE       00  ERROR
         LSR.W   #1,D0          WORD       01    0
         ANDI.W  #$0040,D0      LONG       10    1
         OR.W    D0,D2

         ADDQ.B  #2,TNB(A1)     NUMBER OF BYTES
         ADDQ.L  #2,D3          FORCE STORE PTR PAST MASK

         CMPI.B  #'A',(A5)
         BEQ.S   MMM44
         CMPI.B  #'D',(A5)
         BEQ.S   MMM44

*    <EA>,<REGISTER LIST>       MEMORY TO REGISTER
         ORI.W   #$0400,D2      DIRECTION BIT

         MOVE.W  #$7EC,D7       MODES ALLOWED
         BSR     EA
         OR.W    D6,D2

         BSR     COMMA

         BSR.S   MMM48
         BRA     CMMD2


*   <REGISTER LIST>,<EA>        REGISTER TO MEMORY
MMM44    DS      0

* EVALUATE DESTINATION FIRST
MMM46    BSR     GETCHAR
         CMPI.B  #',',D0        FIND COMMA
         BNE     MMM46

         MOVE.W  #$1F4,D7       MODES ALLOWED
         BSR     EA
         OR.W    D6,D2
         MOVE.L  A5,PENDOP(A1)  END OF OPERAND
         MOVE.L  PTROP(A1),A5
         BSR.S   MMM48          EVALUATE REGISTERS
         MOVE.L  PENDOP(A1),A5  POINTER TO END OF OPERAND
         BRA     CMMD2

*        D6 = CORRESPONDENCE MASK
*        D4 = CONTROL  $FF '-BLANK/'
MMM48    CLR.L   D6             MASK
         MOVEQ   #-1,D4         CONTROL = $FF

RL111    BSR     GETCHAR
         CMPI.B  #',',D0
         BEQ.S   RL114          DONE* FOUND COMMA
         CMPI.B  #BLANK,D0
         BNE.S   RL115          NOT SPACE
RL114    RTS     DONE

RL115    CMPI.B  #'/',D0
         BNE.S   RL444

         TST.B   D4             CONTROL
         BMI     ER
         MOVE.L  D0,D4          CONTROL = '/'
RL333    BSR     GETREGAD
         OR.B    D0,D1          D1 = BIT POSITION
         MOVE.B  D1,D5          D5 = LAST REGISTER ENTERED
         BSR.S   SETBIT
         BRA     RL111

RL444    CMPI.B  #'-',D0
         BNE.S   RL666

         CMPI.B  #'/',D4        CONTROL
         BNE     ER
         MOVE.L  D0,D4          CONTROL = '-'
         BSR     GETREGAD
         OR.B    D0,D1
         MOVE.L  D1,D7          D7 = NOW REGISTER
         MOVE.B  D5,D0          D5 = LAST REG
         EOR.B   D1,D0
         ANDI.B  #$38,D0
         BNE     ER             NOT MATCED SET
         CMP.B   D1,D5
         BPL     ER

RL555    ADDQ.L  #1,D5
         MOVE.L  D5,D1
         BSR.S   SETBIT
         CMP.B   D7,D5
         BMI     RL555
         BRA     RL111

RL666    TST.B   D4
         BPL     ER
         MOVE.B  #'/',D4        CONTROL = '/'
         SUBQ.L  #1,A5
         BRA     RL333

SETBIT   LEA     MTBL(PC),A0    SET BIT IN CORRESPONDENCE MASK
         MOVE.L  D2,D0
         ANDI.W  #$38,D0
         CMPI.W  #$20,D0
         BNE.S   RL30           NOT PREDECREMENT
         MOVE.B  (A0,D1),D1     D1 = BIT  (FOR SURE)
RL30     BSET    D1,D6

         MOVE.W  D6,2(A1) SAVE CORRESPONDENCE MASK
         RTS

MTBL     DC.B    15,14,13,12,11,10,9,8,7,6,5,4,3,2,1,0




*   D@,<DATA>(A@)
*   <DATA>(A@),D@
*         (A@),D@            FORCED TO 0(A@),D0
*         D@,(A@)            FORCED TO D0,0(A@)
*
*  SIZE = WORD,LONG
MMOVEP   DS      0              (INDEX 33)
         MOVE.W  TLENGTH(A1),D0
         BEQ     ER             .BYTE NOT ALLOWED
         LSR.W   #1,D0
         ANDI.W  #$0040,D0
         OR.W    D0,D2          SIZE

         MOVE.W  #$25,D7
         BSR     EA             D6 = MODE

         BSR     COMMA

         MOVE.L  D6,D0
         ANDI.W  #$38,D0
         CMPI.B  #$0,D0
         BEQ.S   MMP344         D@,<DATA>(A@)

*    <DATA>(A@),D@
         BSR     GETREGD
         ROR.W   #7,D0
         OR.W    D0,D2          D@
         BRA.S   MMP348

MMP344   ORI.W   #$0080,D2      REGISTER TO MEMORY

         ROR.W   #7,D6
         OR.W    D6,D2          D@

         MOVE.W  #$24,D7
         BSR     EA
MMP348   MOVE.L  D6,D0
         ANDI.W  #7,D6
         OR.W    D6,D2          A@

         ANDI.W  #$38,D0
         CMPI.B  #$10,D0
         BNE.S   MMP368         <DATA>(A@)

         CLR.W   2(A1)    <DATA> FORCED TO ZERO*  "(A@)"
         ADDQ.B  #2,TNB(A1)     NUMBER OF BYTES
         ADDQ.L  #2,D3          STORE POINTER
MMP368   BRA     CMMD2

MMOVEQ   DS      0              (INDEX 34)
         BSR     GETIMM
         MOVE.L  D0,D5

         BSR     EA8BITS        -128 TO +127
         BNE     ER
         OR.B    D5,D2          D5 = VALUE

         BSR     COMMA

         BSR     GETREGD        D@
         ROR.W   #7,D0

MMQ20    OR.W    D0,D2
         BSR.S   SIZELONG
         BRA     CMMD2

SIZELONG TST.B   TLSPEC(A1)     MUST BE .LONG
         BEQ.S   SI201          DEFAULT SIZE OK
         CMPI.W  #$0080,TLENGTH(A1)
         BNE.S   ER10           NOT .LONG
SI201    RTS

SIZEWORD CMPI.W  #$0040,TLENGTH(A1)  MUST BE .WORD
         BEQ     SI201          [RTS]
ER10     BRA     ER

SIZEBYTE TST.B   TLSPEC(A1)
         BEQ.S   SI222          DEFAULT SIZE OK
         TST.W   TLENGTH(A1)
         BNE     ER10
SI222    RTS

MMOVE    DS      0              (INDEX 21)
         CMPI.B  #'S',(A5)
         BNE.S   MMM40
         MOVE.W  #$40C0,D2      SR,<EA>
         ADDQ.L  #1,A5
         CMPI.B  #'R',(A5)+
         BNE     ER10

         BSR     COMMA

         BSR     EADA           DATA ALTERABLE ONLY (DESTINATION)

MM315    OR.W    D6,D2
         BSR     SIZEWORD
         BRA     CMMD2

MMM40    CMPI.B  #'U',(A5)
         BNE.S   MMM50
         ADDQ.L  #1,A5
         CMPI.B  #'S',(A5)+
         BNE     ER10
         CMPI.B  #'P',(A5)+
         BNE     ER10

         BSR     COMMA

         MOVE.W  #$4E68,D2      USP,A@
         BSR     GETREGA
         BRA     MMQ20

* GET EXCEPTIONS FROM DESTINATION
MMM50    DS      0

         BSR     A5TODEST       MOVE A5 TO DESTINATION

         MOVE.B  (A5)+,D0
         CMPI.B  #'C',D0
         BNE.S   MMM60
         CMPI.B  #'C',(A5)+
         BNE     ER10
         CMPI.B  #'R',(A5)+
         BNE     ER10
         MOVE.W  #$44C0,D2      <EA>,CCR

MM508    MOVE.L  A5,PENDOP(A1)  SAVE POINTER
         MOVE.L  PTROP(A1),A5   A5 = POINTER TO OPERAND

         BSR     EADADDR        DATA ADDRESSING ONLY (SOURCE)
         MOVE.L  PENDOP(A1),A5
         BRA     MM315

MMM60    CMPI.B  #'S',D0
         BNE.S   MM70
         MOVE.W  #$46C0,D2      <EA>,SR
         CMPI.B  #'R',(A5)+
         BNE     ER
         BRA     MM508

MM70     CMPI.B  #'U',D0
         BNE.S   MM80
         MOVE.W  #$4E60,D2      A@,USP
         CMPI.B  #'S',(A5)+
         BNE     ER
         CMPI.B  #'P',(A5)+
         BNE     ER

         MOVE.L  A5,PENDOP(A1)
         MOVE.L  PTROP(A1),A5
         BSR     GETREGA
         MOVE.L  PENDOP(A1),A5  RESTORE A5
         BRA     MMQ20

MM80     MOVE.L  PTROP(A1),A5   A5 = POINTER TO SOURCE FIELD
         BSR     FSIZE          GET SIZE (BITS  7 - 6)
         LSL.W   #6,D2          ADJUST TO(BITS 13-12)
         BTST    #13,D2
         BNE.S   MM804          .L 10 TO 10
         ADDI.W  #$1000,D2      .W 01 TO 11
         ORI.W   #$1000,D2      .B 00 TO 01
MM804    BSR     EAALL          SOURCE* ALL MODES ALLOWED
         OR.W    D6,D2

* IF BYTE SIZE* "ADDRESS REGISTER DIRECT" NOT ALLOWED

         MOVE.L  D2,D0
         ANDI.W  #$3000,D0
         CMPI.W  #$1000,D0
         BNE.S   MM806          NOT .B SIZE
         ANDI.B  #$38,D6
         CMPI.B  #$08,D6
         BEQ     ER
MM806    DS      0

         BSR     COMMA

         MOVE.W  #$1FF,D7       DATA ALTERABLE + A@
         BSR     EA

         MOVE.L  D6,D0          DESTINATION
         ANDI.W  #$0038,D0
         CMPI.W  #$0008,D0
         BEQ.S   MMOVEA1        A@ MAKE MOVEA

* POSITION REGISTER AND MODE OF DESTINATION

MM825    ROR.L   #3,D6          RRR............. .............MMM
         ROR.W   #3,D6                           MMM.............
         SWAP    D6             MMM............. RRR.............
         ROL.W   #3,D6                           .............RRR
         ROL.L   #1,D6          MM.............. ............RRRM
         ROL.L   #8,D6          ................ ....RRRMMM......
         OR.W    D6,D2
         BRA     CMMD2

MMOVEA1  CLR.L   D3
         MOVE.B  #2,TNB(A1)

MMOVEA   DS      0              (INDEX 32)
         MOVE.L  PTROP(A1),A5   A5 = POINTER TO OPERAND

         MOVE.W  TLENGTH(A1),D2 D0 = SIZE
         BEQ     ER             .BYTE NOT ALLOWED

         LSL.W   #6,D2          .SIZE
         BTST    #12,D2
         BEQ.S   MMA225         .L = ..10
         ORI.W   #$3000,D2      .W = ..11
MMA225

         BSR     EAALL          ALL MODES ALLOWED
         OR.W    D6,D2

         BSR     COMMA

         MOVE.W  #$0002,D7      A@ ONLY
         BSR     EA
         BRA     MM825


MJMP     DS      0              (INDEX 18)
         TST.B   TLSPEC(A1)
         BEQ.S   MJMP32         DEFAULT (ALLOW EITHER .S OR .L)
         MOVE.W  TLENGTH(A1),D0
         BEQ     ER             .B NOT ALLOWED
         MOVE.W  #$6E4,D7       D7 = MODES ALLOWED
         CMPI.W  #$40,D0
         BEQ.S   MJMP22         .S SPECIFIED (.W ACCEPTED)
         MOVE.W  #$8764,D7      MODE FOR .L
MJMP22   BSR     EA
         BRA.S   MJMP42

MJMP32   BSR     EAC            CONTROL ADDRESSING ONLY
MJMP42   OR.W    D6,D2
         BRA     CMMD2

* SIZE = LONG
MLEA     DS      0              (INDEX 19)
         BSR     SIZELONG

         BSR     EAC            CONTROL ADDRESSING ONLY
         OR.W    D6,D2

         BSR     COMMA

         BSR     GETREGA
         ROR.W   #7,D0
         OR.W    D0,D2
         BRA     CMMD2


* SIZE = LONG
MPEA     DS      0              (INDEX 36)
         BSR     SIZELONG

         BSR     EAC            CONTROL ADDRESSING ONLY
         OR.W    D6,D2
         BRA     CMMD2

MSWAP    DS      0              (INDEX 24)
* SIZE WORD
         CMPI.W  #$0040,TLENGTH(A1)
         BNE     ER             NOT .W

         BSR     GETREGD        D@ ONLY
         OR.W    D0,D2
         BRA     CMMD2

GETIMM   CMPI.B  #'#',(A5)+
         BNE     ER

         BSR     EV             EVALUATE EXPRESSION
         RTS                    D0 = VALUE

MLINK    BSR     GETREGA        (INDEX 20)
         OR.W    D0,D2

         BSR     COMMA

         BSR     GETIMM
         MOVE.L  D0,D5
         BSR     EA16BITS       -32K TO +32K
         MOVE.W  D0,2(A1)

         ADDQ.B  #2,TNB(A1)
         BRA     CMMD2

MSTOP    DS      0              (INDEX 23)
* UNSIZED
         BSR     GETIMM
         CMPI.L  #$00010000,D0
         BCC     ER
         MOVE.W  D0,2(A1)
         ADDQ.B  #2,TNB(A1)
         BRA     CMMD2

MTRAP    DS      0              (INDEX 25)
         BSR     GETIMM
         CMPI.L  #16,D0
         BCC     ER
         OR.W    D0,D2
         BRA     CMMD2

MUNLK    DS      0              (INDEX 26)
* UNSIZED
         BSR     GETREGA
         OR.W    D0,D2
         BRA     CMMD2

MDC      DS      0              (INDEX 37) .W ONLY ALLOWED
         BSR     EV
         MOVE.L  D0,D5
         BSR     EA16BIT        ONLY .W ALLOWED     -32K TO +64K
         MOVE.W  D5,D2
         BRA     CMMD2

*------------------------------------------------------------------------
* MFPU form handler  (INDEX 38) FPU instructions
* D2 = OPC mask word: high=$00, low=FP opcode
*       $FF = FMOVECR, $00 = FMOVE, else = arithmetic
*
* FP opcode saved to FPUSCR(A1) — preserves D4 (PC) for EA/GETFIELD.
* Scratch values saved to FPUSCR+2(A1) — avoids stack pushes before EA
* so that ER→ERDONE→RTS cannot corrupt the stack.
*------------------------------------------------------------------------
MFPU     DS      0
         MOVE.W  D2,D0
         ANDI.W  #$FF,D0
         MOVE.W  D0,FPUSCR(A1)   FP opcode → scratch (preserves D4=PC)

* Check for FMOVECR ($FF sentinel)
         CMPI.B  #$FF,D0
         BEQ     MFPU_MCR

* Check TLSPEC: if format suffix present, memory operand
         TST.B   TLSPEC(A1)
         BNE     MFPU_FMT

* No format suffix — register to register: FPsrc,FPdst
         CMPI.B  #'F',(A5)
         BNE     ER

*--- Register to register: FPsrc,FPdst ---
MFPU_R2R BSR     GETFPREG        D0 = source FP reg
         MOVE.W  D0,D5           D5 = source FP reg

* Check for FTST (opcode $3A, single operand)
         MOVE.W  FPUSCR(A1),D1
         CMPI.B  #$3A,D1
         BEQ.S   MFPU_1OP

         BSR     COMMA
         BSR     GETFPREG        D0 = dest FP reg

* Build command word: R/M=0, src=D5[12:10], dst=D0[9:7], opcode[6:0]
         MOVE.W  FPUSCR(A1),D1   FP opcode from scratch
         MOVE.W  D5,D3
         LSL.W   #3,D3
         LSL.W   #7,D3
         OR.W    D3,D1
         LSL.W   #7,D0
         OR.W    D0,D1
         MOVE.W  D1,2(A1)
         ADDQ.B  #2,TNB(A1)
         MOVE.W  #$F200,D2
         BRA     CMMD2

*--- Single operand: FTST FPsrc ---
MFPU_1OP MOVE.W  FPUSCR(A1),D1   FP opcode from scratch
         MOVE.W  D5,D3
         LSL.W   #3,D3
         LSL.W   #7,D3
         OR.W    D3,D1
         MOVE.W  D1,2(A1)
         ADDQ.B  #2,TNB(A1)
         MOVE.W  #$F200,D2
         BRA     CMMD2

*--- Format suffix present: parse format, then dispatch ---
MFPU_FMT BSR     MFPU_PFM        D5 = format code

* For FMOVE (opcode=0): check for FP reg source or control reg
         TST.B   FPUSCR+1(A1)
         BNE     MFPU_EA         Non-FMOVE → always EA,FPn

* FMOVE with format suffix: check source type
         CMPI.B  #'F',(A5)
         BNE     MFPU_EA2        Not 'F' → EA source

* Source starts with 'F': FPn→<ea> or FPcr→<ea>
         CMPI.B  #'P',1(A5)
         BNE     ER
         MOVE.B  2(A5),D0
         CMPI.B  #'C',D0
         BEQ     MFPU_CRS        FPCR source
         CMPI.B  #'S',D0
         BEQ     MFPU_CRS        FPSR source
         CMPI.B  #'I',D0
         BEQ     MFPU_CRS        FPIAR source

* FPn source → FMOVE.fmt FPn,<ea>
         BSR     GETFPREG        D0 = source FP reg
         MOVE.W  D0,FPUSCR+2(A1)   Save source reg to scratch
         MOVE.W  D5,PENDOP(A1)   Save format code to scratch
         BSR     COMMA
         MOVEQ   #2,D3
         MOVE.W  #$1FD,D7        Data alterable
         BSR     EA
         MOVE.W  PENDOP(A1),D5   Restore format
         MOVE.W  FPUSCR+2(A1),D0   Restore source reg

* Build opword: $F200 | EA
         MOVE.W  #$F200,D2
         OR.W    D6,D2

* Build command word: 011 fmt[2:0] src[2:0] 0000000
         MOVE.W  D5,D1
         LSL.W   #3,D1
         LSL.W   #7,D1           fmt to [12:10]
         ORI.W   #$6000,D1       bits 15:13 = 011
         MOVE.W  D0,D3
         LSL.W   #7,D3           src to [9:7]
         OR.W    D3,D1
         MOVE.W  D1,2(A1)
         ADDQ.B  #2,TNB(A1)
         BRA     CMMD2

*--- FMOVE.L FPcr,<ea> (control reg → EA) ---
MFPU_CRS BSR     MFPU_PCR        D0 = reg select bits
         MOVE.W  D0,FPUSCR+2(A1)   Save reg select to scratch
         BSR     COMMA
         MOVEQ   #2,D3
         MOVE.W  #$1FD,D7        Data alterable
         BSR     EA
         MOVE.W  FPUSCR+2(A1),D0   Restore reg select

* Build opword: $F200 | EA
         MOVE.W  #$F200,D2
         OR.W    D6,D2

* Build command word: 101 rrr 0000000000
         MOVE.W  D0,D1
         LSL.W   #8,D1
         LSL.W   #2,D1           reg to [12:10]
         ORI.W   #$A000,D1       bits 15:13 = 101
         MOVE.W  D1,2(A1)
         ADDQ.B  #2,TNB(A1)
         BRA     CMMD2

*--- EA source: check if dest is FPn or FPcr ---
MFPU_EA2 MOVE.W  D5,FPUSCR+2(A1)   Save format to scratch (opcode in LINK)
         BSR     MFPFLIT
         BEQ.S   MFA2_DN         FP literal handled
MFA2_EA  MOVEQ   #2,D3
         MOVE.W  #$FFF,D7        All modes
         BSR     EA
MFA2_DN  MOVE.W  FPUSCR+2(A1),D5   Restore format

         BSR     COMMA

* Check if dest is control reg
         CMPI.B  #'F',(A5)
         BNE     ER
         CMPI.B  #'P',1(A5)
         BNE     ER
         MOVE.B  2(A5),D0
         CMPI.B  #'C',D0
         BEQ     MFPU_CRD        FPCR dest
         CMPI.B  #'S',D0
         BEQ     MFPU_CRD        FPSR dest
         CMPI.B  #'I',D0
         BEQ     MFPU_CRD        FPIAR dest

* FPn dest → FMOVE.fmt <ea>,FPn (standard)
         BSR     GETFPREG        D0 = dest FP reg

* Build opword: $F200 | EA
         MOVE.W  #$F200,D2
         OR.W    D6,D2

* Build command word: R/M=1, fmt=D5[12:10], dst=D0[9:7], opcode=0
         MOVEQ   #0,D1
         ORI.W   #$4000,D1       R/M=1 (bit 14)
         MOVE.W  D5,D3
         LSL.W   #3,D3
         LSL.W   #7,D3
         OR.W    D3,D1
         LSL.W   #7,D0
         OR.W    D0,D1
         MOVE.W  D1,2(A1)
         ADDQ.B  #2,TNB(A1)
         BRA     CMMD2

*--- FMOVE.L <ea>,FPcr (EA → control reg) ---
MFPU_CRD BSR     MFPU_PCR        D0 = reg select bits

* Build opword: $F200 | EA
         MOVE.W  #$F200,D2
         OR.W    D6,D2

* Build command word: 100 rrr 0000000000
         MOVE.W  D0,D1
         LSL.W   #8,D1
         LSL.W   #2,D1           reg to [12:10]
         ORI.W   #$8000,D1       bits 15:13 = 100
         MOVE.W  D1,2(A1)
         ADDQ.B  #2,TNB(A1)
         BRA     CMMD2

*--- Non-FMOVE with format: .fmt <ea>,FPdst ---
MFPU_EA  MOVE.W  D5,FPUSCR+2(A1)   Save format to scratch (opcode in LINK)
         BSR     MFPFLIT
         BEQ.S   MFEA_DN         FP literal handled
MFEA_EA  MOVEQ   #2,D3
         MOVE.W  #$FFF,D7        All addressing modes
         BSR     EA
MFEA_DN  MOVE.W  FPUSCR+2(A1),D5   Restore format

         BSR     COMMA
         BSR     GETFPREG        D0 = dest FP reg

* Build opword: $F200 | EA
         MOVE.W  #$F200,D2
         OR.W    D6,D2

* Build command word: R/M=1, fmt=D5[12:10], dst=D0[9:7], opcode[6:0]
         MOVE.W  FPUSCR(A1),D1   FP opcode from scratch
         ORI.W   #$4000,D1       R/M=1 (bit 14)
         MOVE.W  D5,D3
         LSL.W   #3,D3
         LSL.W   #7,D3
         OR.W    D3,D1
         LSL.W   #7,D0
         OR.W    D0,D1
         MOVE.W  D1,2(A1)
         ADDQ.B  #2,TNB(A1)
         BRA     CMMD2

*--- Parse format suffix from TLSPEC → D5 = format code ---
MFPU_PFM MOVE.B  TLSPEC(A1),D0
         CLR.L   D5
         CMPI.B  #'L',D0
         BEQ.S   MFPF_RT         fmt=0
         MOVEQ   #1,D5
         CMPI.B  #'S',D0
         BEQ.S   MFPF_RT         fmt=1
         MOVEQ   #2,D5
         CMPI.B  #'X',D0
         BEQ.S   MFPF_RT         fmt=2
         MOVEQ   #3,D5
         CMPI.B  #'P',D0
         BEQ.S   MFPF_RT         fmt=3
         MOVEQ   #4,D5
         CMPI.B  #'W',D0
         BEQ.S   MFPF_RT         fmt=4
         MOVEQ   #5,D5
         CMPI.B  #'D',D0
         BEQ.S   MFPF_RT         fmt=5
         MOVEQ   #6,D5
         CMPI.B  #'B',D0
         BEQ.S   MFPF_RT         fmt=6
         ADDQ.L  #4,A7           Pop return address
         BRA     ER              Unknown format
MFPF_RT  RTS

*--- Parse FP control register name → D0 = reg select bits ---
* FPCR=4, FPSR=2, FPIAR=1
MFPU_PCR ADDQ.L  #2,A5           Skip "FP"
         MOVE.B  (A5)+,D0
         CMPI.B  #'C',D0
         BEQ.S   MFPC_CR
         CMPI.B  #'S',D0
         BEQ.S   MFPC_SR
         CMPI.B  #'I',D0
         BEQ.S   MFPC_IAR
         BRA     ER
MFPC_CR  CMPI.B  #'R',(A5)+
         BNE     ER
         MOVEQ   #4,D0           FPCR
         RTS
MFPC_SR  CMPI.B  #'R',(A5)+
         BNE     ER
         MOVEQ   #2,D0           FPSR
         RTS
MFPC_IAR CMPI.B  #'A',(A5)+
         BNE     ER
         CMPI.B  #'R',(A5)+
         BNE     ER
         MOVEQ   #1,D0           FPIAR
         RTS

*--- FMOVECR #offset,FPdst ---
MFPU_MCR CMPI.B  #'#',(A5)+
         BNE     ER
         BSR     EV              D0 = ROM offset
         CMPI.L  #$7F,D0
         BGT     ER
         MOVE.W  D0,D5           D5 = offset
         BSR     COMMA
         BSR     GETFPREG        D0 = dest FP reg

* Build opword
         MOVE.W  #$F200,D2
* Build command word: 010111 ddd ooooooo
         MOVE.W  #$5C00,D1
         LSL.W   #7,D0
         OR.W    D0,D1
         OR.W    D5,D1
         MOVE.W  D1,2(A1)
         ADDQ.B  #2,TNB(A1)
         BRA     CMMD2

*--- Parse "FPn" -> register number 0-7 in D0 ---
GETFPREG CMPI.B  #'F',(A5)+
         BNE     ER
         CMPI.B  #'P',(A5)+
         BNE     ER
         CLR.L   D0
         MOVE.B  (A5)+,D0
         SUBI.B  #'0',D0
         BMI     ER
         CMPI.B  #7,D0
         BGT     ER
         RTS

*------------------------------------------------------------------------
* CHKFPLIT — Check if current operand is a FP literal (#[+-]?digit...dot)
* Entry:  A5 → current text position (should point to '#')
* Return: Z set = FP literal, Z clear = not
* Uses:   D0, A0
*------------------------------------------------------------------------
CHKFPLIT MOVEA.L A5,A0
         CMPI.B  #'#',(A0)+
         BNE.S   .no
         MOVE.B  (A0),D0
         CMPI.B  #'+',D0
         BEQ.S   .sksgn
         CMPI.B  #'-',D0
         BNE.S   .scan
.sksgn   ADDQ.L  #1,A0
.scan    MOVE.B  (A0)+,D0
         CMPI.B  #'.',D0
         BEQ.S   .yes
         SUBI.B  #'0',D0
         BMI.S   .no
         CMPI.B  #9,D0
         BLE.S   .scan
.no      MOVEQ   #1,D0           NE = not FP literal
         RTS
.yes     MOVEQ   #0,D0           EQ = is FP literal
         RTS

*------------------------------------------------------------------------
* FPARSLIT — Parse floating-point literal → IEEE 754 single-precision
* Entry:  A5 → first char of literal (past '#')
* Return: D0 = IEEE 754 single, A5 advanced past literal
* Uses:   D0-D5
*------------------------------------------------------------------------
FPARSLIT CLR.L   D2              Sign (0=positive)
         CMPI.B  #'+',(A5)
         BEQ.S   .sksgn
         CMPI.B  #'-',(A5)
         BNE.S   .pint
         MOVEQ   #1,D2
.sksgn   ADDQ.L  #1,A5

* Parse integer part → D3
.pint    CLR.L   D3
.ilp     CLR.L   D0
         MOVE.B  (A5),D0
         SUBI.B  #'0',D0
         BMI.S   .idn
         CMPI.B  #9,D0
         BGT.S   .idn
         ADDQ.L  #1,A5
         MOVE.L  D3,D1
         LSL.L   #2,D3
         ADD.L   D1,D3
         LSL.L   #1,D3           D3*10
         ADD.L   D0,D3           +digit
         BRA.S   .ilp

* Parse fractional part → D4=numerator, D5=10^n
.idn     CLR.L   D4
         MOVEQ   #1,D5
         CMPI.B  #'.',(A5)
         BNE.S   .cvt
         ADDQ.L  #1,A5
.flp     CLR.L   D0
         MOVE.B  (A5),D0
         SUBI.B  #'0',D0
         BMI.S   .cvt
         CMPI.B  #9,D0
         BGT.S   .cvt
         CMPI.L  #$19999999,D5   Overflow guard (~9 digits max)
         BGT.S   .cvt
         ADDQ.L  #1,A5
         MOVE.L  D4,D1
         LSL.L   #2,D4
         ADD.L   D1,D4
         LSL.L   #1,D4
         ADD.L   D0,D4           D4*10+digit
         MOVE.L  D5,D1
         LSL.L   #2,D5
         ADD.L   D1,D5
         LSL.L   #1,D5           D5*10
         BRA.S   .flp

* D2=sign, D3=integer, D4=frac_num, D5=frac_div
.cvt     TST.L   D3
         BNE.S   .nz
         TST.L   D4
         BNE.S   .nz
         MOVE.L  D2,D0
         ROR.L   #1,D0           ±0.0
         RTS

.nz      TST.L   D3
         BEQ.S   .fonly

* Integer present — find MSB position → D1 (= unbiased exponent)
         CLR.L   D1
         MOVE.L  D3,D0
.fmsb    LSR.L   #1,D0
         BEQ.S   .gotE
         ADDQ.L  #1,D1
         BRA.S   .fmsb

.gotE    CMP.L   #23,D1
         BLE.S   .shL

* Exponent > 23: shift integer right, no room for fraction
         MOVE.L  D1,D0
         SUB.L   #23,D0
.shrR    LSR.L   #1,D3
         SUBQ.L  #1,D0
         BNE.S   .shrR
         ANDI.L  #$7FFFFF,D3
         BRA     .pack

* Exponent ≤ 23: shift integer left, fill remaining bits from fraction
.shL     MOVEQ   #23,D0
         SUB.L   D1,D0           D0 = fraction bits to fill
         LSL.L   D0,D3           Align integer mantissa
         ANDI.L  #$7FFFFF,D3    Strip implicit leading 1
         SUBQ.L  #1,D0
         BMI.S   .round          No fraction bits, but check rounding

* Fill low mantissa bits by repeated doubling of fraction
.fbit    LSL.L   #1,D4           frac_num *= 2
         CMP.L   D5,D4
         BLT.S   .fb0
         SUB.L   D5,D4
         BSET    D0,D3           Set this mantissa bit
.fb0     SUBQ.L  #1,D0
         BPL.S   .fbit
         BRA.S   .round

* Fraction only (integer=0): find first 1-bit
.fonly   MOVEQ   #-1,D1
.fo1     LSL.L   #1,D4
         CMP.L   D5,D4
         BGE.S   .fo2
         SUBQ.L  #1,D1
         CMPI.L  #-127,D1
         BLE.S   .zero
         BRA.S   .fo1

.fo2     SUB.L   D5,D4           Remove implicit 1
         CLR.L   D3
         MOVEQ   #22,D0
.fo3     LSL.L   #1,D4
         CMP.L   D5,D4
         BLT.S   .fo4
         SUB.L   D5,D4
         BSET    D0,D3
.fo4     SUBQ.L  #1,D0
         BPL.S   .fo3
         BRA.S   .round

.zero    CLR.L   D0
         RTS

* Round to nearest: check next fraction bit
.round   LSL.L   #1,D4
         CMP.L   D5,D4
         BLT.S   .pack
         ADDQ.L  #1,D3
         BTST    #23,D3          Mantissa overflow?
         BEQ.S   .pack
         ANDI.L  #$7FFFFF,D3
         ADDQ.L  #1,D1           Bump exponent

* Pack IEEE 754: sign(1) | biased_exp(8) | mantissa(23)
.pack    ADD.L   #127,D1         Bias exponent
         MOVE.L  D1,D0
         ANDI.L  #$FF,D0
         LSL.L   #8,D0
         LSL.L   #8,D0
         LSL.L   #7,D0           Exponent → bits [30:23]
         OR.L    D3,D0           Add mantissa
         TST.L   D2
         BEQ.S   .done
         BSET    #31,D0          Set sign bit
.done    RTS

*------------------------------------------------------------------------
* MFBCC form handler  (INDEX 39) FBcc branch instructions
* D2 = OPC mask word: low byte = condition code (0-31)
*------------------------------------------------------------------------
MFBCC    DS      0
         BSR     EVSR            D5 = displacement
* Build opword: $F280 | condition (16-bit displacement)
         MOVE.W  D2,D0
         ANDI.W  #$3F,D0
         ORI.W   #$F280,D0
         MOVE.W  D0,D2
* Validate and store 16-bit displacement
         MOVE.L  D4,D5           Restore D5 from saved D4
         BSR     EA16BITS
         MOVE.W  D5,2(A1)
         ADDQ.B  #2,TNB(A1)
         BRA     CMMD2



*------------------------------------------------------------------------
* MFPFLIT — Handle FP literal for formats .S(1)/.X(2)/.D(5)
*
* Entry:  D5 = format code, FPUSCR+2(A1) = format saved, A5 → text
* Return: EQ = literal handled (D3/TNB/D6 set), NE = not handled
*------------------------------------------------------------------------
MFPFLIT  CMPI.W  #1,D5
         BEQ.S   .go
         CMPI.W  #5,D5
         BEQ.S   .go
         CMPI.W  #2,D5
         BEQ.S   .go
         MOVEQ   #1,D0           NE = not an FP-literal format
         RTS
.go      MOVE.W  #$80,TLENGTH(A1)
         BSR     CHKFPLIT
         BNE.S   .no
* Parse decimal → IEEE 754 single (base conversion)
         ADDQ.L  #1,A5           Skip '#'
         BSR     FPARSLIT        D0 = IEEE 754 single
         MOVEQ   #2,D3
* Format dispatch
         CMPI.W  #1,FPUSCR+2(A1)
         BEQ.S   .sgl
         CMPI.W  #5,FPUSCR+2(A1)
         BEQ.S   .dbl
* Extended (.X format 2): 12 bytes
         BSR     FSGL2EXT        D0/D1/D2 = extended
         MOVE.L  D0,(A4,D3)
         MOVE.L  D1,4(A4,D3)
         MOVE.L  D2,8(A4,D3)
         ADD.B   #12,TNB(A1)
         ADD.L   #12,D3
         BRA.S   .done
* Double (.D format 5): 8 bytes
.dbl     BSR     FSGL2DBL        D0/D1 = double
         MOVE.L  D0,(A4,D3)
         MOVE.L  D1,4(A4,D3)
         ADDQ.B  #8,TNB(A1)
         ADDQ.L  #8,D3
         BRA.S   .done
* Single (.S format 1): 4 bytes
.sgl     MOVE.L  D0,(A4,D3)
         ADDQ.B  #4,TNB(A1)
         ADDQ.L  #4,D3
.done    MOVE.B  #$3C,D6         Immediate mode
         MOVEQ   #0,D0           EQ = handled
         RTS
.no      MOVEQ   #1,D0           NE = not FP literal
         RTS

*------------------------------------------------------------------------
* FSGL2DBL — Convert IEEE 754 single → double
*
* Entry:  D0 = IEEE 754 single-precision
* Return: D0 = double high 32 bits, D1 = double low 32 bits
* Uses:   D2-D5
*------------------------------------------------------------------------
FSGL2DBL MOVE.L  D0,D2           Save single
         CLR.L   D1
* Zero check (ignore sign)
         MOVE.L  D2,D0
         ADD.L   D0,D0           Shift out sign
         BEQ.S   .dzero
* Sign → D4 bit 31
         MOVE.L  D2,D4
         ANDI.L  #$80000000,D4
* Exponent → D3
         MOVE.L  D2,D3
         SWAP    D3
         LSR.W   #7,D3
         ANDI.L  #$FF,D3         Single exponent (clears upper word)
         ADDI.W  #896,D3         Rebias: +(1023-127)
* Mantissa → D0 (23 bits)
         MOVE.L  D2,D0
         ANDI.L  #$007FFFFF,D0
* Double low: bottom 3 mantissa bits → bits 31-29
         MOVE.L  D0,D1
         ANDI.L  #7,D1
         ROR.L   #3,D1
* Double high mantissa: top 20 bits (bits 22-3)
         LSR.L   #3,D0
* Exponent → bits 30-20: shift left by 4, then swap
         MOVE.L  D3,D5
         LSL.L   #4,D5
         SWAP    D5              Total shift = 20
         CLR.W   D5
* Pack double high: sign | exponent | mantissa
         OR.L    D4,D0
         OR.L    D5,D0
         RTS
.dzero   MOVE.L  D2,D0
         ANDI.L  #$80000000,D0   Preserve ±0 sign
         CLR.L   D1
         RTS

*------------------------------------------------------------------------
* FSGL2EXT — Convert IEEE 754 single → MC68881 extended (96 bits)
*
* Entry:  D0 = IEEE 754 single-precision
* Return: D0 = bytes 0-3 (sign + 15-bit exp + 16 zero bits)
*         D1 = bytes 4-7 (mantissa high, J-bit explicit)
*         D2 = bytes 8-11 (mantissa low = 0)
* Uses:   D3-D5
*------------------------------------------------------------------------
FSGL2EXT MOVE.L  D0,D3           Save single
         CLR.L   D2              Mantissa low = 0
* Zero check (ignore sign)
         MOVE.L  D3,D1
         ADD.L   D1,D1
         BEQ.S   .xzero
* Sign → D4 bit 31
         MOVE.L  D3,D4
         ANDI.L  #$80000000,D4
* Exponent → D5
         MOVE.L  D3,D5
         SWAP    D5
         LSR.W   #7,D5
         ANDI.L  #$FF,D5         Single exponent (clears upper word)
         ADDI.W  #16256,D5       Rebias: +(16383-127)
* Mantissa → D1 with explicit J-bit
         MOVE.L  D3,D1
         ANDI.L  #$007FFFFF,D1   23-bit mantissa
         LSL.L   #8,D1           Shift to bits 30-8
         ORI.L   #$80000000,D1   Set J-bit (explicit integer bit)
* Build D0: sign(1) | exponent(15) | zeros(16)
         SWAP    D5              Exponent → high word
         CLR.W   D5              Clear low word
         MOVE.L  D4,D0           Sign
         OR.L    D5,D0           Exponent
         RTS
.xzero   MOVE.L  D3,D0
         ANDI.L  #$80000000,D0   Preserve ±0 sign
         CLR.L   D1
         CLR.L   D2
         RTS

*-------------------------------------------------------------------------
* File DCODE68K  68K ONE LINE DISASSEMBLER                        07/28/82

*        CALLING SEQUENCE:
*   D0,D1,D2 = CODE TO BE DISASSEMBLED
*   A4 = VALUE OF PROGRAM COUNTER FOR THE CODE
*   A5 = POINTER TO STORE DATA (BUFSIZE = 80 ASSUMED)
*        JSR       DCODE68K

*        RETURN:
*   A4 = VALUE OF PROGRAM COUNTER FOR NEXT INSTRUCTION
*   A5 = POINTER TO LINE AS DISASSEMBLED
*   A6 = POINTER TO END OF LINE
*
* 01234567890123456789012345678901234567890123456789
* AAAAAA FDATA.DDDDDDDDDDDDDD FOC.... FOP.....

*FDATA   EQU     10             DATA FIELD
*FOC     EQU     31             OP-CODE FIELD
*FOP     EQU     39             OPERAND FIELD

* CAUSES ORGIN MODULO 4
LONG     MACRO
         DS      0
         DS.B    (*-X)&2
         ENDM


X        DS      0              BASE ADDRESS THIS MODULE
         LONG

*  MOVEM REGISTERS TO EA
*
*        01001D001S......
*        ..........XXXXXX       EFFECTIVE ADDRESS
*        .........0......       WORD
*        .........1......       LONG
*        .....0..........       REGISTER TO MEMORY
*        .....1..........       MEMORY TO REGISTER
*

IMOVEMFR DS      0
         BSR     MOVEMS         SIZE

         MOVEQ   #$0038,D6
         AND.W   (A4),D6
         CMPI.W  #$0020,D6
         BEQ.S   IM7788         PREDECREMENT MODE

         MOVEQ   #1,D6          D6 = INCREMENTER (BIT POSITION)
         MOVEQ   #0,D1          D1 = BIT POSITION
         BRA.S   IM7799

IM7788   MOVEQ   #-1,D6         D6 = DECREMENTER (BIT POSITION)
         MOVEQ   #15,D1         D1 = BIT POSITION
IM7799   BSR     MOVEMR         BUILD MASK WORD

         MOVE.B  #',',(A6)+     STORE COMMA

         ADDQ.L  #2,D3
         MOVE.W  (A4),D4
         MOVE.W  #$1F4,D7       CONTROL + PREDECREMENT
         BSR     EEA
         BRA.S   CS16           COMMON

         LONG
* MOVEM  EA  TO REGISTERS
*
IMOVEMTR BSR     MOVEMS         SIZE
         ADDQ.L  #2,D3
         MOVE.W  #$7EC,D7       CONTROL + POSTINCREMENT
         BSR     EEA

         MOVE.B  #',',(A6)+     STORE COMMA

         MOVEQ   #1,D6          D6 = BIT POSITION INCREMENTER
         MOVEQ   #0,D1          D1 = BIT POSITION
         BSR     MOVEMR

CS16     BRA.S   CS15           COMMON


         LONG
ISTOP    DS      0
         MOVE.W  2(A4),D0
         MOVE.B  #'#',(A6)+     IMMEDIATE
         MOVE.B  #'$',(A6)+     HEX
         BSR     PNT4HX         VALUE
         BRA     COMMON4

         LONG
IMMED    DS      0              ADD  AND  CMP #  EOR  OR  SUB
         BSR     FORMSIZE
         ADDQ.L  #2,D3          SIZE = 4
         MOVE.B  #'#',(A6)+     IMMEDIATE

         CLR.L   D0
         MOVE.W  2(A4),D0       D0 = EXTENSION WORD
         MOVE.W  (A4),D1
         LSR.W   #6,D1
         ANDI.W  #3,D1
         BEQ.S   IMMED65        .BYTE

         CMPI.B  #1,D1
         BEQ.S   IMMED75        .WORD

         ADDQ.L  #2,D3          .LONG    SIZE = 6
         MOVE.L  2(A4),D0       D0 = LONG EXTENSION WORD

IMMED45  BSR     HEX2DEC        DECIMAL

         MOVE.B  D5,(A6)+       COMMA SEPARATOR

         MOVE    (A4),D0
         ANDI.W  #$003F,D0
         CMPI.W  #$003C,D0      DESTINATION ADDRESS MODE 111100  "SR"
         BNE.S   IMMED55        NOT FOUND

         MOVE.W  (A4),D0        "SR"  ILLEGAL FOR
         ANDI.W  #$4000,D0      ADDI   SUBI  CMPI
         BNE     FERROR         0600   0400  0C00

         MOVE.W  (A4),D1
         ANDI.W  #$00C0,D1
         CMPI.W  #$0080,D1
         BEQ     FERROR         .LONG NOT ALLOWED

         MOVE.B  #'S',(A6)+     #,SR FOR ANDI,EORI,ORI
         MOVE.B  #'R',(A6)+
CS15     BRA.S   CS14           COMMON

IMMED55  BSR     EEA
         BRA.S   CS14           COMMON

IMMED65  MOVE.L  D0,D1          D1 = XXXXXXXX........
         LSR.W   #8,D1          D1 = 00000000XXXXXXXX
         BEQ.S   IMMED75
         MOVE.L  D0,D1
         ASR.W   #7,D1
         ADDQ.W  #1,D1          CHECK FOR NEGATIVE
         BNE     FERROR

IMMED75  EXT.L   D0
         BRA     IMMED45

*  BIT   5432109876543210
*        ....RRRMMM......       DESTINATION REGISTER MODE
*        ..........MMMRRR       SOURCE MODE REGISTER
*        0001............       .BYTE
*        0011............       .WORD
*        0010............       .LONG
*
* IF BYTE SIZE* DESTINATION ADDRESS DIRECT NOT ALLOWED
         LONG
IMOVE    DS      0
         BRA     IMOVEA1

         LONG
ILINK    DS      0
         BSR.S   FORMREGA

         MOVE.B  D5,(A6)+       COMMA SERARATOR

         MOVE.B  #'#',(A6)+
         MOVE.W  2(A4),D0
         EXT.L   D0
         BSR     HEX2DEC        DECIMAL DISPLACEMENT
         BRA     COMMON4

         LONG
FORM1    DS      0              CLR  NEG  NEGX  NOT TST
         BSR     FORMSIZE


*                               NBCD TAS
FORM1A   BSR     EEA            DATA ALTERABLE ONLY
CS14     BRA.S   CS13           COMMON

         LONG
FORM3    DS      0              EXT  SWAP
         BSR.S   FORMREGD
         BRA.S   CS13           COMMON

         LONG
FORM4    DS      0              TRAP
         MOVE.B  #'#',(A6)+
         MOVE.W  (A4),D0
         ANDI.L  #$0F,D0
         BSR     HEX2DEC        DECIMAL
         BRA.S   CS13           COMMON

         LONG
FORM5    DS      0              UNLNK
         BSR.S   FORMREGA
         BRA.S   CS13           COMMON

*  BIT   5432109876543210
*        ....RRR.........       ADDRESS REGISTER
*        ..........XXXXXX       EFFECTIVE ADDRESS
*
         LONG
FORM6A   DS      0              LEA
         MOVE.W  #$7E4,D7       CONTROL ADDRESSING
         BSR.S   EEA10

         MOVE.B  D5,(A6)+       COMMA SEPARATOR

         MOVE.W  (A4),D4
         ROL.W   #7,D4
         BSR.S   FORMREGA
         BRA.S   CS13           COMMON

*  BIT   5432109876543210
*        ....DDD.........       DATA REGISTER
*        ..........XXXXXX       EFFECTIVE ADDRESS
*
         LONG
FORM6D   DS      0              CHK  DIVS  DIVU  MULS  MULU
         MOVE.W  #$FFD,D7       DATA ADDRESSING
         BSR.S   EEA10

         MOVE.B  D5,(A6)+       COMMA SEPARATOR

         MOVE.W  (A4),D4
         ROL.W   #7,D4
         BSR.S   FORMREGD
         BRA.S   CS13           COMMON

FORMREGA MOVE.B  #'A',(A6)+     FORMAT A@
FORMREG5 ANDI.B  #$07,D4
         ORI.B   #'0',D4
         MOVE.B  D4,(A6)+
         RTS

FORMREGD MOVE.B  #'D',(A6)+     FORMAT D@
         BRA     FORMREG5

*  BIT   5432109876543210
*        ....DDD......DDD       DATA REGISTERS
*
         LONG
FORM7    DS      0              EXG
         ROL.W   #7,D4
         BSR     FORMREGD

         MOVE.B  D5,(A6)+       COMMA SEPARATOR

         MOVE.W  (A4),D4
         BSR     FORMREGD
         BRA.S   CS13           COMMON

*  BIT   5432109876543210
*        ....AAA......AAA       ADDRESS REGISTERS
*
         LONG
FORM8    DS      0              EXG
         ROL.W   #7,D4
         BSR     FORMREGA

FORM815  MOVE.B  #',',(A6)+     COMMA SEPARATOR

         MOVE.W  (A4),D4
         BSR     FORMREGA
CS13     BRA     CS12           COMMON

*  BIT   5432109876543210
*        ....DDD.........       DATA REGISTER
*        .............AAA       ADDRESS REGISTER
*
         LONG
FORM9    DS      0              EXG
         ROL.W   #7,D4
         BSR     FORMREGD       DATA REGISTER
         BRA     FORM815

EEA10    BRA     EEA

*  BIT   5432109876543210
*        ..........AAAAAA         EFFECTIVE ADDRESS
*        .......MMM......         OP-MODE
*        ....RRR.........         D-REGISTER
*        .......011......         WORD  EA,A@
*        .......111......         LONG  EA,A@
*        .......000......         EA,D@ BYTE (ADDRESS REGISTER DIRECT NOT ALLOWED)
*        .......0........         EA,D@
*        .......1........         D@,EA
*        ........00......         BYTE
*        ........01......         WORD
*        ........10......         LONG
*
         LONG
*                               ADD <EA>,A@   CMP <EA>,A@   SUB <EA>,A@
FORM10EX DS      0              ADD  CMP  SUB
         MOVE.W  #$FFF,D7       ALL MODES ALLOWED
         MOVE.L  D4,D0
         ANDI.W  #$01C0,D0
         BEQ.S   FORM103        .......000......
         CMPI.W  #$01C0,D0
         BEQ.S   FORM10E3       .......111......
         CMPI.W  #$00C0,D0
         BNE.S   FORM10E6

         MOVE.B  #'.',(A5)+     .......011......       STORE PERIOD
         MOVE.B  #'W',(A5)+
         BRA.S   FORM10E4

FORM10E3 MOVE.B  #'.',(A5)+
         MOVE.B  #'L',(A5)+

FORM10E4 BSR     EEA10

         MOVE.B  D5,(A6)+       STORE COMMA SEPARATOR

         MOVE.W  (A4),D4
         ROL.W   #7,D4
         BSR     FORMREGA       <EA>,A@
         BRA.S   CS12           COMMON

FORM10E6 BTST.B  #0,(A4)
         BNE.S   FORM105        .......1........    D@,<EA>
         BRA.S   FORM104        .......0........    <EA>,D@

*  BIT   5432109876543210
*        ..........AAAAAA       EFFECTIVE ADDRESS
*        .......MMM......       OP-MODE
*        ....RRR.........       D-REGISTER
*        .......0........       EA,D@
*        .......1........       D@,EA
*        ........00......       BYTE
*        ........01......       WORD
*        ........10......       LONG
         LONG
FORM10   DS      0              AND  EOR  OR
         BTST.B  #0,(A4)
         BNE.S   FORM105

FORM103  MOVE.W  #$FFD,D7       DATA ADDRESSING
FORM104  BSR     FORMSIZE
         BSR     EEA10          <EA>,D@

         MOVE.B  D5,(A6)+       COMMA SEPARATOR

         MOVE.B  (A4),D4
         LSR.B   #1,D4
         BSR     FORMREGD
         BRA.S   CS12           COMMON

FORM105  BSR     FORMSIZE       D@,<EA>
         MOVE.B  (A4),D4
         LSR.B   #1,D4
         BSR     FORMREGD

         MOVE.B  D5,(A6)+       COMMA SEPARATOR

         MOVE.W  (A4),D4
         MOVE.W  #$1FD,D7       ALTERABLE MEMORY ADDRESSING
         BSR     EEA10
CS12     BRA     COMMON

         LONG
*                               PEA     (JMP  JSR)
FORM11   MOVE.W  #$7E4,D7       CONTROL ADDERSSING
         BSR     EEA10
         BRA     CS12           COMMON

         LONG
*                               JMP  JSR
FORM11SL MOVE.L  D4,D0          LOOK FOR .S  OR  .L
         ANDI.W  #$3F,D0
         CMPI.W  #$38,D0
         BNE.S   FORM112        NOT .S
         MOVE.B  #'.',(A5)+     PERIOD
         MOVE.B  #'S',(A5)+     S
FORM112  CMPI.W  #$39,D0
         BNE.S   FORM114
         MOVE.B  #'.',(A5)+     PERIOD
         MOVE.B  #'L',(A5)+     L
FORM114  BRA     FORM11

*  BIT   5432109876543210
*        ....XXX.....0...       DATA DESTINATION REGISTER
*        ....XXX.....1...       ADDRESS REGISTER
*        ....XXX.00......       BYTE
*        ........01......       WORD
*        ........10......       LONG
*        ............0...       DATA REGISTER TO DATA REGISTER
*        ............1...       MEMORY TO MEMORY
*        ............0XXX       DATA SOURCE REGISTER
*        ............1XXX       ADDRESS SOURCE REGISTER
*
         LONG
FORM12   DS      0              ABCD  ADDX  SBCD  SUBX
         BSR     FORMSIZE

         BTST    #3,D4
         BNE.S   FORM125

         BSR     FORMREGD       D@,D@*   FORMAT SOURCE

         MOVE.B  D5,(A6)+       COMMA SEPARATOR

         MOVE.B  (A4),D4
         LSR.B   #1,D4
         BSR     FORMREGD       FORMAT DESTINATION
         BRA.S   CS11           COMMON

FORM125  MOVE.B  #'-',(A6)+     -
         MOVE.B  #'(',(A6)+     (
         BSR     FORMREGA       A@    SOURCE

         MOVE.L  #'(-,)',D0     ),-(
         BSR.S   SCHR           STORE CHARS

         MOVE.B  (A4),D4
         LSR.B   #1,D4
         BSR     FORMREGA       A@   DESTINATION
         MOVE.B  #')',(A6)+
         BRA.S   CS11           COMMON

*  BIT   5432109876543210
*        ....XXX.....1...       ADDRESS REGISTER    DESTINATION
*        ....XXX.00......       BYTE
*        ........01......       WORD
*        ........10......       LONG
*        ............1...       MEMORY TO MEMORY
*        ............1XXX       ADDRESS SOURCE REGISTER
*
         LONG
FORM12A  DS      0              CMPM
         BSR     FORMSIZE

         MOVE.B  #'(',(A6)+     (
         BSR     FORMREGA       A@

         MOVE.L  #'(,+)',D0     )+,(
         BSR.S   SCHR           STORE CHARS

         MOVE.B  (A4),D4
         LSR.B   #1,D4
         BSR     FORMREGA       A@
         MOVE.B  #')',(A6)+
         MOVE.B  #'+',(A6)+
CS11     BRA     COMMON

         LONG
IQUICK   BRA     IQUICKA        ADDQ  SUBQ

*  BIT   5432109876543210
*        0111...0........       FIXED
*        ....RRR.........       DATA REGISTER
*        ........DDDDDDDD       SIGN EXTENDED DATA
*
         LONG
IMOVEQ   DS      0
         MOVE.B  #'#',(A6)+     IMMEDIATE

         MOVE.W  (A4),D0
         EXT.W   D0
         EXT.L   D0
         BSR     HEX2DEC        DECIMAL

         MOVE.B  D5,(A6)+       COMMA SEPARATOR

         ROL.W   #7,D4
         BSR     FORMREGD
         BRA     CS11           COMMON

SCHR     MOVE.B  D0,(A6)+       OUTPUT STRING
         LSR.L   #8,D0
         BNE     SCHR           MORE TO OUTPUT
         RTS

* MOVE FROM SR  (STATUS REGISTER)
*
         LONG
IMVFSR   MOVE.L  #',RS'+0,D0   SR,

         BSR     SCHR
         BSR     EEA            DATA ALTERABLE
         BRA     CS11           COMMON

* MOVE FROM USP (USER STACK POINTER)
*
         LONG
IMVFUSP  MOVE.L  #',PSU',D0     USP,
         BSR     SCHR
         BSR     FORMREGA
         BRA     CS11           COMMON

* MOVE TO SR (STATUS REGISTER)
*
         LONG
IMVTSR   MOVE.W  #$FFD,D7       DATA ADDRESSING
         BSR     EEA
         MOVE.L  #'RS,'+0,D0   ,SR
IMVT44   BSR     SCHR
         BRA     CS11           COMMON

* MOVE TO USP (USER STACK POINTER)
*
         LONG
IMVTUSP  BSR     FORMREGA
         MOVE.L  #'PSU,',D0     ,USP
         BRA     IMVT44

*  MOVE TO CCR (CONDITION CODE REGISTER)
*
         LONG
IMVTCCR  MOVE.W  #$FFD,D7       DATA ADDRESSING
         BSR     EEA
         MOVE.L  #'RCC,',D0     ,CCR
         BRA     IMVT44

*  BIT   5432109876543210
*        0000...1..001...       FIXED
*        ....XXX.........       DATA REGISTER
*        ........0.......       MEMORY TO REGISTER
*        ........1.......       REGISTER TO MEMORY
*        .........0......       WORD
*        .........1......       LONG
*        .............XXX       ADDRESS REGISTER
*
         LONG
IMOVEP   DS      0
         MOVE.B  #'.',(A5)+     D@,#(A@)
         MOVE.W  #'LW',D0
         BTST    #6,D4
         BEQ.S   IMOVEP11       USE "W"
         LSR.W   #8,D0          USE "L"
IMOVEP11 MOVE.B  D0,(A5)+       LENGTH

         MOVE.B  (A4),D4
         LSR.B   #1,D4

         BTST.B  #7,1(A4)
         BEQ.S   IMOVEP35

         BSR     FORMREGD       D@,$HHHH(A@)

         MOVE.B  D5,(A6)+       COMMA SEPARATOR

         MOVE.W  (A4),D4
         BSR.S   IMOVEP66
CS20     BRA     COMMON4

IMOVEP35 BSR.S   IMOVEP66       $HHHH(A@),D@

         MOVE.B  D5,(A6)+       COMMA SEPARATOR

         MOVE.B  (A4),D4
         LSR.B   #1,D4
         BSR     FORMREGD
         BRA     CS20           COMMON4

IMOVEP66 MOVE.B  #'$',(A6)+     FORMAT DISPLACEMENT
         MOVE.W  2(A4),D0
         BSR     PNT4HX

         MOVE.B  #'(',(A6)+

         MOVE.W  (A4),D4
         BSR     FORMREGA
         MOVE.B  #')',(A6)+
         RTS

         LONG
SCOMMON  BRA     COMMON         NOP RESET RTE RTR RTS TRAPV

         LONG
ISCC     BSR     ICCCC          GET REST OF OP-CODE
         BSR     EEA            DATA ALTERABLE
         BRA     SCOMMON


         LONG
IDBCC    DS      0              DB--
         MOVE.W  (A4),D4
         BSR     FORMREGD

         MOVE.B  D5,(A6)+       COMMA SEPARATOR
         MOVE.B  #'$',(A6)+     HEX FIELD TO FOLLOW

         BSR     ICCCC
         BRA.S   ICC55

*  BIT   5432109876543210
*        0110............       FIXED
*        ....CCCC........       CONDITION
*        ........DDDDDDD0       DISPLACEMENT
*        ...............1       ERROR (ODD BOUNDRY DISPLACEMENT)
*
         LONG
ICC      DS      0              B--
         BSR     ICCCC

IBSR     MOVE.B  #'$',(A6)+     BSR   BRA

         TST.B   D4
         BEQ.S   ICC55          16 BIT DISPLACEMENT

         MOVE.B  #'.',(A5)+
         MOVE.B  #'S',(A5)+
         EXT.W   D4             8 BIT DISPLACEMENT

ICC35    EXT.L   D4             SIGN-EXTENDED DISPLACEMENT
         ADD.L   HISPC(A1),D4   + PROGRAM COUNTER
         ADDQ.L  #2,D4          + TWO
         MOVE.L  D4,D0

         ASR.L   #1,D4
         BCS     FERROR         ODD BOUNDRY DISPLACEMENT

         BSR     PNT6HX
         BRA     SCOMMON

ICC55    ADDQ.L  #2,D3          SIZE
         MOVE.W  2(A4),D4
         MOVE.B  #'.',(A5)+
         MOVE.B  #'L',(A5)+     .L FOR 16 BIT DISPLACEMENT
         BRA     ICC35

         LONG
*                               BCHG  BCLR  BSET  BTST
ISETD    DS      0              DYNAMIC BIT
         ROL.W   #7,D4
         BSR     FORMREGD       DATA REGISTER

ISETD12  MOVE.B  D5,(A6)+       COMMA SEPARATOR

         MOVE.W  (A4),D4
         BSR     EEA            DATA ALTERABLE
CS18     BRA     SCOMMON

         LONG
*                            BCHG  BCLR  BSET  BTST
*  1ST WORD     .... .... ..XX XXXX    EA   DATA ALTERABLE ONLY
*  2ND WORD     0000 0000 000Y YYYY    BIT NUMBER
*
ISETS    DS      0              STATIC BIT
         ADDQ.L  #2,D3     SIZE
         MOVE.B  #'#',(A6)+     IMMEDIATE

         CLR.L   D0
         MOVE.W  2(A4),D0       GET BIT POSITION FROM 2ND WORD
         MOVE.L  D0,D1
         LSR.L   #5,D1
         BNE     FERROR
         BSR     HEX2DEC        DECIMAL

         BRA     ISETD12

*   BIT  5432109876543210
*        ....XXX.........       IMMEDIATE COUNT/REGISTER
*        .......0........       RIGHT SHIFT
*        .......1........       LEFT SHIFT
*        ........00......       BYTE
*        ........01......       WORD
*        ........10......       LONG
*        ....0...11......       WORD (MEMORY)
*        ....0...11AAAAAA       EFFECTIVE ADDRESS
*        ..........0.....       SHIFT IMMEDIATE COUNT
*        ..........1.....       SHIFT COUNT (MODULO 64) IN DATA REGISTER
*
         LONG
ISHIFT   DS      0              AS-  LS-  RO-  ROX-
         MOVE.W  #'LR',D0
         BTST    #8,D4          DIRECTION BIT
         BEQ.S   ISHIFT13       RIGHT
         LSR.W   #8,D0          LEFT
ISHIFT13 MOVE.B  D0,(A5)+       DIRECTION* "L" OR "R"

         MOVE.W  (A4),D0
         ANDI.W  #$00C0,D0
         CMPI.W  #$00C0,D0
         BEQ.S   ISHIFTM1       MEMORY SHIFT

         BSR     FORMSIZE

         ROL.W   #7,D4
         BTST    #12,D4         I/R BIT
         BNE.S   ISHIFT33       COUNT IN REGISTER

         ANDI.B  #$07,D4        IMMEDIATE COUNT
         BNE.S   ISHIFT23
         ORI.B   #$08,D4        CHANGE ZERO TO EIGHT
ISHIFT23 ORI.B   #'0',D4
         MOVE.B  #'#',(A6)+
         MOVE.B  D4,(A6)+
         BRA.S   ISHIFT44

ISHIFT33 BSR     FORMREGD

ISHIFT44 MOVE.B  D5,(A6)+       COMMA SEPARATOR

         MOVE.W  (A4),D4
         BSR     FORMREGD
CS17     BRA     CS18           COMMON

ISHIFTM1 MOVE.B  #'.',(A5)+     PERIOD
         MOVE.B  #'W',(A5)+     .WORD

         BTST    #11,D4
         BNE     FERROR         BIT 11 MUST BE ZERO

         MOVE.W  #$1FC,D7       MEMORY ALTERABLE ADDRESSING
         BSR     EEA
         BRA     CS17           COMMON

ICCCC    MOVEQ   #$0F,D0        APPEND CONDITION CODE
         AND.B   (A4),D0        D0 = CCC
         LSL.L   #1,D0          D0 = CCC*2

         MOVE.W  BRTBL(PC,D0.W),D1  GET BRANCH MNEMONIC
         MOVE.B  D1,(A5)+           (REVERSED) FROM THE TABLE
         LSR.W   #8,D1              AND ADD THE NONBLANK PORTION
         CMPI.B  #BLANK,D1          TO THE BUFFER.
         BEQ.S   ICCCC9
         MOVE.B  D1,(A5)+
ICCCC9   RTS

BRTBL    DC.B    ' T'      'T '  *BRA ACCEPTED
         DC.B    ' F'      'F '
         DC.B    'IH'      'HI'
         DC.B    'SL'      'LS'
         DC.B    'CC'      'CC'
         DC.B    'SC'      'CS'
         DC.B    'EN'      'NE'
         DC.B    'QE'      'EQ'
         DC.B    'CV'      'VC'
         DC.B    'SV'      'VS'
         DC.B    'LP'      'PL'
         DC.B    'IM'      'MI'
         DC.B    'EG'      'GE'
         DC.B    'TL'      'LT'
         DC.B    'TG'      'GT'
         DC.B    'EL'      'LE'

*   BIT  5432109876543210
*        ....RRRMMM......    DESTINATION REGISTER MODE
*        ..........MMMRRR    SOURCE MODE REGISTER
*
* IF BYTE SIZE* ADDRESS DIRECT NOT ALLOWED AS SOURCE
*
IMOVEA1  DS      0
         MOVE.W  #$FFF,D7       ALL MODES
         BSR     EEA

         MOVE.B  D5,(A6)+       COMMA SEPARATOR

         MOVE.W  (A4),D4        ....RRRMMM......
         LSR.W   #1,D4          .....RRRMMM.....
         LSR.B   #5,D4          .....RRR.....MMM
         ROR.W   #8,D4          .....MMM.....RRR
         LSL.B   #5,D4          .....MMMRRR.....
         LSR.W   #5,D4          ..........MMMRRR

* IF .BYTE DESTINATION A@ NOT ALLOWED
         MOVE.W  #$1FF,D7       DATA ALTERABLE + A@
         MOVE.B  (A4),D0
         CMPI.B  #$01,D0
         BNE.S   IMOVE19        NOT BYTE SIZE

         MOVE.W  #$1FD,D7       DATA ALTERABLE
IMOVE19

         BSR     EEA
         BRA.S   CS19           COMMON

*  IF BYTE* ADDRESS REGISTER DIRECT NOT ALLOWED
IQUICKA  DS      0              ADDQ  SUBQ
         BSR.S   FORMSIZE

         MOVE.B  #'#',(A6)+
         ROL.W   #7,D4
         ANDI.B  #7,D4
         BNE.S   IQUICK21
         ORI.B   #8,D4          MAKE ZERO INTO EIGHT
IQUICK21 ORI.B   #'0',D4        MAKE ASCII
         MOVE.B  D4,(A6)+

         MOVE.B  D5,(A6)+       COMMA SEPARATOR

         MOVE.W  (A4),D4

         MOVE.W  (A4),D0
         ANDI.W  #$00C0,D0
         BEQ.S   IQUICK31       DATA ALTERABLE
         MOVE.W  #$1FF,D7       ALTERABLE ADDRESSING
IQUICK31 BSR     EEA
CS19     BRA     COMMON

*  BIT   5432109876543210
*        ........00......       BYTE
*        ........01......       WORD
*        ........10......       LONG
*        ........11......       ERROR
*
FORMSIZE DS      0
         MOVE.W  (A4),D2
         MOVE.B  #'.',(A5)+     STORE PERIOD
         LSR.W   #6,D2
         ANDI.W  #$03,D2
         BNE.S   FORM91
         MOVE.B  #'B',(A5)+     STORE "B"
         BRA.S   FORM95

FORM91   MOVE.B  #'W',D0
         CMPI.B  #1,D2
         BEQ.S   FORM93
         MOVE.B  #'L',D0
         CMPI.B  #2,D2
         BNE.S   FE10           FERROR
FORM93   MOVE.B  D0,(A5)+       STORE "W" OR "L"
FORM95   RTS

EA000    BSR     FORMREGD
         BTST    #0,D7
         BEQ.S   FE10           FERROR
         RTS

EA001    BSR     FORMREGA
         BTST    #1,D7
         BEQ.S   FE10           FERROR  THIS MODE NOT ALLOWED
         RTS

EA010    MOVE.B  #'(',(A6)+
         BSR     FORMREGA
         MOVE.B  #')',(A6)+
         BTST    #2,D7
         BEQ.S   FE10           FERROR  THIS MODE NOT ALLOWED
         RTS

EA011    MOVE.B  #'(',(A6)+
         BSR     FORMREGA
         MOVE.B  #')',(A6)+
         MOVE.B  #'+',(A6)+
         BTST    #3,D7
         BEQ.S   FE10           FERROR  THIS MODE NOT ALLOWED
EA011RTS RTS

EA100    MOVE.B  #'-',(A6)+
         MOVE.B  #'(',(A6)+
         BSR     FORMREGA
         MOVE.B  #')',(A6)+
         BTST    #4,D7
         BNE     EA011RTS
FE10     BRA     FERROR         THIS MODE NOT ALLOWED

*  ENTER       A4 = POINTER TO FIRST WORD
*              D3 = OFFSET TO EXTENSION
*              D4 = VALUE TO PROCESS
*              D7 = MODES ALLOWED MASK
*
EEA      DS      0
         MOVE.L  D4,D0
         LSR.W   #3,D0
         ANDI.W  #$7,D0
         BEQ     EA000

         CMPI.B  #1,D0
         BEQ     EA001

         CMPI.B  #2,D0
         BEQ     EA010

         CMPI.B  #3,D0
         BEQ     EA011

         CMPI.B  #4,D0
         BEQ     EA100

         CMPI.B  #5,D0
         BEQ.S   EA101

         CMPI.B  #7,D0
         BEQ.S   EA111

*    EXTENSION WORD
*   BIT  5432109876543210
*        0...............    DATA REGISTER
*        1...............    ADDRESS REGISTER
*        .RRR............    REGISTER
*        ....0...........    SIGN EXTENDED,LOW ORDER INTEGER IN INDEX REG
*        ....1...........    LONG VALUE IN INDEX REGISTER
*        .....000........
*        ........DDDDDDDD    DISPLACEMENT INTEGER
*
* EA110            ADDRESS REGISTER INDIRECT WITH INDEX

         BTST    #6,D7
         BEQ     FE10           FERROR  THIS MODE NOT ALLOWED

         MOVE.W  (A4,D3),D1
         ANDI.W  #$0700,D1
         BNE     FE10           FERROR  BITS 10-8 MUST BE ZERO

         MOVE.W  (A4,D3),D0     D0 = DISPLACEMENT
         EXT.W   D0
         EXT.L   D0
         BSR     HEX2DEC        DECIMAL
         MOVE.B  #'(',(A6)+     (

         BSR     FORMREGA       XX(A@

         MOVE.B  #',',(A6)+     XX(A@,

         MOVE.B  (A4,D3),D4
         ASR.B   #4,D4
         BPL.S   EA1105
         BSR     FORMREGA
         BRA.S   EA1107

EA1105   BSR     FORMREGD
EA1107   MOVE.B  #'.',(A6)+     XX(A@,X@.

         MOVE.W  (A4,D3),D4     D4 = R@
         MOVE.B  #'W',D0        ..........W
         BTST    #11,D4
         BEQ.S   EA1109
         MOVE.B  #'L',D0        ..........L
EA1109   MOVE.B  D0,(A6)+
         MOVE.B  #')',(A6)+     ...........)
         ADDQ.L  #2,D3
         RTS

* ADDRESS REGISTER INDIRECT WITH DISPLACEMENT
*
EA101    BTST    #5,D7          101000*   DIS(A@)
         BEQ.S   FE11           FERROR*  THIS MODE NOT ALLOWED

         MOVE.W  (A4,D3),D0
         EXT.L   D0
         BSR     HEX2DEC        DECIMAL
         ADDQ.L  #2,D3          SIZE
         BRA     EA010

*  111000        ABSOLUTE SHORT
*  111001        ABSOLUTE LONG
*  111010        PROGRAM COUNTER WITH DISPLACEMENT
*  111011        PROGRAM COUNTER WITH INDEX
*  111100        IMMEDIATE OR STATUS REG
*
EA111
         ANDI.W  #7,D4
         BNE.S   EA1112

         BTST    #7,D7
         BEQ.S   FE11           FERROR*  THIS MODE NOT ALLOWED

         MOVE.W  (A4,D3),D0     111000*   ABSOLUTE SHORT
         EXT.L   D0
         MOVE.B  #'$',(A6)+
         BSR     PNT8HX         SIGN EXTENDED VALUE
         ADDQ.L  #2,D3          SIZE + 2
         RTS

EA1112   CMPI.B  #1,D4
         BNE.S   EA1113

         BTST    #8,D7
         BEQ.S   FE11           FERROR*  THIS MODE NOT ALLOWED

         MOVE.B  #'$',(A6)+     HEX
         MOVE.L  (A4,D3),D0     111001*     ABSOLUTE LONG
         BSR     PNT8HX
*-       MOVE.B  #'.',(A6)+     FORCE LONG FORMAT
*-       MOVE.B  #'L',(A6)+     IE   .L
         ADDQ.L  #4,D3
         RTS

EA1113   CMPI.B  #2,D4
         BNE.S   EA1114

         BTST    #9,D7
         BNE.S   EA1113A
FE11     BRA     FERROR         THIS MODE NOT ALLOWED
EA1113A

         MOVE.W  (A4,D3),D0     111010*  PC + DISPLACEMENT  DESTINATION(PC)
         EXT.L   D0
         ADD.L   HISPC(A1),D0
         ADDQ.L  #2,D0
         MOVE.B  #'$',(A6)+     HEX "$"
         BSR     PNT8HX         DESTINATION
         MOVE.L  #')CP(',D0     (PC)
         BSR     SCHR           STORE WORD
         ADDQ.L  #2,D3          SIZE
         RTS

EA1114   CMPI.B  #3,D4
         BNE.S   EA1115

* PROGRAM COUNTER WITH INDEX    DESTINATION(PC,R@.X)
*
*        5432109876543210       SECOND WORD
*        0...............       DATA REGISTER
*        1...............       ADDRESS REGISTER
*        .XXX............       REGISTER
*        ....0...........       SIGN-EXTENDED,LOW ORDER WORD INTEGER
*                               ..IN INDEX REGISTER
*        ....1...........       LONG VALUE IN INDEX REGISTER
*        .....000........
*        ........XXXXXXXX       DISPLACEMENT INTEGER
*
         BTST    #10,D7
         BEQ     FE11           FERROR  THIS MODE NOT ASLLOWED

         MOVE.W  (A4,D3),D1
         ANDI.W  #$0700,D1
         BNE     FE11           FERROR*  BITS 10-8 MUST BE ZERO

         MOVE.B  1(A4,D3),D0    111100*   DESTINATION(PC,R@.X)
         EXT.W   D0
         EXT.L   D0
         ADD.L   HISPC(A1),D0
         ADDQ.L  #2,D0
         MOVE.B  #'$',(A6)+     HEX "$"
         BSR     PNT8HX         DESTINATION

         MOVE.L  #',CP(',D0
         BSR     SCHR           DES(PC,

         MOVE.W  (A4,D3),D4
         ROL.W   #4,D4
         BTST    #3,D4
         BEQ.S   EAF25
         BSR     FORMREGA
         BRA.S   EAF27
EAF25    BSR     FORMREGD       DES(PC,R@
EAF27

         MOVE.B  #'.',(A6)+     DES(PC,R@.

         MOVE.W  (A4,D3),D4
         MOVE.W  #'LW',D0
         BTST    #11,D4
         BEQ.S   EAF35
         LSR.W   #8,D0
EAF35    MOVE.B  D0,(A6)+       DES(PC,R@.X

         MOVE.B  #')',(A6)+     DES(PC,R@.X)
         ADDQ.L  #2,D3
         RTS

*   BIT  5432109876543210
*        ..........111100       FIRST WORD*  #<IMMEDIATE>
*
EA1115   CMPI.B  #4,D4
         BNE     FE11           FERROR

         BTST    #11,D7
         BEQ     FE11           FERROR*  THIS MODE NOT ALLOWED

         MOVE.B  #'#',(A6)+     IMMEDIATE

         MOVE.B  -1(A5),D1
         CMPI.B  #'L',D1
         BEQ.S   EA11155        LONG
         CMPI.B  #'S',D1
         BEQ.S   EA11155S       FPU single (4 bytes, hex)
         CMPI.B  #'D',D1
         BEQ     EA11158        FPU double (8 bytes)
         CMPI.B  #'X',D1
         BEQ     EA1115X        FPU extended (12 bytes)
         CMPI.B  #'P',D1
         BEQ     EA1115X        FPU packed (12 bytes)

         MOVE.W  (A4,D3),D0

         CMPI.B  #'B',D1
         BNE.S   EA11153        .WORD

* BYTE SIZE* DATA ALLOWED
*  0000 0000 XXXX XXXX
*  1111 1111 1XXX XXXX
         MOVE.L  D0,D1
         LSR.W   #8,D1
         BEQ.S   EA11153
         MOVE.L  D0,D1
         ASR.W   #7,D1
         ADDQ.W  #1,D1
         BNE     FE11           FERROR

EA11153  EXT.L   D0
         BSR     HEX2DEC
         ADDQ.L  #2,D3
         RTS

EA11155  MOVE.L  (A4,D3),D0
         BSR     HEX2DEC
         ADDQ.L  #4,D3          SIZE
         RTS

* FPU single immediate (4 bytes) — display as hex
EA11155S MOVE.B  #'$',(A6)+
         MOVE.L  (A4,D3),D0
         BSR     PNT8HX
         ADDQ.L  #4,D3
         RTS

* FPU double immediate (8 bytes) — display as hex
EA11158  MOVE.B  #'$',(A6)+
         MOVE.L  (A4,D3),D0
         BSR     PNT8HX
         MOVE.L  4(A4,D3),D0
         BSR     PNT8HX
         ADDQ.L  #8,D3
         RTS

* FPU extended/packed immediate (12 bytes) — display as hex
EA1115X  MOVE.B  #'$',(A6)+
         MOVE.L  (A4,D3),D0
         BSR     PNT8HX
         MOVE.L  4(A4,D3),D0
         BSR     PNT8HX
         MOVE.L  8(A4,D3),D0
         BSR     PNT8HX
         ADD.L   #12,D3
         RTS

MOVEMS   MOVE.B  #'.',(A5)+     PERIOD
         MOVE.W  #'LW',D0
         BTST    #6,D4
         BEQ.S   MOVEMS2
         LSR.W   #8,D0
MOVEMS2  MOVE.B  D0,(A5)+       SIZE
         RTS

* MOVEM - REGISTER EXPANSION
*
MOVEMR   DS      0
         MOVE.W  2(A4),D2       D2 = SECOND WORD
         MOVEQ   #$20,D0        D0 = SPACE
         MOVEQ   #$2F,D7        D7 = /
         SUBQ.L  #1,A6          ADJUST STORE POINTER
         MOVEQ   #$30,D5        D5 = REGISTER #
         MOVE.W  #'AD',D4       D4 = REG CLASS

MOVEMR11 BTST    D1,D2
         BEQ.S   MOVEMR77       BIT RESET

         CMP.B   (A6),D0        BIT SET
         BNE.S   MOVEMR44       NOT SPACE

MOVEMR33 MOVE.B  D4,1(A6)       REG TYPE
         MOVE.B  D5,2(A6)       REG #
         MOVE.B  #'-',3(A6)     -
         ADDQ.L  #3,A6
         BRA.S   MOVEMR88

MOVEMR44 CMPI.B  #',',(A6)
         BEQ     MOVEMR33       COMMA SEPARATOR

         CMP.B   (A6),D7        / SEPARATOR
         BEQ     MOVEMR33

         MOVE.B  D4,1(A6)       REG TYPE
         MOVE.B  D5,2(A6)       REG #
         MOVE.B  #'-',3(A6)     - SEPARATOR
         BRA.S   MOVEMR88

MOVEMR77 CMPI.B  #',',(A6)
         BEQ.S   MOVEMR88       COMMA

         CMP.B   (A6),D0
         BEQ.S   MOVEMR88       SPACE
         CMP.B   1(A6),D0
         BEQ.S   MOVEMR79       SPACE
         ADDQ.L  #3,A6
MOVEMR79 MOVE.B  D7,(A6)        / SEPARATOR

MOVEMR88 ADDQ.L  #1,D5
         ADD.L   D6,D1          D1 = BIT POSITION
         CMPI.B  #'8',D5
         BNE     MOVEMR11

         CMP.B   (A6),D0        SPACE
         BEQ.S   MOVEMR94

         CMP.B   1(A6),D0       SPACE
         BEQ.S   MOVEMR94
         ADDQ.L  #3,A6
         MOVE.B  D7,(A6)        /   SEPARATOR

MOVEMR94 MOVE.B  #'0',D5        RESET REG TO ZERO
         LSR.W   #8,D4          CHANGE REG TYPE
         BNE     MOVEMR11       MORE

         MOVE.B  D0,(A6)        SPACE
         RTS

DCODE68K DS      0
         LINK    A1,#-LOCVARSZ       CREATE A FRAME FOR THE
         MOVEM.L D0-D2/A4,DDATA(A1)  CODE AND ITS PC.  A4
         LEA     DDATA(A1),A4        POINTS TO THE CODE.

         MOVE.L  A5,A3          A3 = START OF OUTPUT BUFFER
         MOVEQ   #BUFSIZE,D0
         MOVE.L  A3,A6
DEC311   MOVE.B  #BLANK,(A6)+   SPACE FILL BUFFER
         SUBQ.L  #1,D0
         BNE     DEC311

         MOVE.L  A3,A6          FORMAT ADDRESS
         MOVE.L  HISPC(A1),D0
         BSR     FRELADDR

* CHECK FOR KNOWN ILLEGAL CODES
         MOVE.W  (A4),D0

         LEA     KI(PC),A5
         MOVE.L  A5,A6
         ADD.L   #KIEND-KI,A6
DEC404   CMP.W   (A5)+,D0
         BEQ.S   FE12           FERROR*  ILLEGAL CODE
         CMP.L   A6,A5
         BNE     DEC404

* Check for F-line (FPU) before TBL scan
         MOVE.W  (A4),D0
         ANDI.W  #$F000,D0
         CMPI.W  #$F000,D0
         BNE.S   DNOTFL
         MOVEQ   #2,D3
         MOVE.W  (A4),D4
         MOVE.B  #',',D5
         MOVEQ   #FOP,D0
         LEA.L   (A3,D0),A6
         BRA     IFLINE
DNOTFL
* LOOK FOR MATCH OF OP-CODE
*
         LEA     TBL(PC),A5     A5 = POINTER TO DECODE TABLE
         LEA     TBLE(PC),A6    A6 = POINTER TO END OF TABLE
DEC411   MOVE.W  (A4),D0        FIRST WORD
         AND.W   (A5)+,D0       MASK
         CMP.W   (A5)+,D0
         BEQ.S   DEC425         FOUND MATCH
         ADDQ.L  #2,A5          UPDATE POINTER
         CMP.L   A6,A5
         BNE     DEC411         MORE TABLE
FE12     BRA.S   FERROR         ILLEGAL INSTRUCTION

DEC425   CLR.L   D6
         MOVE.B  (A5)+,D6       D6 = (GOTO OFFSET)/4
         LSL.L   #2,D6

         CLR.L   D7
         MOVE.B  (A5)+,D7       D7 = INDEX TO OP-CODE

* MOVE OP-CODE TO BUFFER
*
         LEA     OPCTBL(PC),A0
DEC510   TST     D7
         BEQ.S   DEC530         AT INDEX
DEC515   TST.B   (A0)+
         BPL     DEC515         MOVE THROUGH FIELD
         SUBQ.L  #1,D7
         BRA     DEC510

DEC530   MOVEQ   #FOC,D0
         LEA.L   (A3,D0),A5     A5 = STORE POINTER  OP-CODE
DEC535   MOVE.B  (A0)+,D0
         BCLR    #7,D0
         BNE.S   DEC537         END OF MOVE
         MOVE.B  D0,(A5)+
         BRA     DEC535
DEC537   MOVE.B  D0,(A5)+

* CALCULATE GOTO AND GO
*
         MOVEQ   #2,D3          D3= SIZE
         LEA     X(PC),A0
         ADD.L   D6,A0

         MOVEQ   #FOP,D0
         LEA.L   (A3,D0),A6     A6 = POINTER FOR OPERAND

         MOVE.W  (A4),D4        D4 = FIRST WORD

         MOVE.B  #',',D5        D5 = CONTAINS ASCII COMMA

         MOVE.W  #$1FD,D7       D7 = DATA ALTERABLE MODES ALLOWED

         JMP     (A0)
*
*  A4 = POINTER TO DATA IN FRAME CREATED BY 'LINK A1,...'
*  A5 = POINTER STORE OP-CODE
*  A6 = POINTER STORE OPERAND
*  D3 = SIZE = 2 BYTES
*  D4 = FIRST WORD
*  D7 = ADDRESS MODES ALLOWED ($1FD) DATA ALTERABLE

COMMON4  ADDQ.L  #2,D3          SIZE = 4

COMMON   MOVE.L  D3,D6          D6 = SIZE
         MOVE.B  #BLANK,(A6)+   SPACE AS LAST CHAR

         MOVE.L  A6,A5          SAVE END OF BUFFER POINTER
         MOVEQ   #FDATA,D0
         LEA.L   (A3,D0),A6

COMMON35 MOVE.W  (A4)+,D0       GET NEXT WORD OF DATA.
         ADDQ.L  #2,HISPC(A1)   ADJUST PROG COUNTER.
         BSR     PNT4HX         FORMAT DATA. (A6)+
         SUBQ.B  #2,D3
         BNE     COMMON35

         MOVE.L  A5,A6          A6 = RESTORE END POINTER

         MOVE.L  A3,A5          A5 =  BEGINNING OF BUFFER

         MOVE.L  HISPC(A1),A4   MOVE THE UPDATED PC
         UNLK    A1               TO A4 AND UNDO FRAME.

         RTS


FERROR   DS      0
* ILLEGAL INSTRUCTION
*
         MOVEQ   #FOC,D0
         LEA.L   (A3,D0),A6
         LEA     MSG111(PC),A5
FERROR35 MOVE.B  (A5)+,D0
         CMPI.B  #EOT,D0
         BEQ.S   FERROR39
         MOVE.B  D0,(A6)+
         BRA     FERROR35
FERROR39 DS      0

         MOVE.W  (A4),D0
         BSR     PNT4HX

         MOVEQ   #2,D3          SIZE

         BRA     COMMON
         

*-------------------------------------------------------------------------
* File HEX2DEC   HEX2DEC convert hex to decimal                   11/02/81


*    CONVERT BINARY TO DECIMAL  REG D0 PUT IN (A6) BUFFER AS ASCII

HEX2DEC  MOVEM.L D1-D4/D6-D7,-(A7)   SAVE REGISTERS
         MOVE.L  D0,D7          SAVE IT HERE
         BPL.S   HX2DC
         NEG.L   D7             CHANGE TO POSITIVE
         BMI.S   HX2DC57        SPECIAL CASE (-0)
         MOVE.B  #'-',(A6)+     PUT IN NEG SIGN
HX2DC    CLR.W   D4             FOR ZERO SURPRESS
         MOVEQ   #10,D6         COUNTER
HX2DC0   MOVEQ   #1,D2          VALUE TO SUB
         MOVE.L  D6,D1          COUNTER
         SUBQ.L  #1,D1          ADJUST - FORM POWER OF TEN
         BEQ.S   HX2DC2         IF POWER IS ZERO
HX2DC1   MOVE.W  D2,D3          D3=LOWER WORD
         MULU    #10,D3
         SWAP    D2             D2=UPPER WORD
         MULU    #10,D2
         SWAP    D3             ADD UPPER TO UPPER
         ADD.W   D3,D2
         SWAP    D2             PUT UPPER IN UPPER
         SWAP    D3             PUT LOWER IN LOWER
         MOVE.W  D3,D2          D2=UPPER & LOWER
         SUBQ.L  #1,D1
         BNE     HX2DC1
HX2DC2   CLR.L   D0             HOLDS SUB AMT
HX2DC22  CMP.L   D2,D7
         BLT.S   HX2DC3         IF NO MORE SUB POSSIBLE
         ADDQ.L  #1,D0          BUMP SUBS
         SUB.L   D2,D7          COUNT DOWN BY POWERS OF TEN
         BRA.S   HX2DC22        DO MORE
HX2DC3   TST.B   D0             ANY VALUE?
         BNE.S   HX2DC4
         TST.W   D4             ZERO SURPRESS
         BEQ.S   HX2DC5
HX2DC4   ADDI.B  #$30,D0        BINARY TO ASCII
         MOVE.B  D0,(A6)+       PUT IN BUFFER
         MOVE.B  D0,D4          MARK AS NON ZERO SURPRESS
HX2DC5   SUBQ.L  #1,D6          NEXT POWER
         BNE     HX2DC0
         TST.W   D4             SEE IF ANYTHING PRINTED
         BNE.S   HX2DC6
HX2DC57  MOVE.B  #'0',(A6)+     PRINT AT LEST A ZERO
HX2DC6   MOVEM.L (A7)+,D1-D4/D6-D7   RESTORE REGISTERS
         RTS                    END OF ROUTINE
         

*   ROUTINES TO CONVERT STRING TO BINARY VALUE
*
*        ACCEPTS PREFIXES:
*         % binary
*         @ octal
*         & decimal
*         $ hex
*
GETNUMD  BSR.S   GETDECNU       GET DECIMAL NUMBER
GETNUMD9 BNE     ERROR
         RTS

GETNUMA  BSR.S   GETHEXNU       GET HEX NUMBER
         BRA     GETNUMD9

GETDECNU MOVEM.L D1-D5/A0,-(A7) DECODE AS A DECIMAL NUMBER
         MOVEQ   #10,D3         D3 = BASE (DECIMAL)
         BRA.S   GETN20

GETHEXNU MOVEM.L D1-D5/A0,-(A7) DECODE AS A HEX NUMBER
         MOVEQ   #16,D3         D3 = BASE

GETN20   CLR.W   D4             D4 = FLAG FOR CHARACTER HIT
         CLR.L   D1             D1 = TEMP RESULTS
         CMPI.B  #BLANK,(A5)
         BEQ.S   GETN80         FIRST CHAR SPACE* ERROR

GETN30   CMP.L   A6,A5          SEE IF AT END OF BUFFER
         BEQ.S   GETN90
         CLR.L   D0
         MOVE.B  (A5)+,D0       D0 = CHARACTER

         LEA     GETNDATA(PC),A0 POINTER TO TERMINATE CHARS
GETN40   MOVE.B  (A0)+,D5       D5 = TERMINATION CHAR
         BEQ.S   GETN50         NOT TERM.CHAR
         CMP.B   D5,D0
         BEQ.S   GETN85         FOUND TERMINATION CHAR* EXIT
         BRA     GETN40

GETN50   CMPI.B  #'%',D0        SEE IF FLAGGED AS BINARY
         BNE.S   GETN60
         MOVEQ   #2,D3          BASE IS BINARY
GETN55   TST.W   D4             ANYTHING ENTERED
         BNE.S   GETN80         CONFLICT

GETN57   MOVEQ   #-1,D4         SET DATA ENTERED FLAG
         BRA     GETN30

GETN60   CMPI.B  #'@',D0        SEE IF FLAGGED AS OCTAL
         BNE.S   GETN65
         MOVEQ   #8,D3          BASE IS OCTAL
         BRA     GETN55

GETN65   CMPI.B  #'&',D0        SEE IF FLAGGED AS DECIMAL
         BNE.S   GETN70
         MOVEQ   #10,D3         BASE IS DECIMAL
         BRA     GETN55

GETN70   CMPI.B  #'$',D0        SEE IF FLAGGED AS HEX
         BNE.S   GETN75
         MOVEQ   #16,D3         BASE IS 16
         BRA     GETN55

GETN75   SUBI.B  #$30,D0
         BLT.S   GETN80         LESS THAN ZERO
         CMPI.B  #9,D0
         BLE.S   GETN77         VALUE 0 - 9
         CMPI.B  #$11,D0
         BLT.S   GETN80         LESS THAN A
         CMPI.B  #$16,D0
         BGT.S   GETN80         GREATER THAN F
         SUBQ.B  #7,D0          MAKE BINARY

GETN77   CMP.W   D3,D0          IS INPUT LARGER THAN BASE
         BCC.S   GETN80         LARGER THAN BASE
         MOVE.L  D1,D2          GET READY TO MULTIPLY D1*BASE
         SWAP    D1
         MULU    D3,D1          TOP PART
         SWAP    D1
         TST.W   D1             CHECK FOR OVERFLOW
         BNE.S   GETN80         VALUE IS TOO LARGE
         MULU    D3,D2          NOW WORK ON LOW WORD
         ADD.L   D2,D1          PUT IT BACK TOGETHER
         BVS.S   GETN80         OVERFLOW?
         ADD.L   D0,D1          ADD IN NEW STUFF
         BVC     GETN57
GETN80   MOVEQ   #-1,D0         ERROR RETURN (BNE)
         BRA.S   GETN95

GETN85   SUBQ.L  #1,A5          BACK UP TO POINT AT SPACE/PREVIOUS CHAR
GETN90   MOVE.L  D1,D0          SET UP RESULT FOR RETURN
         CLR.L   D1             NORMAL RETURN (BEQ)
GETN95   MOVEM.L (A7)+,D1-D5/A0 RESTORE SOME REGISTERS
         RTS

* FORMAT RELATIVE ADDRESS  AAAAAA+Rn
*        ENTER     D0 = VALUE
*                  A6 = STORE POINTER
*
FRELADDR MOVEM.L D1/D5-D7/A0,-(A7)
         LEA     OFFSET,A0
         MOVEQ   #-1,D7         D7 = DIFF. BEST FIT
         CLR.L   D6             D6 = OFFSET POSITION

FREL10   MOVE.L  D0,D1
         TST.L   (A0)
         BEQ.S   FREL15         ZERO OFFSET
         SUB.L   (A0),D1        D1 = DIFF.
         BMI.S   FREL15         NO FIT

         CMP.L   D7,D1
         BCC.S   FREL15         OLD FIT BETTER

         MOVE.L  D1,D7          D7 = NEW BEST FIT
         MOVE.L  D6,D5          D5 = POSITION

FREL15   ADDQ.L  #4,A0
         ADDQ.L  #1,D6
         CMPI.W  #8,D6
         BNE     FREL10         MORE OFFSETS TO CHECK

         TST.L   D7
         BMI.S   FREL25         NO FIT
         TST     D6
         BNE.S   FREL20
         TST.L   OFFSET
         BEQ.S   FREL25         R0 = 000000* NO FIT

FREL20   SUB #1,D7
         MOVE.L  D7,D0
         BSR     PNT6HX         FORMAT OFFSET
         MOVE.B  #'+',(A6)+     +
         MOVE.B  #'R',(A6)+     R
         ADDI.B  #'0',D5        MAKE ASCII
         BRA.S   FREL30

FREL25   BSR     PNT6HX         FORMAT ADDRESS AS IS
         MOVE.B  #BLANK,D5
         MOVE.B  D5,(A6)+       THREE SPACES FOR ALIGNMENT
         MOVE.B  D5,(A6)+
FREL30   MOVE.B  D5,(A6)+

         MOVEM.L (A7)+,D1/D5-D7/A0
         RTS


*************************************************************
* -FIXDATA- SUBROUTINE...  MOVES MESSAGE POINTED TO BY (A5) *
*                          INTO "BUFFER". EOT,($04),ENDS  *
*                          THE MOVE. AT COMPLETION (A5) IS  *
*                          POINTING AT THE BEGINNING,(A6)  *
*                          POINTS AT END.                   *
*************************************************************

FIXDATA  LEA     BUFFER,A6
FIXDADD  CMPI.B  #EOT,(A5)
         BEQ.S   FIXD2
         MOVE.B  (A5)+,(A6)+
         BRA     FIXDADD
FIXD2    LEA     BUFFER,A5
         RTS


************************************************************
* -FIXDCRLF- SUBROUTINE INSERTS A CARRIAGE RETURN AND LINE *
*                       FEED IN FRONT OF THE TEXT,THEN    *
*                       USES THE REMAINING PORTION OF THE  *
*                       FIXDATA.                           *
************************************************************

FIXDCRLF LEA     BUFFER,A6
         MOVE.W  #$0D0A,(A6)+   CR,LF
         BRA     FIXDADD



*
*  ***GETHEX***  GET HEX (BINARY VALUE FROM ASCII)
*   D0.B HAS ASCII CHAR  RETURNS $0-$F BINARY
*
GETHEX CMPI.B    #$30,D0        IS IT LESS THAN ZERO
       BLT.S     PNMSG011
       CMPI.B    #$39,D0        IS IT GREATER THAN 9
       BLE.S     GTHX2          GOOD HEX

       CMPI.B    #$41,D0        IS IT LESS THAN 'A'
       BLT.S     PNMSG011
       CMPI.B    #$46,D0        IS IT GT 'F'
       BGT.S     PNMSG011
       SUBQ.B    #7,D0          MAKE IT SMALLER A=10
GTHX2  ANDI.L    #$F,D0
       RTS

PNMSG011 BSR     FIXBUF         PRINT NOT A HEX DIGIT
         MOVE.B  D0,(A6)+       PUT IN OFFENDING CHAR
         LEA     MSG011(PC),A5  '  IS NOT A HEX DIGIT'
         BSR     FIXDADD
         BRA     MSG            GO PRINT IT AND ENTER MACSBUG


*
*  PRINT HEX ROUTINES
*
*
* PRINT 8 HEX CHARACTERS
*
*  D0,D1,D2 DESTROYED
*
PNT8HX   SWAP    D0             FLIP REG HALVES
         BSR.S   PNT4HX         DO TOP WORD
         SWAP    D0             NOW DO LOWER WORD
         BRA.S   PNT4HX
* PRINT 6 HEX CHARACTERS
PNT6HX   SWAP    D0             FLIP REGISTER HALVES
         BSR.S   PNT2HX
         SWAP    D0             FLIP BACK REG HALVES
* PRINT 4 HEX CHARACTERS IN D0.W
PNT4HX   MOVE.W  D0,D1          SAVE IN TEMP
         ROR.W   #8,D0          GET BITS 15-8 INTO LOWER BYTE
         BSR.S   PNT2HX         PRINT IT
         MOVE.W  D1,D0          PULL IT BACK
* PRINT 2 HEX CHARACTERS IN D0.B
PNT2HX   MOVE.W  D0,D2          SAVE IN TEMP REG
         ROXR.W  #4,D0          FORM UPPER NIBBLE
         BSR.S   PUTHEX         PUT ASCII INTO PRINT BUFFER
         MOVE.W  D2,D0          GET BACK FROM TEMP
* CONVERT D0.NIBBLE TO HEX & PUT IT IN PRINT BUFFER
*
PUTHEX   ANDI.B  #$0F,D0        SAVE LOWER NIBBLE
         ORI.B   #$30,D0        CONVERT TO ASCII
         CMPI.B  #$39,D0        SEE IF IT IS>9
         BLE.S   SAVHEX
         ADD     #7,D0          ADD TO MAKE 10=>A
SAVHEX   MOVE.B  D0,(A6)+       PUT IT IN PRINT BUFFER
         RTS

* PRINT ERROR

ERROR    LEA     MSG008E(PC),A5
         BRA     WHAT93

SYNTAX   LEA     MSG008(PC),A5  'SYNTAX ERROR'
         BRA     WHAT93

* PRINT WHAT

WHAT     LEA     MSG021(PC),A5  PRINT 'WHAT' AND ENTER MACSBUG
WHAT93   BSR   FIXDATA
        *CLR.W   TRACEON
MSG     move.b #0,(a6)+
        move.b #13,d0
        move.l a6,a1
        trap #15
        
*
*     FIX THE BUFFER A5 & A6 SET TO START OF BUFFER QUE
*
FIXBUF   LEA     BUFFER,A5
         MOVE.L  A5,A6
         RTS


MSG011   DC.B    '  IS NOT A HEX DIGIT',EOT
MSG111   DC.B    'DC.W    $',EOT
MSG008   DC.B    'SYNTAX '
MSG008E  DC.B    'ERROR '
MSGEOT   DC.B    EOT
MSG021   DC.B    'WHAT',EOT
CRLF     DC.B    $0D,$0A,0

GETNDATA DC.B    ' (+,-.:;=^]',0 TERMINATE CHARS
         EVEN                   Word-align KI/TBL
KI       DC.W    $4AFB          KNOWN ILLEGAL CODES
KIEND    DS      0

*  \1   MASK
*  \2   OP-CODE PATTERN
*  \3   GOTO OFFSET
*  \4   INDEX TO OP-CODE
C68      MACRO
         DC.W    $\1
         DC.W    $\2
         DC.B    (\3-X)>>2
         DC.B    \4
         ENDM

TBL      DS      0
         C68     FEC0,E6C0,ISHIFT,56           RO
         C68     FEC0,E4C0,ISHIFT,57           ROX
         C68     FEC0,E2C0,ISHIFT,55           LS
         C68     FEC0,E0C0,ISHIFT,54           AS
         C68     F018,E018,ISHIFT,56           RO
         C68     F018,E010,ISHIFT,57           ROX
         C68     F018,E008,ISHIFT,55           LS
         C68     F018,E000,ISHIFT,54           AS
         C68     F0C0,D0C0,FORM10EX,4          ADD       <EA>,A@
         C68     F130,D100,FORM12,53           ADDX
         C68     F000,D000,FORM10EX,4            ADD
         C68     F1F8,C188,FORM9,50            EXG
         C68     F1F8,C148,FORM8,50            EXG
         C68     F1F8,C140,FORM7,50            EXG
         C68     F1F0,C100,FORM12,49           ABCD
         C68     F1C0,C1C0,FORM6D,48           MULS
         C68     F1C0,C0C0,FORM6D,47           MULU
         C68     F000,C000,FORM10,2            AND
         C68     F0C0,B0C0,FORM10EX,6          CMP     <EA>,A@
         C68     F138,B108,FORM12A,46           CMPM
         C68     F100,B100,FORM10,5            EOR
         C68     F000,B000,FORM10EX,6            CMP
         C68     F0C0,90C0,FORM10EX,44         SUB       <EA>,A@
         C68     F130,9100,FORM12,45           SUBX
         C68     F000,9000,FORM10EX,44           SUB
         C68     F1F0,8100,FORM12,43           SBCD
         C68     F1C0,81C0,FORM6D,42           DIVS
         C68     F1C0,80C0,FORM6D,41           DIVU
         C68     F000,8000,FORM10,40           OR
         C68     F100,7000,IMOVEQ,39           MOVEQ
         C68     FF00,6100,IBSR,51             BSR
         C68     FF00,6000,IBSR,65             BRA
         C68     F000,6000,ICC,38              B
         C68     F0F8,50C8,IDBCC,37              DB
         C68     F0C0,50C0,ISCC,36             S
         C68     F100,5100,IQUICK,35           SUBQ
         C68     F100,5000,IQUICK,34           ADDQ
         C68     F1C0,41C0,FORM6A,33           LEA
         C68     F1C0,4180,FORM6D,32           CHK
         C68     FFC0,4EC0,FORM11SL,31         JMP
         C68     FFC0,4E80,FORM11SL,30         JSR
         C68     FFFF,4E77,SCOMMON,29           RTR
         C68     FFFF,4E76,SCOMMON,28           TRAPV
         C68     FFFF,4E75,SCOMMON,27           RTS
         C68     FFFF,4E73,SCOMMON,26           RTE
         C68     FFFF,4E72,ISTOP,25             STOP
         C68     FFFF,4E71,SCOMMON,24           NOP
         C68     FFFF,4E70,SCOMMON,23           RESET
         C68     FFF8,4E68,IMVFUSP,60          MOVE FROM USP
         C68     FFF8,4E60,IMVTUSP,60          MOVE TO USP
         C68     FFF8,4E58,FORM5,22            UNLINK
         C68     FFF8,4E50,ILINK,21            LINK
         C68     FFF0,4E40,FORM4,20            TRAP
         C68     FF80,4C80,IMOVEMTR,15         MOVEM FROM REGISTERS
         C68     FFC0,4AC0,FORM1A,19           TAS
         C68     FF00,4A00,FORM1,18            TST
         C68     FFF8,48C0,FORM3,17            EXT.L
         C68     FFF8,4880,FORM3,16            EXT.W
         C68     FF80,4880,IMOVEMFR,15         MOVEA TO REGISTERS
         C68     FFF8,4840,FORM3,14            SWAP
         C68     FFC0,4840,FORM11,13           PEA
         C68     FFC0,4800,FORM1A,12           NBCD
         C68     FFC0,46C0,IMVTSR,59           MOVE TO SR
         C68     FF00,4600,FORM1,11            NOT
         C68     FFC0,44C0,IMVTCCR,59          MOVE TO CCR
         C68     FF00,4400,FORM1,10            NEG
         C68     FF00,4200,FORM1,9             CLR
         C68     FFC0,40C0,IMVFSR,59           MOVE.W  FROM  SR
         C68     FF00,4000,FORM1,8             NEGX
         C68     F000,3000,IMOVE,59            MOVE.W
         C68     F000,2000,IMOVE,60            MOVE.L
         C68     F000,1000,IMOVE,58            MOVE.B
         C68     FF00,0C00,IMMED,6             CMP       #
         C68     FF00,0A00,IMMED,5             EOR       #
         C68     FF00,0600,IMMED,4             ADD       #
         C68     FF00,0400,IMMED,3             SUB       #
         C68     FF00,0200,IMMED,2             AND       #
         C68     FF00,0000,IMMED,1             OR        #
         C68     F138,0108,IMOVEP,0            MOVEP
         C68     FFC0,08C0,ISETS,64            BSET
         C68     FFC0,0880,ISETS,63            BCLR
         C68     FFC0,0840,ISETS,62            BCHG
         C68     FFC0,0800,ISETS,61            BTST
         C68     F1C0,01C0,ISETD,64            BSET
         C68     F1C0,0180,ISETD,63            BCLR
         C68     F1C0,0140,ISETD,62            BCHG
         C68     F1C0,0100,ISETD,61            BTST
*------------------------------------------------------------------------
* FPU data tables for IFLINE disassembler
*------------------------------------------------------------------------

* FPU 7-bit opcode -> N68 index lookup (128 bytes)
FOPTBL   DC.B    66          ; $00 FMOVE
         DC.B    94          ; $01 FINT
         DC.B    82          ; $02 FSINH
         DC.B    95          ; $03 FINTRZ
         DC.B    73          ; $04 FSQRT
         DC.B    0           ; $05 unused
         DC.B    91          ; $06 FLOGNP1
         DC.B    0           ; $07 unused
         DC.B    87          ; $08 FETOXM1
         DC.B    84          ; $09 FTANH
         DC.B    79          ; $0A FATAN
         DC.B    0           ; $0B unused
         DC.B    80          ; $0C FASIN
         DC.B    85          ; $0D FATANH
         DC.B    76          ; $0E FSIN
         DC.B    78          ; $0F FTAN
         DC.B    86          ; $10 FETOX
         DC.B    88          ; $11 FTWOTOX
         DC.B    89          ; $12 FTENTOX
         DC.B    0           ; $13 unused
         DC.B    90          ; $14 FLOGN
         DC.B    92          ; $15 FLOG10
         DC.B    93          ; $16 FLOG2
         DC.B    0           ; $17 unused
         DC.B    72          ; $18 FABS
         DC.B    83          ; $19 FCOSH
         DC.B    71          ; $1A FNEG
         DC.B    0           ; $1B unused
         DC.B    81          ; $1C FACOS
         DC.B    77          ; $1D FCOS
         DC.B    96          ; $1E FGETEXP
         DC.B    97          ; $1F FGETMAN
         DC.B    70          ; $20 FDIV
         DC.B    98          ; $21 FMOD
         DC.B    67          ; $22 FADD
         DC.B    69          ; $23 FMUL
         DC.B    101         ; $24 FSGLDIV
         DC.B    99          ; $25 FREM
         DC.B    100         ; $26 FSCALE
         DC.B    102         ; $27 FSGLMUL
         DC.B    68          ; $28 FSUB
         DC.B    0,0,0,0,0,0,0  ; $29-$2F unused
         DC.B    103,103,103,103,103,103,103,103 ; $30-$37 FSINCOS
         DC.B    74          ; $38 FCMP
         DC.B    0           ; $39 unused
         DC.B    75          ; $3A FTST
         DC.B    0,0,0,0,0   ; $3B-$3F unused
         DC.B    0,0,0,0,0,0,0,0  ; $40-$47
         DC.B    0,0,0,0,0,0,0,0  ; $48-$4F
         DC.B    0,0,0,0,0,0,0,0  ; $50-$57
         DC.B    0,0,0,0,0,0,0,0  ; $58-$5F
         DC.B    0,0,0,0,0,0,0,0  ; $60-$67
         DC.B    0,0,0,0,0,0,0,0  ; $68-$6F
         DC.B    0,0,0,0,0,0,0,0  ; $70-$77
         DC.B    0,0,0,0,0,0,0,0  ; $78-$7F

* FBcc condition code suffix strings (null-terminated, packed)
FBCCTBL  DC.B    'F',0               ; $00
         DC.B    'EQ',0              ; $01
         DC.B    'OGT',0             ; $02
         DC.B    'OGE',0             ; $03
         DC.B    'OLT',0             ; $04
         DC.B    'OLE',0             ; $05
         DC.B    'OGL',0             ; $06
         DC.B    'OR',0              ; $07
         DC.B    'UN',0              ; $08
         DC.B    'UEQ',0             ; $09
         DC.B    'UGT',0             ; $0A
         DC.B    'UGE',0             ; $0B
         DC.B    'ULT',0             ; $0C
         DC.B    'ULE',0             ; $0D
         DC.B    'NE',0              ; $0E
         DC.B    'T',0               ; $0F
         DC.B    'SF',0              ; $10
         DC.B    'SEQ',0             ; $11
         DC.B    'GT',0              ; $12
         DC.B    'GE',0              ; $13
         DC.B    'LT',0              ; $14
         DC.B    'LE',0              ; $15
         DC.B    'GL',0              ; $16
         DC.B    'GLE',0             ; $17
         DC.B    'NGLE',0            ; $18
         DC.B    'NGL',0             ; $19
         DC.B    'NLE',0             ; $1A
         DC.B    'NLT',0             ; $1B
         DC.B    'NGE',0             ; $1C
         DC.B    'NGT',0             ; $1D
         DC.B    'SNE',0             ; $1E
         DC.B    'ST',0              ; $1F

* FP format code -> size suffix character (indexed 0-7)
FFMTTBL  DC.B    'L'         ; 0 = Long int
         DC.B    'S'         ; 1 = Single
         DC.B    'X'         ; 2 = Extended
         DC.B    'P'         ; 3 = Packed BCD
         DC.B    'W'         ; 4 = Word int
         DC.B    'D'         ; 5 = Double
         DC.B    'B'         ; 6 = Byte int
         DC.B    '?'         ; 7 = invalid

FMCRSTR  DC.B    'FMOVECR',0
         DS.W    0           Word-align

*------------------------------------------------------------------------
* IFLINE — F-line (FPU) instruction disassembler handler
*
* Entry: A4=data ptr, A3=output buf, A6=operand ptr (FOP),
*        D3=2 (size), D4=first word (opword), D5=','
*------------------------------------------------------------------------
         EVEN
         LONG
IFLINE   DS      0
* Check CpID = 001 (bits 11:9)
         MOVE.W  D4,D0
         ANDI.W  #$0E00,D0
         CMPI.W  #$0200,D0       CpID = 001?
         BNE     FERROR          Not FPU

* Get type field (bits 8:6)
         MOVE.W  D4,D0
         LSR.W   #6,D0
         ANDI.W  #7,D0

         BEQ     IFL_GEN         Type 000 = general
         CMPI.B  #2,D0
         BEQ     IFL_FBCC        Type 010 = FBcc.W
         CMPI.B  #3,D0
         BEQ     IFL_FBCC        Type 011 = FBcc.L
         BRA     FERROR

*--- FBcc: opword = 1111 001 01s cccccc ---
IFL_FBCC
         MOVEQ   #FOC,D0
         LEA.L   (A3,D0),A5
         MOVE.B  #'F',(A5)+
         MOVE.B  #'B',(A5)+

* Get condition code (bits 5:0 of opword)
         MOVE.W  D4,D0
         ANDI.W  #$3F,D0

* Walk FBcc condition table to find entry
         LEA     FBCCTBL(PC),A0
         TST.B   D0
         BEQ.S   IFLB_FND
IFLB_SK  TST.B   (A0)+
         BNE.S   IFLB_SK         Skip until null
         SUBQ.B  #1,D0
         BNE.S   IFLB_SK         Next entry
IFLB_FND
* Copy condition string
IFLB_CP  MOVE.B  (A0)+,D0
         BEQ.S   IFLB_DN
         MOVE.B  D0,(A5)+
         BRA.S   IFLB_CP
IFLB_DN  MOVE.B  #' ',(A5)+

* Check size bit (bit 6 of opword = type bit 0)
         BTST    #6,D4
         BNE.S   IFLB_L32

* 16-bit displacement
         MOVE.W  2(A4),D0
         EXT.L   D0
         ADD.L   HISPC(A1),D0
         ADDQ.L  #2,D0
         BSR     PNT6HX
         BRA     COMMON4         Size = 4

* 32-bit displacement
IFLB_L32
         MOVE.W  2(A4),D0
         SWAP    D0
         MOVE.W  4(A4),D0
         ADD.L   HISPC(A1),D0
         ADDQ.L  #2,D0
         BSR     PNT6HX
         ADDQ.L  #4,D3           Size = 6
         BRA     COMMON

*--- General instruction (type 000) ---
IFL_GEN
         MOVE.W  2(A4),D6        D6 = command word

* Check for FMOVECR: bits 15:10 = 010111
         MOVE.W  D6,D0
         ANDI.W  #$FC00,D0
         CMPI.W  #$5C00,D0
         BEQ     IFL_MCR

* Check for FMOVE control regs: bits 15:13 = 100 or 101
         MOVE.W  D6,D0
         ANDI.W  #$E000,D0
         CMPI.W  #$8000,D0
         BEQ     IFL_CTRL
         CMPI.W  #$A000,D0
         BEQ     IFL_CTRL

* Check for FMOVE FPn-><ea>: bits 15:13 = 011
         CMPI.W  #$6000,D0
         BEQ     IFL_TMEM

* General arithmetic: get 7-bit opcode
         MOVE.W  D6,D0
         ANDI.W  #$7F,D0

* Look up N68 index in FOPTBL
         LEA     FOPTBL(PC),A0
         CLR.L   D7
         MOVE.B  (A0,D0.W),D7
         BEQ     FERROR          Unknown opcode

* Navigate OPCTBL to N68 index and print mnemonic
         MOVEQ   #FOC,D0
         LEA.L   (A3,D0),A5
         LEA     OPCTBL(PC),A0
         MOVE.L  D7,D0
IFL_NV1  TST.W   D0
         BEQ.S   IFL_NV3
IFL_NV2  TST.B   (A0)+
         BPL     IFL_NV2         Skip until MSB set
         SUBQ.L  #1,D0
         BRA.S   IFL_NV1
IFL_NV3
* Copy mnemonic chars (MSB on last char)
IFL_NV4  MOVE.B  (A0)+,D0
         BCLR    #7,D0
         BNE.S   IFL_NV5
         MOVE.B  D0,(A5)+
         BRA.S   IFL_NV4
IFL_NV5  MOVE.B  D0,(A5)+

* Check R/M bit (bit 14 of command word)
         BTST    #14,D6
         BNE.S   IFL_MEM

* Register-to-register: FPsrc,FPdst
         MOVE.W  D6,D0
         LSR.W   #7,D0
         LSR.W   #3,D0
         ANDI.W  #7,D0           D0 = source FP reg
         MOVE.B  #'F',(A6)+
         MOVE.B  #'P',(A6)+
         ORI.B   #'0',D0
         MOVE.B  D0,(A6)+

* Check if FTST (no destination)
         MOVE.W  D6,D0
         ANDI.W  #$7F,D0
         CMPI.B  #$3A,D0
         BEQ.S   IFL_NDST

         MOVE.B  #',',(A6)+

* Destination FP reg
         MOVE.W  D6,D0
         LSR.W   #7,D0
         ANDI.W  #7,D0
         MOVE.B  #'F',(A6)+
         MOVE.B  #'P',(A6)+
         ORI.B   #'0',D0
         MOVE.B  D0,(A6)+

IFL_NDST BRA     COMMON4

* Memory/immediate to register
IFL_MEM
         MOVE.B  #'.',(A5)+
         MOVE.W  D6,D0
         LSR.W   #7,D0
         LSR.W   #3,D0
         ANDI.W  #7,D0           D0 = format code
         LEA     FFMTTBL(PC),A0
         MOVE.B  (A0,D0.W),(A5)+

* Decode EA — extension words start at offset 4 (past cmdword)
         ADDQ.L  #2,D3           D3 = 4 (past opword + cmdword)
         MOVE.W  #$FFF,D7
         BSR     EEA

         MOVE.B  #',',(A6)+

* Check if FTST (no destination) or FCMP
         MOVE.W  D6,D0
         ANDI.W  #$7F,D0
         CMPI.B  #$3A,D0
         BEQ.S   IFL_MEMD

* Destination FP reg
         MOVE.W  D6,D0
         LSR.W   #7,D0
         ANDI.W  #7,D0
         MOVE.B  #'F',(A6)+
         MOVE.B  #'P',(A6)+
         ORI.B   #'0',D0
         MOVE.B  D0,(A6)+

IFL_MEMD BRA     COMMON

*--- FMOVECR: command word = 0101110 ddd ooooooo ---
IFL_MCR
         MOVEQ   #FOC,D0
         LEA.L   (A3,D0),A5
         LEA     FMCRSTR(PC),A0
IFL_MC1  MOVE.B  (A0)+,D0
         BEQ.S   IFL_MC2
         MOVE.B  D0,(A5)+
         BRA.S   IFL_MC1
IFL_MC2

* Print #$offset
         MOVE.B  #'#',(A6)+
         MOVE.B  #'$',(A6)+
         MOVE.W  D6,D0
         ANDI.W  #$7F,D0
         BSR     PNT2HX

         MOVE.B  #',',(A6)+

* Destination FP reg
         MOVE.W  D6,D0
         LSR.W   #7,D0
         ANDI.W  #7,D0
         MOVE.B  #'F',(A6)+
         MOVE.B  #'P',(A6)+
         ORI.B   #'0',D0
         MOVE.B  D0,(A6)+
         BRA     COMMON4

*--- FMOVE control regs: cmd = 10 d rrr 0000000000 ---
IFL_CTRL
         MOVEQ   #FOC,D0
         LEA.L   (A3,D0),A5
         MOVE.B  #'F',(A5)+
         MOVE.B  #'M',(A5)+
         MOVE.B  #'O',(A5)+
         MOVE.B  #'V',(A5)+
         MOVE.B  #'E',(A5)+
         MOVE.B  #'.',(A5)+
         MOVE.B  #'L',(A5)+

* Check direction bit 13
         BTST    #13,D6
         BNE.S   IFL_CREG        Control reg -> EA

* EA -> control reg
         ADDQ.L  #2,D3           D3 = 4
         MOVE.W  #$FFF,D7
         BSR     EEA
         MOVE.B  #',',(A6)+
         BSR.S   IFL_PREG
         BRA     COMMON

* Control reg -> EA
IFL_CREG BSR.S   IFL_PREG
         MOVE.B  #',',(A6)+
         ADDQ.L  #2,D3           D3 = 4
         MOVE.W  #$1FD,D7
         BSR     EEA
         BRA     COMMON

* Print FP control register name from bits 12:10 of D6
IFL_PREG MOVE.W  D6,D0
         LSR.W   #8,D0
         LSR.W   #2,D0
         ANDI.W  #7,D0
         CMPI.B  #4,D0
         BEQ.S   IFL_PCR
         CMPI.B  #2,D0
         BEQ.S   IFL_PSR
         CMPI.B  #1,D0
         BEQ.S   IFL_PIAR
         MOVE.B  #'?',(A6)+
         RTS
IFL_PCR  MOVE.B  #'F',(A6)+
         MOVE.B  #'P',(A6)+
         MOVE.B  #'C',(A6)+
         MOVE.B  #'R',(A6)+
         RTS
IFL_PSR  MOVE.B  #'F',(A6)+
         MOVE.B  #'P',(A6)+
         MOVE.B  #'S',(A6)+
         MOVE.B  #'R',(A6)+
         RTS
IFL_PIAR MOVE.B  #'F',(A6)+
         MOVE.B  #'P',(A6)+
         MOVE.B  #'I',(A6)+
         MOVE.B  #'A',(A6)+
         MOVE.B  #'R',(A6)+
         RTS

*--- FMOVE FPn -> <ea>: cmd = 011 fff sss kkkkkkk ---
IFL_TMEM
         MOVEQ   #FOC,D0
         LEA.L   (A3,D0),A5
         MOVE.B  #'F',(A5)+
         MOVE.B  #'M',(A5)+
         MOVE.B  #'O',(A5)+
         MOVE.B  #'V',(A5)+
         MOVE.B  #'E',(A5)+

* Format suffix
         MOVE.B  #'.',(A5)+
         MOVE.W  D6,D0
         LSR.W   #7,D0
         LSR.W   #3,D0
         ANDI.W  #7,D0
         LEA     FFMTTBL(PC),A0
         MOVE.B  (A0,D0.W),(A5)+

* Source FP reg
         MOVE.W  D6,D0
         LSR.W   #7,D0
         ANDI.W  #7,D0
         MOVE.B  #'F',(A6)+
         MOVE.B  #'P',(A6)+
         ORI.B   #'0',D0
         MOVE.B  D0,(A6)+

         MOVE.B  #',',(A6)+

* Destination EA
         ADDQ.L  #2,D3           D3 = 4
         MOVE.W  #$1FD,D7
         BSR     EEA
         BRA     COMMON

*------------------------------------------------------------------------

TBLE     DS      0

N68      MACRO
         DC.B    '\1',128+'\2'        \1\2
         ENDM

OPCTBL   DS      0
         N68     MOVE,P    0
         N68     O,R       1
         N68     AN,D      2
         N68     SU,B      3
         N68     AD,D      4
         N68     EO,R      5
         N68     CM,P      6
         N68     MOV,E     7
         N68     NEG,X     8
         N68     CL,R      9
         N68     NE,G      10
         N68     NO,T      11
         N68     NBC,D     12
         N68     PEA.,L    13
         N68     SWAP.,W   14
         N68     MOVE,M    15
         N68     EXT.,W    16
         N68     EXT.,L    17
         N68     TS,T      18
         N68     TAS.,B    19
         N68     TRA,P     20
         N68     LIN,K     21
         N68     UNL,K     22
         N68     RESE,T    23
         N68     NO,P      24
         N68     STO,P     25
         N68     RT,E      26
         N68     RT,S      27
         N68     TRAP,V    28
         N68     RT,R      29
         N68     JS,R      30
         N68     JM,P      31
         N68     CHK.,W    32
         N68     LEA.,L    33
         N68     ADD,Q     34
         N68     SUB,Q     35
         DC.B    128+'S'   36
         N68     D,B       37
         DC.B    128+'B'   38
         N68     MOVEQ.,L  .....39
         N68     O,R       40
         N68     DIVU.,W   41
         N68     DIVS.,W   42
         N68     SBC,D     43
         N68     SU,B      44
         N68     SUB,X     45
         N68     CMP,M     46
         N68     MULU.,W   47
         N68     MULS.,W   48
         N68     ABC,D    49
         N68     EX,G      50
         N68     BS,R      .....51
         N68     NUL,L     .....52
         N68     ADD,X     53
         N68     A,S       54
         N68     L,S       55
         N68     R,O       56
         N68     RO,X      57
         N68     MOVE.,B   58
         N68     MOVE.,W   59
         N68     MOVE.,L   60
         N68     BTS,T     61
         N68     BCH,G     62
         N68     BCL,R     63
         N68     BSE,T     64
         N68     BR,A      65
         N68     FMOV,E    66
         N68     FAD,D     67
         N68     FSU,B     68
         N68     FMU,L     69
         N68     FDI,V     70
         N68     FNE,G     71
         N68     FAB,S     72
         N68     FSQR,T    73
         N68     FCM,P     74
         N68     FTS,T     75
         N68     FSI,N     76
         N68     FCO,S     77
         N68     FTA,N     78
         N68     FATA,N    79
         N68     FASI,N    80
         N68     FACO,S    81
         N68     FSIN,H    82
         N68     FCOS,H    83
         N68     FTAN,H    84
         N68     FATAN,H   85
         N68     FETO,X    86
         N68     FETOXM,1  87
         N68     FTWOTO,X  88
         N68     FTENTO,X  89
         N68     FLOG,N    90
         N68     FLOGNP,1  91
         N68     FLOG1,0   92
         N68     FLOG,2    93
         N68     FIN,T     94
         N68     FINTR,Z   95
         N68     FGETEX,P  96
         N68     FGETMA,N  97
         N68     FMO,D     98
         N68     FRE,M     99
         N68     FSCAL,E   100
         N68     FSGLDI,V  101
         N68     FSGLMU,L  102
         N68     FSINCO,S  103
         N68     FMOVEC,R  104


ADR      MACRO
         DC.W    M\1-XBASE
         ENDM

TBLKEYS  DS     0              INDEX
         ADR    ABCD            0  ABCD SBCD
         ADR    ADD             1  ADD  SUB
         ADR    ADDA            2  ADDA CMPA SUBA
         ADR    ADDI            3  ADDI CMPI SUBI
         ADR    ADDQ            4  ADDQ SUBQ
         ADR    ADDX            5  ADDX SUBX
         ADR    AND             6  AND  EOR OR
         ADR    ASL             7  ASL  LSL ROL ROXL
         ADR    DBCC            8  DBCC
         ADR    BCHG            9  BCHG
         ADR    BRA            10  BRA  BSR  BCC
         ADR    BSET           11  BSET
         ADR    CHK            12  CHK  DIVS DIVU MILS MULU
         ADR    CLR            13  CLR NEG NEGX NOT TST
         ADR    CMPM           14  CMPM
         ADR    MOVEQ          15  MOVEQ
         ADR    EXG            16  EXG
         ADR    EXT            17  EXT
         ADR    JMP            18  JMP  JSR
         ADR    LEA            19  LEA
         ADR    LINK           20  LINK
         ADR    MOVE           21  MOVE
         ADR    CMMD2          22  NOP RESET RTE RTR RTS TRAPV
         ADR    STOP           23  STOP
         ADR    SWAP           24  SWAP
         ADR    TRAP           25  TRAP
         ADR    UNLK           26  UNLK
         ADR    MOVEM          27  MOVEM
         ADR    ANDI           28  ANDI EORI ORI
         ADR    SCC            29  NBCD SCC TAS
         ADR    BCLR           30  BCLR
         ADR    BTST           31  BTST
         ADR    MOVEA          32  MOVEA
         ADR    MOVEP          33  MOVEP
         ADR    CMP            34  CMP
         ADR    EOR            35  EOR
         ADR    PEA            36  PEA
         ADR    DC             37  DC.W
         ADR    FPU            38  FPU instructions
         ADR    FBCC           39  FBcc branches



         DC.B    0              PAD BYTE

*****************************************************************************************************
* MESSAGES SECTION		

OKMSG		DC.B	'MC68901 Multifunction Peripheral Initialized',CR,LF,LF,0		*****

msgBanner	DC.B	'================================================================================',CR,LF
			DC.B	' 888b     d888                  888 d8b            .d8888b.',CR,LF
			DC.B	' 8888b   d8888                  888 Y8P           d88P  Y88b',CR,LF
			DC.B	' 88888b.d88888                  888               888    888',CR,LF
			DC.B	' 888Y88888P888  .d88b.  888d888 888 888 88888b.        d88P',CR,LF
			DC.B	' 888 Y888P 888 d8P  Y8b 888P"   888 888 888 "88b   .od888P"',CR,LF
			DC.B	' 888  Y8P  888 88888888 888     888 888 888  888  d88P"',CR,LF
			DC.B	' 888   "   888 Y8b.     888     888 888 888  888 888"',CR,LF
			DC.B	' 888       888  "Y8888  888     888 888 888  888 888888888',CR,LF
			DC.B	'                                                  FPU',CR,LF
			DC.B	'================================================================================',CR,LF
			DC.B	'ver 2.1 build 001  MATT PEARCE 2024-2026  |  MC68000 + MC68881 FPGA',CR,LF,0

msgPrompt	DC.B	'>',0	

msgNoCMD	DC.B	'Invalid Command',CR,LF,0
msgBadAddr	DC.B	'Invalid Address',CR,LF,0
msgBadVal	DC.B	'Invalid Value',CR,LF,0
msgNewline	DC.B	CR,LF,0
msgColonSpc	DC.B	': ',0

msgDepPrompt	DC.B	': ',0

msgHelp		DC.B	'Available Commands: ',CR,LF
			DC.B	'[A]ssemble [B]reakpoint [D]eposit [E]xamine [G]o [H]elp',CR,LF
			DC.B	'[L]oad SREC [N]o-break [R]egs [T]race',CR,LF
			DC.B	'B addr[;cnt]  Set breakpoint (cnt=pass count)',CR,LF
			DC.B	'B             List breakpoints',CR,LF
			DC.B	'N [addr]      Clear one/all breakpoints',CR,LF
			DC.B	'T [count]     Trace (single-step) instructions',CR,LF,0

msgFault	DC.B	'FAULT AT $',0
msgBreak	DC.B	'Break at $',0
msgIllegal	DC.B	'Illegal instruction at $',0
msgBPfull	DC.B	'Breakpoint table full',CR,LF,0
msgBPcnt	DC.B	';',0

ERMES1		DC.B	'Non-valid hexadecimal input  ',CR,LF,0
ERMES2		DC.B	'Invalid command  ',CR,LF,0	
ERMES3		DC.B	'Loading error',CR,LF,0	
ERMES4		DC.B	'Table full  ',CR,LF,0	
ERMES5		DC.B	'Breakpoint not active   ',CR,LF,0	
ERMES6		DC.B	'Uninitialized exception ',CR,LF,0	
ERMES7		DC.B	' Range error',CR,LF,0

msgNoRegs	DC.B	'No saved registers — run a program with G first',CR,LF,0
msgPC		DC.B	'  PC=',0
msgSR		DC.B	' SR=',0
msgSP		DC.B	'  SP=',0
msgFPpfx	DC.B	' FP',0
msgEq		DC.B	'=',0


TBLOPC   OPC     ABC,D,0,C1,00,0,0     ABCD
         OPC     ADD,A,2,D0,C0,0,0     ADDA
         OPC     ADD,I,3,06,00,0,0     ADDI
         OPC     ADD,Q,4,50,00,0,0     ADDQ
         OPC     ADD,X,5,D1,00,0,0     ADDX
         OPC     AD,D,1,D0,00,0,0      ADD
         OPC     AND,I,28,02,00,0,0    ANDI
         OPC     AN,D,6,C0,00,0,0      AND
         OPC     AS,L,7,E1,00,0,0      ASL
         OPC     AS,R,07,E0,00,0,0     ASR
         OPC     BR,A,10,60,00,0,NW    BRA
         OPC     BH,I,10,62,00,0,NW    BHI
         OPC     BL,S,10,63,00,0,NW    BLS
         OPC     BC,C,10,64,00,0,NW    BCC
         OPC     BC,S,10,65,00,0,NW    BCS
         OPC     BN,E,10,66,00,0,NW    BNE
         OPC     BE,Q,10,67,00,0,NW    BEQ
         OPC     BV,C,10,68,00,0,NW    BVC
         OPC     BV,S,10,69,00,0,NW    BVS
         OPC     BP,L,10,6A,00,0,NW    BPL
         OPC     BM,I,10,6B,00,0,NW    BMI
         OPC     BG,E,10,6C,00,0,NW    BGE
         OPC     BL,T,10,6D,00,0,NW    BLT
         OPC     BG,T,10,6E,00,0,NW    BGT
         OPC     BL,E,10,6F,00,0,NW    BLE
         OPC     BCH,G,9,01,40,0,0     BCHG
         OPC     BCL,R,30,01,80,0,0    BCLR      DYNAMIC
         OPC     BSE,T,11,01,C0,0,0    BSET
         OPC     BS,R,10,61,00,0,NW    BSR
         OPC     BTS,T,31,01,00,0,0    BTST
         OPC     B,T,10,60,00,0,NW     BT
         OPC     CH,K,12,41,80,0,0     CHK
         OPC     CL,R,13,42,00,0,0     CLR
         OPC     CMP,A,2,B0,C0,0,0     CMPA
         OPC     CMP,I,3,0C,00,0,0     CMPI
         OPC     CMP,M,14,B1,08,0,0    CMPM
         OPC     CM,P,34,B0,00,0,0     CMP
         OPC     DB,T,8,50,C8,0,NW     DBT
         OPC     DB,F,8,51,C8,0,NW     DBF
         OPC     DBR,A,8,51,C8,0,NW    DBRA
         OPC     DBH,I,8,52,C8,0,NW    DBHI
         OPC     DBL,S,8,53,C8,0,NW    DBLS
         OPC     DBC,C,8,54,C8,0,NW    DBCC
         OPC     DBC,S,8,55,C8,0,NW    DBCS
         OPC     DBN,E,8,56,C8,0,NW    DBNE
         OPC     DBE,Q,8,57,C8,0,NW    DBEQ
         OPC     DBV,C,8,58,C8,0,NW    DBVC
         OPC     DBV,S,8,59,C8,0,NW    DBVS
         OPC     DBP,L,8,5A,C8,0,NW    DBPL
         OPC     DBM,I,8,5B,C8,0,NW    DBMI
         OPC     DBG,E,8,5C,C8,0,NW    DBGE
         OPC     DBL,T,8,5D,C8,0,NW    DBLT
         OPC     DBG,T,8,5E,C8,0,NW    DBGT
         OPC     DBL,E,8,5F,C8,0,NW    DBLE
         OPC     DC.,W,37,00,00,0,0    DC.W  (WORD ONLY)
         OPC     DIV,S,12,81,C0,0,0    DIVS
         OPC     DIV,U,12,80,C0,0,0    DIVU
         OPC     EOR,I,28,0A,00,0,0    EORI
         OPC     EO,R,35,B1,00,0,0     EOR
         OPC     EX,G,16,C1,00,0,0     EXG
         OPC     EX,T,17,48,00,0,0     EXT
         OPC     JM,P,18,4E,C0,0,NW    JMP
         OPC     JS,R,18,4E,80,0,NW    JSR
         OPC     LE,A,19,41,C0,0,0     LEA
         OPC     LIN,K,20,4E,50,0,0    LINK
         OPC     LS,L,7,E3,08,0,0      LSL
         OPC     LS,R,07,E2,08,0,0     LSR
         OPC     MOVE,A,32,00,04,0,0   MOVEA
         OPC     MOVE,M,27,48,80,0,0   MOVEM
         OPC     MOVE,P,33,01,08,0,0   MOVEP
         OPC     MOVE,Q,15,70,00,0,0   MOVEQ
         OPC     MOV,E,21,00,00,0,0    MOVE
         OPC     MUL,S,12,C1,C0,0,0    MULS
         OPC     MUL,U,12,C0,C0,0,0    MULU
         OPC     NBC,D,29,48,0,0,0     NBCD
         OPC     NEG,X,13,40,00,0,0    NEGX
         OPC     NE,G,13,44,00,0,0     NEG
         OPC     NO,P,22,4E,71,NOC,0   NOP
         OPC     NO,T,13,46,00,0,0     NOT
         OPC     OR,I,28,00,00,0,0     ORI
         OPC     O,R,6,80,00,0,0       OR
         OPC     PE,A,36,48,40,0,0     PEA
         OPC     RESE,T,22,4E,70,NOC,0 RESET
         OPC     RO,L,7,E7,18,0,0      ROL
         OPC     RO,R,07,E6,18,0,0     ROR
         OPC     ROX,L,7,E5,10,0,0     ROXL
         OPC     ROX,R,07,E4,10,0,0    ROXR
         OPC     RT,E,22,4E,73,NOC,0   RTE
         OPC     RT,R,22,4E,77,NOC,0   RTR
         OPC     RT,S,22,4E,75,NOC,0   RTS
         OPC     SBC,D,0,81,00,0,0     SBCD
         OPC     S,F,29,51,C0,0,0      SF
         OPC     SH,I,29,52,C0,0,0     SHI
         OPC     SL,S,29,53,C0,0,0     SLS
         OPC     SC,C,29,54,C0,0,0     SCC
         OPC     SC,S,29,55,C0,0,0     SCS
         OPC     SN,E,29,56,C0,0,0     SNE
         OPC     SE,Q,29,57,C0,0,0     SEQ
         OPC     SV,C,29,58,C0,0,0     SVC
         OPC     SV,S,29,59,C0,0,0     SVS
         OPC     SP,L,29,5A,C0,0,0     SPL
         OPC     SM,I,29,5B,C0,0,0     SMI
         OPC     SG,E,29,5C,C0,0,0     SGE
         OPC     SL,T,29,5D,C0,0,0     SLT
         OPC     SG,T,29,5E,C0,0,0     SGT
         OPC     SL,E,29,5F,C0,0,0     SLE
         OPC     STO,P,23,4E,72,0,0    STOP
         OPC     S,T,29,50,C0,0,0      ST
         OPC     SUB,A,2,90,C0,0,0     SUBA
         OPC     SUB,I,3,04,00,0,0     SUBI
         OPC     SUB,Q,4,51,00,0,0     SUBQ
         OPC     SUB,X,5,91,00,0,0     SUBX
         OPC     SU,B,1,90,00,0,0      SUB
         OPC     SWA,P,24,48,40,0,0    SWAP
         OPC     TA,S,29,4A,C0,0,0     TAS
         OPC     TRAP,V,22,4E,76,NOC,0 TRAPV
         OPC     TRA,P,25,4E,40,0,0    TRAP
         OPC     TS,T,13,4A,00,0,0     TST
         OPC     UNL,K,26,4E,58,0,0    UNLK

* FPU instructions — TBLKEYS index 38
* First word mask = $00,opcode (FP opcode in low byte for MFPU handler)
         OPC     FMOVEC,R,38,00,FF,0,0   FMOVECR (special, $FF marker)
         OPC     FMOV,E,38,00,00,0,0     FMOVE
         OPC     FAD,D,38,00,22,0,0      FADD
         OPC     FSU,B,38,00,28,0,0      FSUB
         OPC     FMU,L,38,00,23,0,0      FMUL
         OPC     FDI,V,38,00,20,0,0      FDIV
         OPC     FSQR,T,38,00,04,0,0     FSQRT
         OPC     FAB,S,38,00,18,0,0      FABS
         OPC     FNE,G,38,00,1A,0,0      FNEG
         OPC     FCM,P,38,00,38,0,0      FCMP
         OPC     FTS,T,38,00,3A,0,0      FTST
         OPC     FSINCO,S,38,00,30,0,0   FSINCOS
         OPC     FSI,N,38,00,0E,0,0      FSIN
         OPC     FCO,S,38,00,1D,0,0      FCOS
         OPC     FTA,N,38,00,0F,0,0      FTAN
         OPC     FASI,N,38,00,0C,0,0     FASIN
         OPC     FACO,S,38,00,1C,0,0     FACOS
         OPC     FATA,N,38,00,0A,0,0     FATAN
         OPC     FSIN,H,38,00,02,0,0     FSINH
         OPC     FCOS,H,38,00,19,0,0     FCOSH
         OPC     FTAN,H,38,00,09,0,0     FTANH
         OPC     FATAN,H,38,00,0D,0,0    FATANH
         OPC     FETO,X,38,00,10,0,0     FETOX
         OPC     FETOXM,1,38,00,08,0,0   FETOXM1
         OPC     FTWOTO,X,38,00,11,0,0   FTWOTOX
         OPC     FTENTO,X,38,00,12,0,0   FTENTOX
         OPC     FLOG,N,38,00,14,0,0     FLOGN
         OPC     FLOGNP,1,38,00,06,0,0   FLOGNP1
         OPC     FLOG1,0,38,00,15,0,0    FLOG10
         OPC     FLOG,2,38,00,16,0,0     FLOG2
         OPC     FIN,T,38,00,01,0,0      FINT
         OPC     FINTR,Z,38,00,03,0,0    FINTRZ
         OPC     FGETEX,P,38,00,1E,0,0   FGETEXP
         OPC     FGETMA,N,38,00,1F,0,0   FGETMAN
         OPC     FMO,D,38,00,21,0,0      FMOD
         OPC     FRE,M,38,00,25,0,0      FREM
         OPC     FSCAL,E,38,00,26,0,0    FSCALE
         OPC     FSGLDI,V,38,00,24,0,0   FSGLDIV
         OPC     FSGLMU,L,38,00,27,0,0   FSGLMUL
* FBcc branch instructions — TBLKEYS index 39
* Longer mnemonics must precede shorter prefixes (FBGLE before FBGL, etc.)
         OPC     FB,F,39,00,00,0,0       FBF
         OPC     FBE,Q,39,00,01,0,0      FBEQ
         OPC     FBOG,T,39,00,02,0,0     FBOGT
         OPC     FBOG,E,39,00,03,0,0     FBOGE
         OPC     FBOL,T,39,00,04,0,0     FBOLT
         OPC     FBOL,E,39,00,05,0,0     FBOLE
         OPC     FBOG,L,39,00,06,0,0     FBOGL
         OPC     FBO,R,39,00,07,0,0      FBOR
         OPC     FBUE,Q,39,00,09,0,0     FBUEQ
         OPC     FBUG,T,39,00,0A,0,0     FBUGT
         OPC     FBUG,E,39,00,0B,0,0     FBUGE
         OPC     FBUL,T,39,00,0C,0,0     FBULT
         OPC     FBUL,E,39,00,0D,0,0     FBULE
         OPC     FBU,N,39,00,08,0,0      FBUN
         OPC     FBN,E,39,00,0E,0,0      FBNE
         OPC     FB,T,39,00,0F,0,0       FBT
         OPC     FBSE,Q,39,00,11,0,0     FBSEQ
         OPC     FBSN,E,39,00,1E,0,0     FBSNE
         OPC     FBS,F,39,00,10,0,0      FBSF
         OPC     FBS,T,39,00,1F,0,0      FBST
         OPC     FBGL,E,39,00,17,0,0     FBGLE  (before FBGL)
         OPC     FBG,L,39,00,16,0,0      FBGL
         OPC     FBG,T,39,00,12,0,0      FBGT
         OPC     FBG,E,39,00,13,0,0      FBGE
         OPC     FBNGL,E,39,00,18,0,0    FBNGLE (before FBNGL)
         OPC     FBNG,L,39,00,19,0,0     FBNGL
         OPC     FBNL,E,39,00,1A,0,0     FBNLE
         OPC     FBNL,T,39,00,1B,0,0     FBNLT
         OPC     FBNG,E,39,00,1C,0,0     FBNGE
         OPC     FBNG,T,39,00,1D,0,0     FBNGT
         OPC     FBL,T,39,00,14,0,0      FBLT
         OPC     FBL,E,39,00,15,0,0      FBLE

         DC.B    0              PAD BYTE

TBLOPCE  DS      0


		END	START	
