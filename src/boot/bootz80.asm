;
; BOOTZ80
; Bootstrapper program to load CP/M after BOOT65/BIOS65
; initialize the Z80 processor.
;
; Copyright (c) 2024 Stefanos Stefanidis, <www.fe32gr23@gmail.com>
;
; Use z80asm to build this code. Note that this program
; uses Intel 8080 instructions, but z80asm will convert these
; to native Z80 instructions.
;

;
; The program is loaded from the SD card by BIOS65, located inside BOOT65.
; The load address is 0000h (by the Z80's perspective). BIOS65 disables
; the 65C02, activates the Z80, loads BOOTZ80, and executes it.
;

CCP	EQU 3400H
NSECTS	EQU 1CH
TRACK	EQU 0F903H
SECTOR	EQU 0F902H
DISKNO	EQU 0F904H
IOTYPE	EQU 0FCFFH      ;I/O setup byte in BIOS65
KYBDMD	EQU CCP+1633H   ;caps lock flag
VICRD	EQU 0
CMD	EQU 0F900H
OFF	EQU 01H
MODESW	EQU 0CE00H
DATA	EQU 0F901H
BUFFER	EQU 0F800H
BOOT	EQU CCP+1600H

	org 0000h           ;Z80 reset location

;
; BOOTZ80 entry point.
;
START:
	NOP                 ;NOP required for hardware
	LXI D, CCP          ;start of load address
	MVI A, 0
	STA DISKNO          ;load in from drive A (device #8)
	MVI H, 1            ;read track 1, sector 6 for BIOSZ80
	MVI L, 6

LOAD1:
	MOV A, H
	STA TRACK
	MOV A, L
	STA SECTOR
	MVI A, VICRD        ;sector read command
	STA CMD
	MVI A, OFF
	STA MODESW          ;turn off self
	NOP
	LDA DATA            ;was transfer OK?
	ORA A
	JNZ LOAD1           ;jump if no
;
; output '*' to show loading
;
	MVI A, '*'
	STA DATA
	MVI A, 3
	STA CMD
	MVI A, OFF
	STA MODESW
	NOP
;
; move sector to memory
;
	LXI B, BUFFER

LOAD2:
	LDAX B
	STAX D
	INR C
	INR E
	JNZ LOAD2
;
; update pointers
;
	INR D
	INR L
	MOV A, L
;
; check for end of track
;
	CPI 17
	JC LOAD3
	INR H
	MVI L, 0

LOAD3:
	CPI 3
	JNZ LOAD1
	LDA IOTYPE          ;poke upper/lower case
	ANI 20h
	JNZ LOAD4
	MVI A, 1
	STA KYBDMD

;go to boot portion of bios
LOAD4:
	JMP BOOT
