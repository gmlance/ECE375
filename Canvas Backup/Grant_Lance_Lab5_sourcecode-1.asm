;***********************************************************
;*	 Lab 5 of ECE 375 - External Interrupts
;*
;*	 Author: Grant Lance
;*	   Date: 11/14/2022
;*
;***********************************************************


.include "m32U4def.inc"				; Include definition file

;************************************************************
;* Variable and Constant Declarations
;************************************************************
.def	mpr = r16				; Multi-Purpose Register
.def	waitcnt = r17				; Wait Loop Counter
.def	ilcnt = r18				; Inner Loop Counter
.def	olcnt = r19				; Outer Loop Counter

.equ	WTime = 25				; Time to wait in wait loop
								; Note: originally 100. changed to 25 for faster debugging

.equ	WskrR = 4				; Right Whisker Input Bit
.equ	WskrL = 5				; Left Whisker Input Bit
.equ	EngEnR = 5				; Right Engine Enable Bit
.equ	EngEnL = 6				; Left Engine Enable Bit
.equ	EngDirR = 4				; Right Engine Direction Bit
.equ	EngDirL = 7				; Left Engine Direction Bit

;/////////////////////////////////////////////////////////////
;These macros are the values to make the TekBot Move.
;/////////////////////////////////////////////////////////////

.equ	MovFwd = (1<<EngDirR|1<<EngDirL)	; Move Forward Command
.equ	MovBck = $00				; Move Backward Command
.equ	TurnR = (1<<EngDirL)			; Turn Right Command
.equ	TurnL = (1<<EngDirR)			; Turn Left Command
.equ	Halt = (1<<EngEnR|1<<EngEnL)		; Halt Command

;============================================================
; NOTE: Let me explain what the macros above are doing.
; Every macro is executing in the pre-compiler stage before
; the rest of the code is compiled.  The macros used are
; left shift bits (<<) and logical or (|).  Here is how it
; works:
;	Step 1.  .equ	MovFwd = (1<<EngDirR|1<<EngDirL)
;	Step 2.		substitute constants
;			 .equ	MovFwd = (1<<4|1<<7)
;	Step 3.		calculate shifts
;			 .equ	MovFwd = (b00010000|b10000000)
;	Step 4.		calculate logical or
;			 .equ	MovFwd = b10010000
; Thus MovFwd has a constant value of b10010000 or $90 and any
; instance of MovFwd within the code will be replaced with $90
; before the code is compiled.  So why did I do it this way
; instead of explicitly specifying MovFwd = $90?  Because, if
; I wanted to put the Left and Right Direction Bits on different
; pin allocations, all I have to do is change thier individual
; constants, instead of recalculating the new command and
; everything else just falls in place.
;==============================================================

;**************************************************************
;* Beginning of code segment
;**************************************************************
.cseg

;***********************************************************
;*	Interrupt Vectors
;***********************************************************
.org	$0000					; Beginning of IVs
		rjmp 	INIT			; Reset interrupt

		; Set up interrupt vectors for any interrupts being used

		; This is just an example:
;.org	$002E					; Analog Comparator IV
;		rcall	HandleAC		; Call function to handle interrupt
;		reti					; Return from interrupt
.org	$0002					;INT0
		rcall	HitRight
		reti
.org	$0004					;INT1
		rcall	HitLeft
		reti
.org	$0008					;INT3
		rcall	COUNTCLEAR
		reti

.org	$0056					; End of Interrupt Vectors
;--------------------------------------------------------------
; Program Initialization
;--------------------------------------------------------------
INIT:
    ; Initialize the Stack Pointer (VERY IMPORTANT!!!!)
		ldi		mpr, low(RAMEND)
		out		SPL, mpr		; Load SPL with low byte of RAMEND
		ldi		mpr, high(RAMEND)
		out		SPH, mpr		; Load SPH with high byte of RAMEND

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

		call LCDInit    		; Initialize LCD Display
		rcall LCDClr
		rcall LCDBacklightOn
		rcall	LOOPL			; Move labels from program memory to buffer
		rcall	LOOPR

		ldi mpr, 0
		sts HITCOUNTL, mpr
		ldi	mpr, 0
		sts HITCOUNTR, mpr
		clr mpr


	
	; Set the Interrupt Sense Control to falling edge
		ldi mpr, 0b00001010
		sts EICRA, mpr ; Use sts, EICRA in extended I/O space
	; Set the External Interrupt Mask
		ldi mpr, 0b00001011
		out EIMSK, mpr
		clr mpr
	; Turn on interrupts
		sei
	; NOTE: This must be the last thing to do in the INIT function

