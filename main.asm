;=======================================================================================================
;
; Gran Turismo 7 Supersport Deluxe Main Code
;
;	Yacine Tchabi & Maxime Denoncin
;
;=======================================================================================================

;########################################################################################################
; IMPORTANT NOTICE: Those are the timers that are critical (i.e. should be avoided to use or
; compatibility with the rest of the code should be checked):
;
;	- R17 : used to check state for the clock signal for screen refresh => may normally be used outside of interrupts but avoid if possible
;
;
;
; PORTS IN USE:
;
;	- PB0: Main Switch
;	- PC2,3 Led
;	- PD2,3,6,7: Keyboard
;	- PB3: Screen DATA
;	- PB4: Screen LATCH
;	- PB5: Screen CLK
;
;########################################################################################################


; PREAMBLE
.include "m328pdef.inc"

; CONSTANTS

.EQU T0OVERFLOW = 0x01		; We want T0 to overflow at 100 Hz (with a 1024 prescaler) => 256-(16e6/1024)/100 ~ 100 => 0x64

.EQU T1OVERFLOWL = 0xD4
.EQU T1OVERFLOWH = 0xF5

.EQU T2OVERFLOW = 0xEE

; BOOT CODE

.ORG 0x0000
RJMP init

.ORG 0x001A
RJMP timer1ISR

.ORG 0x0020
RJMP timer0ISR



; INITIALIZATIONS

init:
	; MAIN SWITCH (PB0)
	CBI DDRB,0 ; Input
	SBI PORTB,0 ; Set pull-up resistor

	; LEDs (PC2,PC3)
	SBI DDRC,2	; Output
	SBI PORTC,2	; HIGH => Led off
	SBI DDRC,3
	SBI PORTC,3

	; Joystick
	CBI DDRB,2
	SBI PORTB,2

	; KEYBOARD
	SBI DDRD,7	; Row1 is an output
	SBI PORTD,7	; Row Deactivated
	SBI DDRD,6
	SBI PORTD,6
	CBI DDRD,2
	SBI	PORTD,2
	CBI DDRD,3
	SBI PORTD,3

	; BUZZER
	SBI DDRB,1
	CBI PORTB,1

	; SCREEN
	SBI DDRB,3	; DATA (PB3)
	CBI PORTB,3
	SBI DDRB,4	; LATCH ACT (PB4)
	CBI PORTB,4
	SBI DDRB,5	; CLOCK (PB5)
	CBI PORTB,5
	
	; TIMER0 Configuration
	LDI R17,0x05
	OUT TCCR0B,R17			; 1024 Prescaler
	LDI R16,T0OVERFLOW			
	OUT TCNT0,R16
	LDI R19,0x01
	STS TIMSK0,R19			; Peripheral Interrupts Activated

	; TIMER1 Configuration
	LDI R17,0x05
	STS TCCR1B,R17			; 1024 Prescaler
	LDI R16,T1OVERFLOWL		
	STS TCNT1L,R16
	LDI R16,T1OVERFLOWH
	STS TCNT1H,R16
	LDI R19,0x01
	STS TIMSK1,R19			; Peripheral Interrupts Activated
	
	; TIMER2 Configuration
	LDI R17,0x05
	STS TCCR2B,R17			; 1024 Prescaler
	LDI R16,T2OVERFLOW
	STS TCNT2,R16
	LDI R19,0x00
	STS TIMSK2,R19			; Peripheral Interrupts NOT Activated


	; GLOBAL INTERRUPTS ACTIVATION
	LDI R20,0b10000000
	OUT SREG,R20			; Global Interrupt Activated

	RCALL clearRAMa
	RCALL clearRAMb
	NOP
	RJMP off


; STATE: OFF
; In this case, the µC loops on nothing, just check the main switch
; state and launch the main menu if switched on
off:
	SBI PORTC,2
	SBI PORTC,3
	RCALL checkOnOff
	BRTC off		; If T is set => still off
	RJMP loadScreen	; Else => main menu

; MENU

loadScreen:
	LDI R17,0x01
	RCALL writeGT7toRAM
	RJMP mainmenu

