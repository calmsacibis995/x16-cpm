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
I2C_WRITE_BYTE = $FEC9  ;write to I2C interface.

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
; BOOT65 startup message.
;
SIGNON:
	!PET "boot65 vsn 1.0 - 4 oct 2024 (commander x16)",13,0

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
	LDA #$FF        ;set up Z80 command register (BIOS65 uses it)
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
	LDA #0          ;turn Z80 back on
	STA MODESW
	NOP             ;delay only
	JSR EXZ80CMD    ;execute Z80 command if any
	JMP BIOS65      ;and loop

EXZ80CMD:
	LDA CMD         ;get saved command
	CMP #$FF        ;see if Z80 active
	BNE TRYEXEC     ;if so try to execute
	JMP RESETX16    ;else RESET the X16

;This routine performs a hard reset of the X16.
RESETX16:
	LDA #$01        ;value
	LDX #$42        ;I2C device (SMC)
	LDY #$01        ;register
	JSR I2C_WRITE_BYTE
	BCS RSTERR      ;the X16 should instantly reboot
RSTERR:	RTS             ;we shouldn't get here

TRYEXEC:
	CMP #10         ;see if 0 to 9
	BCC ADDCMD      ;it is so execute else ignore
	RTS

ADDCMD:
	CLD             ;clear decimal flag
	CLC             ;and then carry
	ADC CMD         ;A was CMD so A now = 2 x CMD
	ADC #<VECTAB    ;add low byte of table
	STA JMPVEC+1    ;modify jump vector
JMPVEC:	JMP (VECTAB)    ;then go execute
VECTAB:	!WORD SECRD     ;0 = sector read
	!WORD SECWR     ;1 = sector write
	!WORD KEYSC     ;2 = keyboard scan
	!WORD OUTSC     ;3 = output to screen
	!WORD PRNST     ;4 = get printer status
	!WORD OUTPR     ;5 = output to printer
	!WORD FORMAT    ;6 = format diskette
	!WORD $0E00     ;7 = jump to addr at $0E00
	!WORD $0F00     ;8 = jump to addr at $0F00
	!WORD Z80JMP    ;9 = jump ($0906)
Z80JMP:	JMP ($0906)     ;indirect jump set by Z80

;function 0 - read sector
SECRD:
	LDA #'1'        ;"1" in "U1"
	JSR SETUSER     ;set up USER 1 mode
	JSR RDCH2       ;set up read from LA 2
	LDX #0          ;do full 256 bytes
SECRD1:	JSR BASIN       ;input from channel
	STA HSTBUF,X    ;& put in host buffer
	INX             ;go to next
	BNE SECRD1      ;loop if more
	BEQ RSTDEFCH    ;exit by restoring default channel
SECRD2:	JSR INITDSK     ;initialize diskette

;function 1 - write sector
SECWR:
	JSR WRCMDCH     ;set up to write to command channel
	LDY #8          ;8 characters
SECWR1:	LDA BLKCMD,X    ;send block command
	JSR BSOUT       ;output to channel
	INX
	DEY
	BNE SECWR1
	JSR CLRCH       ;restore default channel
	JSR INCMDCH     ;read command results
	BNE SECRD2      ;error so initialize
	JSR CLRCH       ;restore default channel
	JSR WRCH2       ;set up write to channel 2
	LDX #0
SECWR2:	LDA HSTBUF,X    ;get byte from buffer
	JSR BSOUT       ;output to channel
	INX
	BNE SECWR2      ;loop until all 256 written
	JSR CLRCH       ;restore default channel
	LDA #'2'        ;"2" in "U2", block write
	BNE SETUSER     ;go do block write

;function 2 - keyboard scan
KEYSC:
	JSR KEY         ;scan keyboard
	LDA LSTX        ;get current key pressed
	STA KYCHAR      ;save in register
	RTS

;function 3 - output to screen
OUTSC:
	LDA #0         ;set editor to
	STA QTSW       ;not in quote mode
	LDA DATA       ;get character
	JMP CHAROUT    ;output to channel

;function 4 - get printer status
PRNST:
	LDA #0         ;always
	STA DATA       ;OK

;function 5 - send character to printer
OUTPR:
	LDA DATA       ;get character
	CMP #10        ;see if line feed

USER_TXT_STR:
	!PET "U1:2 0 TT SS",13