;---------------------------------------------------------------
; Main Program
;---------------------------------------------------------------
		MAIN:	; The Main program
		; Initialize TekBot Foward Movement
		ldi		mpr, MovFwd		; Load Move Forward Command
		out		PORTB, mpr		; Send command to motors
		clr		mpr
		
		rcall	HITCOUNTASCIIL ; check for changes in hit count 
							   ; increment LCD display
		rcall   HITCOUNTASCIIR ; check for changes in hit count 
							   ; increment LCD display
		
		rcall	LCDWrite		; Write to LCD from Buffer
		; Set the External Interrupt Mask
		ldi mpr, 0b00001011
		out EIMSK, mpr
		clr mpr
		rjmp	MAIN			; Create an infinite while loop to signify the 
							

;****************************************************************
;* Subroutines and Functions
;****************************************************************

;----------------------------------------------------------------
; Sub:	HitRight
; Desc:	Handles functionality of the TekBot when the right whisker
;		is triggered.
;----------------------------------------------------------------
HitRight:
		push	mpr			; Save mpr register
		push	waitcnt			; Save wait register
		in		mpr, SREG	; Save program state
		push	mpr			;

		; Set the External Interrupt Mask
		ldi mpr, 0b00000000
		out EIMSK, mpr

		; Move Backwards for a second
		ldi		mpr, MovBck	; Load Move Backward command
		out		PORTB, mpr	; Send command to port
		ldi		waitcnt, WTime	; Wait for 1 second
		rcall	Wait			; Call wait function

		; Turn left for a second
		ldi		mpr, TurnL	; Load Turn Left Command
		out		PORTB, mpr	; Send command to port
		ldi		waitcnt, WTime	; Wait for 1 second
		rcall	Wait			; Call wait function

		; Move Forward again
		ldi		mpr, MovFwd	; Load Move Forward command
		out		PORTB, mpr	; Send command to port
		clr		mpr

		rcall   INCHITCOUNTR ; increment HITCOUNT
		ldi		mpr, 0b00001011 ; no queue of interupts
		out		EIFR, mpr

		pop		mpr		; Restore program state
		out		SREG, mpr	;
		pop		waitcnt		; Restore wait register
		pop		mpr		; Restore mpr
		ret				; Return from subroutine

;----------------------------------------------------------------
; Sub:	HitLeft
; Desc:	Handles functionality of the TekBot when the left whisker
;		is triggered.
;----------------------------------------------------------------
HitLeft:
		push	mpr			; Save mpr register
		push	waitcnt			; Save wait register
		in		mpr, SREG	; Save program state
		push	mpr			;

		; Set the External Interrupt Mask
		ldi mpr, 0b00000000
		out EIMSK, mpr

		; Move Backwards for a second
		ldi		mpr, MovBck	; Load Move Backward command
		out		PORTB, mpr	; Send command to port
		ldi		waitcnt, WTime	; Wait for 1 second
		rcall	Wait			; Call wait function

		; Turn right for a second
		ldi		mpr, TurnR	; Load Turn Left Command
		out		PORTB, mpr	; Send command to port
		ldi		waitcnt, WTime	; Wait for 1 second
		rcall	Wait			; Call wait function

		; Move Forward again
		ldi		mpr, MovFwd	; Load Move Forward command
		out		PORTB, mpr	; Send command to port
		clr		mpr

		rcall   INCHITCOUNTL ; increment HITCOUNT
		ldi		mpr, 0b00001011 ; no queue of interupts
		out		EIFR, mpr

		pop		mpr		; Restore program state
		out		SREG, mpr	;
		pop		waitcnt		; Restore wait register
		pop		mpr		; Restore mpr
		ret				; Return from subroutine

;----------------------------------------------------------------
; Sub:	Wait
; Desc:	A wait loop that is 16 + 159975*waitcnt cycles or roughly
;		waitcnt*10ms.  Just initialize wait for the specific amount
;		of time in 10ms intervals. Here is the general eqaution
;		for the number of clock cycles in the wait loop:
;			(((((3*ilcnt)-1+4)*olcnt)-1+4)*waitcnt)-1+16
;----------------------------------------------------------------
Wait:
		push	waitcnt			; Save wait register
		push	ilcnt			; Save ilcnt register
		push	olcnt			; Save olcnt register

Loop:	ldi		olcnt, 224		; load olcnt register
OLoop:	ldi		ilcnt, 237		; load ilcnt register
ILoop:	dec		ilcnt			; decrement ilcnt
		brne	ILoop			; Continue Inner Loop
		dec		olcnt		; decrement olcnt
		brne	OLoop			; Continue Outer Loop
		dec		waitcnt		; Decrement wait
		brne	Loop			; Continue Wait loop

		pop		olcnt		; Restore olcnt register
		pop		ilcnt		; Restore ilcnt register
		pop		waitcnt		; Restore wait register
		ret				; Return from subroutine
;-----------------------------------------------------------
;	You will probably want several functions, one to handle the
;	left whisker interrupt, one to handle the right whisker
;	interrupt, and maybe a wait function
;------------------------------------------------------------

;-----------------------------------------------------------
; Func: Template function header
; Desc: Cut and paste this and fill in the info at the
;		beginning of your functions
;-----------------------------------------------------------
FUNC:							; Begin a function with a label

		; Save variable by pushing them to the stack

		; Execute the function here

		; Restore variable by popping them from the stack in reverse order

		ret						; End a function with RET

;-----------------------------------------------------------
; Func: COUNTCLEAR
; Desc: Clear interupt count (set to 0x00)
;-----------------------------------------------------------
COUNTCLEAR:							; Begin a function with a label

		push r16; Save variable by pushing them to the stack
		push r17
		push r18
		push r19

		; Set the External Interrupt Mask
		ldi mpr, 0b00000000
		out EIMSK, mpr

		; Execute the function here
		ldi YH, high(HITCOUNTR)
		ldi YL, low(HITCOUNTR)
		
		clr r16; make sure r16 is zero
		st  Y, r16;

		ldi YH, high(HITCOUNTL)
		ldi YL, low(HITCOUNTL)
		
		clr r16; make sure r16 is zero
		st  Y, r16;


		; Initialize LCD Display
		rcall LCDClr
		rcall	LOOPL
		rcall	LOOPR

		pop r19; Restore variable by popping them from the stack in reverse order
		pop r18
		pop r17
		pop r16

		ret						; End a function with RET
;-----------------------------------------------------------
; Func: INCHITCOUNTR
; Desc: Increment right hit count
;-----------------------------------------------------------
INCHITCOUNTR:							; Begin a function with a label

		push r16; Save variable by pushing them to the stack
		push r17
		push r18
		push r19
		
		
		; Execute the function here
		ldi YH, high(HITCOUNTR)
		ldi YL, low(HITCOUNTR)

		ld r16, Y ; load Y with HITCOUNT and load r16 with first value
		inc r16 ; r16 -> r16 + 1
		st Y, r16; store incremented HITCOUNT


		pop r19; Restore variable by popping them from the stack in reverse order
		pop r18
		pop r17
		pop r16

		ret						; End a function with RET
;-----------------------------------------------------------
; Func: INCHITCOUNTL
; Desc: Increment left hit count
;-----------------------------------------------------------
INCHITCOUNTL:							; Begin a function with a label

		push r16; Save variable by pushing them to the stack
		push r17
		push r18
		push r19
		
		
		; Execute the function here
		ldi YH, high(HITCOUNTL)
		ldi YL, low(HITCOUNTL)

		ld r16, Y ; load Y with HITCOUNT and load r16 with first value
		inc r16 ; r16 -> r16 + 1
		st Y, r16; store incremented HITCOUNT


		pop r19; Restore variable by popping them from the stack in reverse order
		pop r18
		pop r17
		pop r16

		ret						; End a function with RET
;-----------------------------------------------------------
; Func: HITCOUNTASCIIR
; Desc: Change the saved hex value for an ascii code to be displayed
;-----------------------------------------------------------
HITCOUNTASCIIR:							; Begin a function with a label

		push r16; Save variable by pushing them to the stack
		push r17; r16 is mpr
		push r18; bin2ascii will convert what every is in mpr to ascii
		push r19; it is saved to where ever x points to

		; a character can be converted one value at a time

		ldi YH, high(HITCOUNTR)
		ldi YL, low(HITCOUNTR)

		ldi XH, high($0116)
		ldi XL, low($0116)

		; load character from HITCOUNT
		ld r16, Y
		; convert character from HITCOUNT
		rcall Bin2ASCII

		
		; write to the memory address for HITASCII

		pop r19
		pop r18
		pop r17
		pop r16

		; Restore variable by popping them from the stack in reverse order

		ret						; End a function with RET
;-----------------------------------------------------------
; Func: HITCOUNTASCIIL
; Desc: Change the saved hex value for an ascii code to be displayed
;-----------------------------------------------------------
HITCOUNTASCIIL:							; Begin a function with a label

		push r16; Save variable by pushing them to the stack
		push r17; r16 is mpr
		push r18; bin2ascii will convert what every is in mpr to ascii
		push r19; it is saved to where ever x points to

		; a character can be converted one value at a time

		ldi YH, high(HITCOUNTL)
		ldi YL, low(HITCOUNTL)

		ldi XH, high($0106)
		ldi XL, low($0106)

		; load character from HITCOUNT
		ld r16, Y
		; convert character from HITCOUNT
		rcall Bin2ASCII

		
		; write to the memory address for HITASCII

		pop r19
		pop r18
		pop r17
		pop r16

		; Restore variable by popping them from the stack in reverse order

		ret						; End a function with RET

;-----------------------------------------------------------
; Func: LOOPR 
; Desc: move string 1 to data memory to be read by the LCD driver (LCD Line 2)
;-----------------------------------------------------------
LOOPR:							; NOTE: all writes to data memory from program memory function the same as this.
								; The only difference being that the memory addresses are different as to display on either the top or bottom.

	push mpr					; Save program state
	in	 mpr,	SREG 
	push mpr
	push r17
	push r18

	ldi ZH, high(STRING2_BEG<<1); Assign Z string beginning
	ldi ZL, low(STRING2_BEG<<1)	; Assign Low

	ldi XH, high($0110)			; Assign X LCD Buffer
	ldi XL, low($0110)			; Assign low

	ldi r17, 6
	ldi r18, 0

	LOOPTWO:

		lpm mpr, Z+
		st  X+, mpr

		dec r17
		cp r17, r18
		brne LOOPTWO
	
	pop r18
	pop r17
	pop	mpr						; Return program state
	out	SREG, mpr
	pop mpr

	ret						; End a function with RET
;-----------------------------------------------------------
; Func: LOOPL 
; Desc: move string 1 to data memory to be read by the LCD driver (LCD Line 1)
;-----------------------------------------------------------
LOOPL:							; NOTE: all writes to data memory from program memory function the same as this.
								; The only difference being that the memory addresses are different as to display on either the top or bottom.

	push mpr					; Save program state
	in	 mpr,	SREG 
	push mpr
	push r17
	push r18

	ldi ZH, high(STRING1_BEG<<1); Assign Z string beginning
	ldi ZL, low(STRING1_BEG<<1)	; Assign Low

	ldi XH, high($0100)			; Assign X LCD Buffer
	ldi XL, low($0100)			; Assign low

	ldi r17, 6
	ldi r18, 0

	LOOPONE:

		lpm mpr, Z+
		st  X+, mpr

		dec r17
		cp r17, r18
		brne LOOPONE
	
	pop r18
	pop r17
	pop	mpr						; Return program state
	out	SREG, mpr
	pop mpr

	ret						; End a function with RET
;***********************************************************
;*	Additional Program Includes
;***********************************************************
; labels
STRING1_BEG:
.DB		"Left :"		
STRING1_END:
STRING2_BEG:
.DB		"Right:"		
STRING2_END:

.include "LCDDriver.asm"	; Include the LCD Driver
;***********************************************************
;*	Stored Program Data
;***********************************************************

; Enter any stored data you might need here
.dseg
.org	$0200
HITCOUNTL:
		.byte 2		; store two bytes for the hit count (binary value)
		; note:  no junk character on line 2 of lcd just binary value of HITCOUNT
		; note2: hitcount moved to different location in data memory outside of lcd buffer bounds
.org	$0203
HITCOUNTR:
		.byte 2