mainmenu:
	CBI PORTC,2				; Leds to visually check state
	SBI PORTC,3
	LDI R18,0x03            ;Number of life
	RCALL checkOnOff		; Verify Main Switch
	BRTC gotooff				; Off if switch switched
	RCALL checkSW1			; Check Button 1
	BRTC gameinit			; If pressed => Game
	RJMP mainmenu			; loop
	
gameinit:
	LDI R19,0x00
	RCALL clearRAMa
	RCALL clearRAMb
	SBI PORTC,2
	SBI PORTC,3
	RCALL mapInit
	RJMP game ;racestart
	
racestart:
	LDI R4,0x00
	LDI R12,0x01
	STS TIMSK2,R12			; Peripheral Interrupts Activated
	RCALL waitLong
	LDI R12,0x00
	STS TIMSK2,R12
	LDI R17,0x00		; R17 -> 0 - On shifte l'écran
	RJMP game
	
	

game:
	CBI PORTC,3				; Leds for visual check
	SBI PORTC,2
	CPI R19,0x00
	BRNE verificationGameOver
	RCALL checkklaxon
	RCALL checkOnOff		; Main Switch Check
	BRTC gotooff
	RCALL checkSW5			; B5 check => mainmenu
	BRTC quitgame
	RCALL checkSW2
	RCALL wait
	BRTC upCmd
	RCALL checkSW6
	RCALL wait
	BRTC dwnCmd
	RJMP game
	upCmd:
	RCALL moveCarUp
	RJMP game
	dwnCmd:
	RCALL moveCarDown
	RJMP game

verificationGameOver:
	DEC R18
	LDI R19,0X00
	CPI R18,0X00
	BRNE gameinit
	RJMP gotogameover



quitgame:
	LDI R17,0x01
	RCALL clearRAMa
	RCALL clearRAMb
	RCALL waitLong
	RCALL writeGT7toRAM
	RJMP mainmenu

gotooff:
	RCALL clearRAMa
	RCALL clearRAMb
	RJMP off

gotogameover:
	LDI R17,0x01
	RCALL writeGameOvertoRAM
	RJMP gameover

gameover:
	CBI PORTC,3
	CBI PORTC,2
	RCALL buzz
	RCALL checkOnOff
	BRTC gotooff
	RCALL checkSW1
	BRTC loadScreen
	RJMP gameover


	
;======================================= INTERRUPT SERVICE ROUTINES ====================================

timer0ISR:
	PUSH R16	; Save current R16 in the stack
	LDI R16,T0OVERFLOW ; We want 100 Hz => 256-(16e6/1024)/100 ~ 100 => 0x64
	OUT TCNT0,R16
	; DO NOT FORGET TO SAVE DATAS
	PUSH R20
	PUSH R21
	
	RCALL screenUpdateA
	RCALL screenUpdateB
	;RCALL shiftCircuit

	EOI:
		POP R21
		POP R20
		POP R16
		CLC
		RETI

timer1ISR:
	PUSH R16
	PUSH R17
	LDI R16,T1OVERFLOWL			
	STS TCNT1L,R16
	LDI R16,T1OVERFLOWH			
	STS TCNT1H,R16
	CPI R17,0X01
	BREQ EOI2
	RCALL shiftCircuit
	RCALL checkforGAMEOVER
	EOI2:
	POP R17
	POP R16
	RETI
	
timer2ISR:
	PUSH R16
	PUSH R17
	LDI R16,T2OVERFLOW			
	STS TCNT2,R16
	CPI R4,0x00
	BREQ buzzoff
	SBI PORTB,1
	RJMP EOI3
	buzzoff:
	CBI PORTB,1
	EOI3:
	POP R17
	POP R16
	RETI


;======================================= PERSONAL FUNCTIONS ============================================

checkOnOff:
	; Check the main switch and store in the T-Flag
	IN R0,PINB		; Copy Register to R0
	BST	R0,0		; Store PB0 state in T-flag
	RET

checkSW1:
	SBI PORTD,6
	CBI PORTD,7
	NOP
	IN R0,PIND
	BST R0,3
	RET

