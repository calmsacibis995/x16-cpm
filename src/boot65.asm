;
; BOOT65 (Commander X16 version)
; Copyright (c) 2024 Stefanos Stefanidis, <www.fe32gr23@gmail.com>
;
; Use the ACME cross-compiler for this code.
;

!to "BOOT65.PRG",cbm
!cpu 65c02

*=$0801                 ;START ADDRESS IS $0801

CIOUT = $FFA8
LISTEN = $FFB1
SECOND = $FF93
OPEN = $FFC0
SETLFS = $FFBA
SETNAM = $FFBD
CLALL = $FFE7
CHAROUT = $FFD2         ;kernal call for output character
SCREEN_MODE = $FF5F     ;set screen mode

; Variables for BOOT65, BIOS65
CMD = $2400
KYCHAR = $2405

;
; This label must always be first! It contains the BASIC stub
; used to load this program.
;
BASIC:
	; BASIC line: "1 SYS 2061"
	!BYTE $0B,$08,$01,$00,$9E,$32,$30,$36,$31,$00,$00,$00
	JMP START

;
; We don't have a Z80 processor board installed!
; User message.
;
NO_Z80_TEXT:
	!PET "no z80 cpuboard detected!",13
	!PET "please power off your system,",13
	!PET "insert the z80 cpuboard, power on",13
	!PET "the x16, then run this program again.",13,0

;
; CP/M startup message.
;
SIGNON:
	!PET "booting...",13,0

BASIC_EXIT_TEXT:
	!PET "cp/m boot process ended prematurely - exiting to basic",0

RND_FNAME:
	!PET "#"

START:
	LDA $9F60       ;probe for Z80 processor board
	CMP #$01        ;placeholder comparison
	BNE NO_Z80      ;no Z80 processor board found, complain.
	JSR LOAD_MSG    ;print boot message
	LDA #1          ;use screen mode #1
	STA SCREEN_MODE ;configure it

INITX16:
	SEI             ;disable interrupts
	JSR CLALL       ;close all files & channels
	LDA #15         ;logical file number 15
	LDX #8          ;device 8
	LDY #15         ;secondary address 15
	JSR SETLFS      ;set LA, FA, SA
	LDA #0          ;zero length file name
	JSR SETNAM      ;set length & file name address
	JSR OPEN        ;open logical file
	LDA #2          ;logical file number 2
	LDX #8          ;device 8
	LDY #2          ;secondary address 2
	JSR SETLFS      ;set LA, FA, SA
	LDA #1          ;name is one char long
	LDX #<RND_FNAME ;Filename "#"
	LDY #>RND_FNAME
	JSR SETNAM      ;set length & file name address
	JSR OPEN        ;open logical file

FINAL_BOOT:
	LDA #16         ;Switch to ROM bank 16 to disable BASIC, Character ROM.
	STA $0001       ;$0001 is where the current ROM bank number.
	LDA #9          ;enable char set change
	JSR CHAROUT     ;output to channel
	LDA #14         ;switch to upper/lower case
	JSR CHAROUT     ;output to channel
	LDA #8          ;disable char set change
	JSR CHAROUT     ;output to channel
	LDA #147        ;clear & home
	JSR CHAROUT     ;output to channel
	LDA #13         ;return & do line feed
	JSR CHAROUT     ;output to channel
	LDA #$FF        ;set up Z80 command register command (BIOS65 uses it)
	STA CMD
	LDA #$28        ;set up key code
	STA KYCHAR
	JMP BIOS65      ;jump to BIOS65

;This routine displays the starting message with
;version number.
LOAD_MSG:
	LDX #0
LMT0:	LDA SIGNON,X
	CMP #0
	BNE LMT1
	RTS
LMT1:	JSR CHAROUT
	INX
	JMP LMT0

;This routine displays the error message when
;the Z80 processor board is not installed.
NO_Z80:
	LDX #0
NZ801:	LDA NO_Z80_TEXT,X
	CMP #0
	BNE NZ802
	JSR EXIT_TO_BASIC
	RTS
NZ802:	JSR CHAROUT
	INX
	JMP NZ801

EXIT_TO_BASIC:
	LDX #0
EX1:	LDA BASIC_EXIT_TEXT,X
	CMP #0
	BNE EX2
	RTS
EX2:	JSR CHAROUT
	INX
	JMP EX1

;
; This is the CP/M BIOS for the X16.
; Called from START after initialization.
;
BIOS65:

