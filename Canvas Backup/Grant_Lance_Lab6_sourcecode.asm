;***********************************************************
;*
;*	This is the skeleton file for Lab 6 of ECE 375
;*
;*	 Author: Grant Lance
;*	   Date: 11/16/22
;*
;***********************************************************

.include "m32U4def.inc"			; Include definition file

;***********************************************************
;*	Internal Register Definitions and Constants
;***********************************************************
.def	mpr = r16				; Multipurpose register
.def 	elspeed = r17
.def 	sixteen = r1
.def 	fifteen = r2
.def 	zero = r0
.def    clrelspeed = r3


.equ	EngEnR = 5				; right Engine Enable Bit
.equ	EngEnL = 6				; left Engine Enable Bit
.equ	EngDirR = 4				; right Engine Direction Bit
.equ	EngDirL = 7				; left Engine Direction Bit
.equ	MovFwd = (1<<EngDirR|1<<EngDirL)	; move forward command

;***********************************************************
;*	Start of Code Segment
;***********************************************************
.cseg							; beginning of code segment

;***********************************************************
;*	Interrupt Vectors
;***********************************************************
.org	$0000
		rjmp	INIT			; reset interrupt

		; place instructions in interrupt vectors here, if needed
.org 	$0002
		rcall SPEED_DOWN
		reti

.org	$0004
		rcall SPEED_UP
		reti
.org 	$0008
		rcall SPEED_MAX
		reti


.org	$0056					; end of interrupt vectors

;***********************************************************
;*	Program Initialization
;***********************************************************
INIT:
		; Initialize the Stack Pointer
		ldi		mpr, low(RAMEND)
		out		SPL, mpr		; Load SPL with low byte of RAMEND
		ldi		mpr, high(RAMEND)
		out		SPH, mpr		; Load SPH with high byte of RAMEND

		;set desired registers
		ldi 	mpr, $10
		mov		sixteen, mpr
		ldi		mpr, $0F
		mov		fifteen, mpr
		ldi		mpr, $F0
		mov		clrelspeed, mpr
		clr		elspeed	
		clr 	zero

		; Configure I/O ports
		; Initialize Port B for output
		ldi		mpr, $FF		; Set Port B Data Direction Register
		out		DDRB, mpr		; for output
		ldi		mpr, $00		; Initialize Port B Data Register
		out		PORTB, mpr		; so all Port B outputs are low

		; Initialize Port D for input
		ldi		mpr, $00		; Set Port D Data Direction Register
		out		DDRD, mpr		; for input
		ldi		mpr, $FF		; Initialize Port D Data Register
		out		PORTD, mpr		; so all Port D inputs are Tri-State

		; Configure External Interrupts
		; Set the Interrupt Sense Control to falling edge
		ldi		mpr, 0b10001010		
		sts 	EICRA, mpr

		; Configure the External Interrupt Mask
		ldi 	mpr, 0b00001011 		;INT 0,1,3 on
		out 	EIMSK, mpr

		; Configure 16-bit Timer/Counter 1A and 1B
		ldi 	mpr, 0b10100001 	
		sts		TCCR1A, mpr
		ldi 	mpr, 0b00001001		; no prescaler
		sts		TCCR1B, mpr
		; Fast PWM, 8-bit mode, no prescaling
		ldi 	mpr, $FF
		sts		OCR1AL, mpr
		sts		OCR1BL, mpr
		; Set TekBot to Move Forward
		ldi		mpr, MovFwd		
		out		PORTB, mpr		

		; Set initial speed, display on Port B pins 3:0
		in		mpr, PORTB
		or		mpr, elspeed
		out		PORTB, mpr
		; Enable global interrupts (if any are used)
		sei
;***********************************************************
;*	Main Program
;***********************************************************
MAIN:
		
				
		; No main because why not 

		rjmp	MAIN			; return to top of MAIN

;***********************************************************
;*	Functions and Subroutines
;***********************************************************
;-----------------------------------------------------------
; Func: SPEED_DOWN
; Desc: decrease speed by one level
;-----------------------------------------------------------
SPEED_DOWN:						

		cli						; no interrupting
		push	mpr				
		ldi		mpr, 0b00000000
		out 	EIMSK, mpr		
		in		mpr, SREG		; 
		push	mpr				; why won't interupts stop

		; check if level is already 0
		sub 	elspeed, zero 	; to set zero flag if true
		BREQ	SkipD			; skip if z (zero) flag is 1

		; Change Compare value Increasing it will slow motor
		lds 	mpr, OCR1AL
		add		mpr, sixteen
		sts		OCR1AL, mpr
		sts     OCR1BL, mpr
		dec 	elspeed			; lower speed by 1

	SkipD:

		in		mpr, PORTB		
		and		mpr, clrelspeed	; clear speed bits
		or		mpr, elspeed		
		out		PORTB, mpr		
		

		ldi 	mpr, 0b00001011			; clear Queue	
		out		EIFR, mpr
		ldi		mpr, 0b00001011			; reset mask
		out 	EIMSK, mpr

		pop		mpr						; Restore program state
		out		SREG, mpr	
		pop		mpr						; put back mpr
		ret								

;-----------------------------------------------------------
; Func: SPEED_UP
; Desc: increase speed by one level
;-----------------------------------------------------------
SPEED_UP:							

		cli					; no interrupting?
		push	mpr			
		in		mpr, SREG	 
		push	mpr			

		; level is already 0?
		cp 		elspeed, fifteen 	; to set zero flag if true (speed = 15)
		BREQ	SkipU				; skip if z (zero) flag is 1

		; Change Compare value decreasing will increase motor speed
		lds 	mpr, OCR1AL
		sub		mpr, sixteen
		sts		OCR1AL, mpr
		sts     OCR1BL, mpr
		inc 	elspeed				; increase speed lvl by 1

	SkipU:

		in		mpr, PORTB
		and		mpr, clrelspeed		; clear speed bits
		or		mpr, elspeed		; new speed loaded in
		out		PORTB, mpr			; Write to port B
		

		ldi 		mpr, 0b00001011	; clear Queue	
		out		EIFR, mpr


		pop		mpr					; Restore program state
		out		SREG, mpr	
		pop		mpr					; put back mpr
		ret						

;-----------------------------------------------------------
; Func: SPEED_MAX
; Desc: speed to max value
;-----------------------------------------------------------
SPEED_MAX:							

		cli					; no interrupting?
		push	mpr			
		in		mpr, SREG	
		push	mpr			


		; Change Compare value decreasing will increase motor speed
		ldi 	mpr, $00
		sts		OCR1AL, mpr			; 0% duty cycle
		sts     OCR1BL, mpr
		ldi 	elspeed, $0F		; max speed 
		in		mpr, PORTB		
		and		mpr, clrelspeed		
		or		mpr, elspeed		
		out		PORTB, mpr			
		
		ldi 	mpr, 0b00001011		; clear Queue	
		out		EIFR, mpr

		pop		mpr					; restore program state
		out		SREG, mpr			;
		pop		mpr					; put back mpr
		ret							