checkSW2:
	SBI PORTD,6
	CBI PORTD,7
	NOP
	IN R0,PIND
	BST R0,2
	RET

checkSW5:
	SBI PORTD,7
	CBI PORTD,6
	NOP
	IN R0,PIND
	BST R0,3
	RET

checkSW6:
	SBI PORTD,7
	CBI PORTD,6
	NOP
	IN R0,PIND
	BST R0,2
	RET

wait:
	PUSH R30
	PUSH R31
	LDI R30,0x05
	LDI R31,0x01
	a:
		DEC R31
		b:
			DEC R30
			CPI R30,0
			BRNE b
			LDI R30,0x05
		CPI R31,0
		BRNE a
	POP R31
	POP R30
	RET

waitLong:
	PUSH R30
	PUSH R31
	LDI R30,0xFF
	LDI R31,0xFF
	al:
		DEC R31
		bl:
			DEC R30
			CPI R30,0
			BRNE bl
			LDI R30,0xFF
		CPI R31,0
		BRNE al
	POP R31
	POP R30
	RET
	
waitOneSecond:
	PUSH R29
	PUSH R30
	PUSH R31
	LDI R29,0xFF
	LDI R30,0xFF
	LDI R31,0xFF
	a2:
		DEC R31
		b2:
			DEC R30
				c2:
				DEC R29
				CPI R29,0
				BRNE c2
				LDI R29,0xFF
			CPI R30,0
			BRNE b2
			LDI R30,0xFF
		CPI R31,0
		BRNE a2
	POP R31
	POP R30
	POP R29
	RET
	
waitNotSoLongButNotTooShort:
	PUSH R30
	PUSH R31
	LDI R30,0xFF
	LDI R31,0x02
	a3:
		DEC R31
		b3:
			DEC R30
			CPI R30,0
			BRNE b3
			LDI R30,0xFF
		CPI R31,0
		BRNE a3
	POP R31
	POP R30
	RET

screenUpdateA:
	PUSH R22
	PUSH R24
	PUSH R30
	PUSH R31
	LDI R22,0x01
	LDI ZL,0x50
	LDI ZH,0x01
	rowUpdate:
		LDI R24,0x0A	; 10 series of 8 bits per row
		send8bits:
			LD R20,-Z
			RCALL sendR20toRow
			DEC R24
			CPI R24,0
			BRNE send8bits
		sendwhichrow:
			MOV R20,R22
			RCALL sendR20toRow
			RCALL latchActivate
			CPI R22,0x80
			BREQ endofupdate
			CLC
			ROL R22
			RJMP rowUpdate
		endofupdate:
		POP R31
		POP R30
		POP R24
		POP R22
		RET

screenUpdateB:
	PUSH R22
	PUSH R24
	PUSH R30
	PUSH R31
	LDI R22,0x01
	LDI ZL,0xA0
	LDI ZH,0x01
	rowUpdateB:
		LDI R24,0x0A	; 10 series of 8 bits per row
		send8bitsB:
			LD R20,-Z
			RCALL sendR20toRow
			DEC R24
			CPI R24,0
			BRNE send8bitsB
		sendwhichrowB:
			MOV R20,R22
			RCALL sendR20toRow
			RCALL latchActivate
			CPI R22,0x80
			BREQ endofupdateB
			CLC
			ROL R22
			RJMP rowUpdateB
		endofupdateB:
		POP R31
		POP R30
		POP R24
		POP R22
		RET


		


sendR20toRow:
	PUSH R21
	LDI R21,0x08
	CLC
	ROLLOOP:
		CBI PORTB,3
		ROR R20
		BRCC carry0
		carry1:
			SBI PORTB,3
			RJMP next
		carry0:
			CBI PORTB,3
		next:
			RCALL risingEdge
			DEC R21
			CPI R21,0
			BRNE ROLLOOP
	POP R21
	RET


risingEdge:
	CBI PORTB,5
	SBI PORTB,5
	RET

latchActivate:
	CBI PORTB,4
	NOP ; WAIT HERE
	SBI PORTB,4
	RCALL waitNotSoLongButNotTooShort
	CBI PORTB,4
	RCALL waitNotSoLongButNotTooShort
	RET

writeGT7toRAM:
	PUSH R30
	PUSH R31
	PUSH R25
	LDI ZL,0x00
	LDI ZH,0x01
	LDI R25,0b01110111
	ST Z+,R25
	LDI R25,0b11011111
	ST Z+,R25
	LDI R25,0b11000000
	ST Z,R25

	LDI ZL,0x0A
	LDI ZH,0x01
	LDI R25,0b10000001
	ST Z+,R25
	LDI R25,0b00000011 
	ST Z+,R25
	LDI R25,0b11100000
	ST Z,R25

	LDI ZL,0x14
	LDI ZH,0x01
	LDI R25,0b10000001 
	ST Z+,R25
	LDI R25,0b00000101 
	ST Z+,R25
	LDI R25,0b10000000
	ST Z,R25

	LDI ZL,0x1E
	LDI ZH,0x01
	LDI R25,0b10110001 
	ST Z+,R25
	LDI R25,0b00001001 
	ST Z+,R25
	LDI R25,0b11110000
	ST Z,R25

	LDI ZL,0x28
	LDI ZH,0x01
	LDI R25,0b10001001 
	ST Z+,R25
	LDI R25,0b00010001 
	ST Z+,R25
	LDI R25,0b11000000
	ST Z,R25

	LDI ZL,0x32
	LDI ZH,0x01
	LDI R25,0b10001001 
	ST Z+,R25
	LDI R25,0b00010001 
	ST Z+,R25
	LDI R25,0b11100000
	ST Z,R25

	LDI ZL,0x3C
	LDI ZH,0x01
	LDI R25,0b01110001 
	ST Z+,R25
	LDI R25,0b00010001 
	ST Z+,R25
	LDI R25,0b11110000
	ST Z,R25

	POP R25
	POP R31
	POP R30
	RET


clearRAMa:
	PUSH R29
	LDI R29,0x00
	LDI ZL,0x00
	LDI ZH,0x01
	la:
		ST Z+,R29
		CPI ZL,0x50
		BRNE la
	POP R29
	RET

clearRAMb:
	PUSH R29
	LDI R29,0x00
	LDI ZL,0x50
	LDI ZH,0x01
	lb:
		ST Z+,R29
		CPI ZL,0xA0
		BRNE lb
	POP R29
	RET

mapInit:
	PUSH R25
	PUSH R30
	PUSH R31
	RCALL clearRAMa
	RCALL clearRAMb

	LDI ZL,0x78
	LDI ZH,0x01
	LDI R25,0b00010000 
	ST Z+,R25

	;RCALL generateUpObstacles
	;RCALL generateDownObstacles
	RCALL generateEnvironment

	POP R31
	POP R30
	POP R25

	RET

moveCarUp:
	RCALL waitLong
	RCALL waitLong
	RCALL waitLong
	RCALL waitLong
	PUSH R26
	PUSH R27
	PUSH R28
	PUSH R29
	LDI R26,14
	LDI ZL,0x50
	LDI ZH,0x01
	findCar:
		LD R27,Z
		CPI R27,0
		BRNE found
		ADIW Z,5
		RJMP findCar
	found:
		CPI ZL,0x50
		BREQ endofupmove
		CPI ZL,0x55
		BRNE moveupstd
		moveupswt:
			LDI R28,0
			ST Z,R28
			LDI ZL,0x8C
			LDI R29,0x10
			ST Z,R29
			RJMP endofupmove
		moveupstd:
			LDI R28,0
			ST Z,R28
			SBIW Z,10
			LDI R29,0b00010000
			ST Z,R29
		endofupmove:
		POP R29
		POP R28
		POP R27
		POP R26
		RET

moveCarDown:
	RCALL waitLong
	RCALL waitLong
	RCALL waitLong
	RCALL waitLong
	PUSH R26
	PUSH R27
	PUSH R28
	PUSH R29
	LDI R26,14
	LDI ZL,0x50
	LDI ZH,0x01
	findCar2:
		LD R27,Z
		CPI R27,0
		BRNE found2
		ADIW Z,5
		RJMP findCar2
	found2:
		CPI ZL,0x91
		BREQ endofdwnmove
		CPI ZL,0x8C
		BRNE movedwnstd
		movedwnswt:
			LDI R28,0
			ST Z,R28
			LDI ZL,0x55
			LDI R29,0x10
			ST Z,R29
			RJMP endofdwnmove
		movedwnstd:
			LDI R28,0
			ST Z,R28
			ADIW Z,10
			LDI R29,0b00010000
			ST Z,R29
		endofdwnmove:
		POP R29
		POP R28
		POP R27
		POP R26
		RET

generateUpObstacles:
	; Addresses 257->260 + 10 to 330
	PUSH R22
	PUSH R23
	PUSH R24
	LDI ZL,0x00
	LDI ZH,0x01
	LDI R23,0b11111111
	ST Z,R23
	LDI R22,0x02
	LDI R23,0b10000000
	LDI R24,0b00000010
	LDI ZL,0x01
	LDI ZH,0x01
	colpts:
		ST Z+,R23
		ST Z+,R24
		DEC R22
		CPI R22,0
		BRNE colpts
		SBIW Z,4
		ADIW Z,10
		CPI ZL,0x47
		BREQ eorow
		CLC
		ROR R23
		CLC
		ROL R24
		LDI R22,0x02
		RJMP colpts
	eorow:
		POP R24
		POP R23
		POP R22
		RET

generateDownObstacles:
	; Addresses 257->260 + 10 to 330
	PUSH R22
	PUSH R23
	PUSH R24
	LDI ZL,0x05
	LDI ZH,0x01
	LDI R23,0b11111111
	ST Z,R23
	LDI R22,0x02
	LDI R23,0b10000000
	LDI R24,0b00000010
	LDI ZL,0x06
	LDI ZH,0x01
	colpts2:
		ST Z+,R23
		ST Z+,R24
		DEC R22
		CPI R22,0
		BRNE colpts2
		SBIW Z,4
		ADIW Z,10
		CPI ZL,0x4C
		BREQ eorow2
		CLC
		ROR R23
		CLC
		ROL R24
		LDI R22,0x02
		RJMP colpts2
	eorow2:
		POP R24
		POP R23
		POP R22
		RET

shiftCircuit:
	PUSH R23
	PUSH R24
	PUSH R25
	PUSH R26
	PUSH R27
	LDI ZH,0x01
	LDI ZL,0x00
	line:
		LDI R27,0x00
		LDI R23,0x05
		byteshift:
			LD R24,Z
			CLC
			ROL R24
			BRCC nextbyte
			CPI R23,0x05
			BREQ enableFinalAdd
			SBIW Z,1
			LDI R25,1
			LD R26,Z
			ADD R26,R25
			ST Z+,R26
			RJMP nextbyte
			enableFinalAdd:
				LDI R27,0x01
			nextbyte:
				ST Z+,R24
				DEC R23
				CPI R23,0
				BRNE byteshift
				CPI R27,0x00
				BREQ nextline
				SBIW Z,1
				LD R23,Z
				ADD R23,R27
				ST Z+,R23
				nextline:
					CPI ZL,0x50
					BREQ endofshift
					RJMP line
					endofshift:
						POP R27
						POP R26
						POP R25
						POP R24
						POP R23
						RET


checkforGAMEOVER:
	PUSH R26
	PUSH R27
	PUSH R28
	LDI R26,14
	LDI ZL,0x50
	LDI ZH,0x01
	findCarGO:
		LD R27,Z
		CPI R27,0
		BRNE foundcarGO
		ADIW Z,5
		RJMP findCarGO
	foundcarGO:
		SBIW Z,20
		SBIW Z,20
		SBIW Z,20
		SBIW Z,20
		; ROL ROL ROL ROL + Branch if C-flag is set
		LD R28,Z
		CP R27,R28
		BRNE notDead
		LDI R19,0x01
		notDead:
			POP R28
			POP R27
			POP R26
			RET

generateEnvironment:
	PUSH R22
	PUSH R23
	PUSH R24
	LDI ZL,0x00
	LDI ZH,0x01
	LDI R23,0b00000010
	ST Z+,R23
	LDI R23,0b00000010
	ST Z+,R23
	LDI R23,0b00000010
	ST Z+,R23
	LDI R23,0b00000010
	ST Z+,R23
	LDI R23,0b00000000
	ST Z+,R23

	LDI ZL,0x0A
	LDI R23,0b00000010
	ST Z+,R23
	LDI R23,0b00000010
	ST Z+,R23
	LDI R23,0b00000010
	ST Z+,R23
	LDI R23,0b00000010
	ST Z+,R23
	LDI R23,0b00000000
	ST Z+,R23

	LDI ZL,0x14
	LDI R23,0b00000010
	ST Z+,R23
	LDI R23,0b00000010
	ST Z+,R23
	LDI R23,0b00000010
	ST Z+,R23
	LDI R23,0b00000010
	ST Z+,R23
	LDI R23,0b00000010
	ST Z+,R23

	LDI ZL,0x1E
	LDI R23,0b00000000
	ST Z+,R23
	LDI R23,0b00000010
	ST Z+,R23
	LDI R23,0b00000010
	ST Z+,R23
	LDI R23,0b00000010
	ST Z+,R23
	LDI R23,0b00000010
	ST Z+,R23

	LDI ZL,0x28
	LDI R23,0b00000000
	ST Z+,R23
	LDI R23,0b00000010
	ST Z+,R23
	LDI R23,0b00000010
	ST Z+,R23
	LDI R23,0b00000010
	ST Z+,R23
	LDI R23,0b00000010
	ST Z+,R23

	LDI ZL,0x32
	LDI R23,0b00000010
	ST Z+,R23
	LDI R23,0b00000010
	ST Z+,R23
	LDI R23,0b00000010
	ST Z+,R23
	LDI R23,0b00000010
	ST Z+,R23
	LDI R23,0b00000010
	ST Z+,R23

	LDI ZL,0x3C
	LDI R23,0b00000010
	ST Z+,R23
	LDI R23,0b00000010
	ST Z+,R23
	LDI R23,0b00000010
	ST Z+,R23
	LDI R23,0b00000000
	ST Z+,R23
	LDI R23,0b00000010
	ST Z+,R23

	;----------------------------

	LDI ZL,0x05
	LDI R23,0b00000010
	ST Z+,R23
	LDI R23,0b00000000
	ST Z+,R23
	LDI R23,0b00000010
	ST Z+,R23
	LDI R23,0b00000000
	ST Z+,R23
	LDI R23,0b00000010
	ST Z+,R23

	LDI ZL,0x0F
	LDI R23,0b00000010
	ST Z+,R23
	LDI R23,0b00000000
	ST Z+,R23
	LDI R23,0b00000010
	ST Z+,R23
	LDI R23,0b00000010
	ST Z+,R23
	LDI R23,0b00000010
	ST Z+,R23

	LDI ZL,0x19
	LDI R23,0b00000010
	ST Z+,R23
	LDI R23,0b00000010
	ST Z+,R23
	LDI R23,0b00000010
	ST Z+,R23
	LDI R23,0b00000010
	ST Z+,R23
	LDI R23,0b00000010
	ST Z+,R23

	LDI ZL,0x23
	LDI R23,0b00000010
	ST Z+,R23
	LDI R23,0b00000010
	ST Z+,R23
	LDI R23,0b00000010
	ST Z+,R23
	LDI R23,0b00000010
	ST Z+,R23
	LDI R23,0b00000010
	ST Z+,R23

	LDI ZL,0x2D
	LDI R23,0b00000010
	ST Z+,R23
	LDI R23,0b00000010
	ST Z+,R23
	LDI R23,0b00000010
	ST Z+,R23
	LDI R23,0b00000010
	ST Z+,R23
	LDI R23,0b00000010
	ST Z+,R23

	LDI ZL,0x37
	LDI R23,0b00000010
	ST Z+,R23
	LDI R23,0b00000010
	ST Z+,R23
	LDI R23,0b00000000
	ST Z+,R23
	LDI R23,0b00000010
	ST Z+,R23
	LDI R23,0b00000010
	ST Z+,R23

	LDI ZL,0x41
	LDI R23,0b00000010
	ST Z+,R23
	LDI R23,0b00000010
	ST Z+,R23
	LDI R23,0b00000000
	ST Z+,R23
	LDI R23,0b00000010
	ST Z+,R23
	LDI R23,0b00000010
	ST Z+,R23
	POP R24
	POP R23
	POP R22

	RET


writeGameOvertoRAM:
	PUSH R30
	PUSH R31
	PUSH R25
	RCALL clearRAMa
	RCALL clearRAMb
	LDI ZL,0x00
	LDI ZH,0x01
	LDI R25,0b01110111
	ST Z+,R25
	LDI R25,0b11100011 
	ST Z+,R25
	LDI R25,0b11110000 
	ST Z+,R25

	LDI ZL,0x0A
	LDI R25,0b10001100 
	ST Z+,R25
	LDI R25,0b01110111 
	ST Z+,R25

	LDI ZL,0x14
	LDI R25,0b10000100 
	ST Z+,R25
	LDI R25,0b01101011 
	ST Z+,R25

	LDI ZL,0x1E
	LDI R25,0b10000100 
	ST Z+,R25
	LDI R25,0b01101011 
	ST Z+,R25
	LDI R25,0b11000000 
	ST Z+,R25

	LDI ZL,0x28
	LDI R25,0b10111111 
	ST Z+,R25
	LDI R25,0b11100011 
	ST Z+,R25

	LDI ZL,0x32
	LDI R25,0b10001100 
	ST Z+,R25
	LDI R25,0b01100011 
	ST Z+,R25

	LDI ZL,0x3C
	LDI R25,0b01110100 
	ST Z+,R25
	LDI R25,0b01100011 
	ST Z+,R25
	LDI R25,0b11110000 
	ST Z+,R25

	;===========

	LDI ZL,0x06
	LDI R25,1
	ST Z+,R25
	LDI R25,0b11111000 
	ST Z+,R25
	LDI R25,0b11111111 
	ST Z+,R25
	LDI R25,0b11000000
	ST Z+,R25

	LDI ZL,0x10
	LDI R25,1
	ST Z+,R25
	LDI R25,0b00011000 
	ST Z+,R25
	LDI R25,0b11000010 
	ST Z+,R25
	LDI R25,0b00100000
	ST Z+,R25

	LDI ZL,0x1A
	LDI R25,1
	ST Z+,R25
	LDI R25,0b00011000 
	ST Z+,R25
	LDI R25,0b11000010 
	ST Z+,R25
	LDI R25,0b00100000
	ST Z+,R25

	LDI ZL,0x24
	LDI R25,1
	ST Z+,R25
	LDI R25,0b00011000 
	ST Z+,R25
	LDI R25,0b11111011 
	ST Z+,R25
	LDI R25,0b10000000
	ST Z+,R25

	LDI ZL,0x2E
	LDI R25,1
	ST Z+,R25
	LDI R25,0b00011001 
	ST Z+,R25
	LDI R25,0b01000010 
	ST Z+,R25
	LDI R25,0b01000000
	ST Z+,R25

	LDI ZL,0x38
	LDI R25,1
	ST Z+,R25
	LDI R25,0b00011010 
	ST Z+,R25
	LDI R25,0b01000010 
	ST Z+,R25
	LDI R25,0b00100000
	ST Z+,R25

	LDI ZL,0x42
	LDI R25,1
	ST Z+,R25
	LDI R25,0b11111100 
	ST Z+,R25
	LDI R25,0b01111110 
	ST Z+,R25
	LDI R25,0b00100000
	ST Z+,R25
	

	POP R25
	POP R31
	POP R30
	RET

buzz:
	SBI PORTB,1
	RCALL waitShort ; Wait a bit more short
	CBI PORTB,1
	RCALL waitShort
	RET

waitShort:
	PUSH R31
	LDI R31,0x01
	bshort:
		DEC R31
		CPI R31,0
		BRNE bshort
	POP R31
	RET
	
checkklaxon:
	IN R0,PINB
	BST R0,2
	BRTC klax
	RJMP return
	klax:
		RCALL buzz
	return:
	RET
