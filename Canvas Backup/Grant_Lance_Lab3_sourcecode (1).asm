;***********************************************************
;*	Lab 3 ECE 375 Fall 2022
;*	-This progam will allow the AVR board to display 
;*   two different strings saved in memory
;*	 
;*     Author: Grant Lance
;*	   Date: 10/20/2022
;*
;***********************************************************

.include "m32U4def.inc"			; Include definition file
.equ	PushB1 = 4				;PB1 Input bit
.equ	PushB2 = 5				;PB2 Input bit
.equ	PushB3 = 6				;PB3 Input bit
.equ	PushB4 = 7				;PB4 Input bit
;***********************************************************
;*	Internal Register Definitions and Constants
;***********************************************************
.def	mpr = r16				; Multipurpose register is required for LCD Driver
.def	waitcnt = r17			; Wait Loop Counter - copied from lab 1 for wait
.def	ilcnt = r18				; Inner Loop Counter
.def	olcnt = r19				; Outer Loop Counter
.def	inputreg = r23			; register to handle port D inputs
.equ	WTime = 25				; Time to wait in wait loop
;***********************************************************
;*	Start of Code Segment
;***********************************************************
.cseg							; Beginning of code segment

;***********************************************************
;*	Interrupt Vectors
;***********************************************************
.org	$0000					; Beginning of IVs
		rjmp INIT				; Reset interrupt

.org	$0056					; End of Interrupt Vectors

;***********************************************************
;*	Program Initialization
;***********************************************************
INIT:							; The initialization routine
								;
		ldi mpr, high(RAMEND)	; Initialize Stack Pointer
		out SPH, mpr			;
		ldi mpr, low(RAMEND)	;
		out SPL, mpr			;

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

		; NOTE that there is no RET or RJMP from INIT,
		; this is because the next instruction executed is the
		; first instruction of the main program
;***********************************************************
;*	Main Program
;***********************************************************
MAIN:							; The Main program
								; Main function design is up to you. Below is an example to brainstorm.
	in		inputreg, PIND		; Get inputs from PIND
	SBRS	inputreg, PushB4	; If button 4 set skip next line
	rcall 	MARQUEE				; Call Scroll Function
	SBRS	inputreg, PushB3	; If button 3 set skip next line
	rcall 	LOOP1				; Move string from Program Memory to Data Memory
	SBRS	inputreg, PushB3	; If button 3 set skip next line
	rcall 	PRINTLOOP			; Move string from Program Memory to Data Memory
	SBRS	inputreg, PushB2	; If button 2 set skip next line
	rcall 	PRINTLOOP2			; Move string from Program Memory to Data Memory
	SBRS	inputreg, PushB2	; If button 2set skip next line
	rcall 	LOOP2				; Move string from Program Memory to Data Memory
	SBRS	inputreg, PushB1	; If button 1 set skip next line
	rcall	LCDClr				;
	
	
	rcall 	LCDWrite			; Display the string on the LCD Display
	rjmp 	MAIN				; jump back to main and create an infinite
								; while loop.  Generally, every main program is an
								; infinite while loop, never let the main program
								; just run off
;***********************************************************
;*	Functions and Subroutines
;***********************************************************
;----------------------------------------------------------------
; Sub:	Wait - stolen from lab 1 example code
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
		dec		olcnt			; decrement olcnt
		brne	OLoop			; Continue Outer Loop
		dec		waitcnt			; Decrement wait
		brne	Loop			; Continue Wait loop

		pop		olcnt			; Restore olcnt register
		pop		ilcnt			; Restore ilcnt register
		pop		waitcnt			; Restore wait register
		ret						; Return from subroutine

;-----------------------------------------------------------
; Func: LOOP1 
; Desc: move string 1 to data memory to be read by the LCD driver (LCD Line 1)
;-----------------------------------------------------------
LOOP1:							; NOTE: all writes to data memory from program memory function the same as this.
								; The only difference being that the memory addresses are different as to display on either the top or bottom.

	push mpr					; Save program state
	in	 mpr,	SREG 
	push mpr

	ldi ZH, high(STRING1_BEG<<1); Assign Z string beginning
	ldi ZL, low(STRING1_BEG<<1)	; Assign Low

	ldi XH, high($0100)			; Assign X LCD Buffer
	ldi XL, low($0100)			; Assign low

	LOOPONE:

		lpm mpr, Z+
		st  X+, mpr

		lpm mpr, Z
		add mpr, mpr, r0
		brne LOOPONE

	pop	mpr						; Return program state
	out	SREG, mpr
	pop mpr

	ret						; End a function with RET

;-----------------------------------------------------------
; Func: LOOP2 
; Desc: move string 1 to data memory to be read by the LCD driver (LCD Line 2)
;-----------------------------------------------------------
LOOP2:

	push mpr
	in	 mpr,	SREG 
	push mpr


	ldi ZH, high(STRING1_BEG<<1)
	ldi ZL, low(STRING1_BEG<<1)

	ldi XH, high($0110)
	ldi XL, low($0110)

	LOOPONE2:

		lpm mpr, Z+
		st  X+, mpr

		lpm mpr, Z
		add mpr, mpr, r0
		brne LOOPONE2

	pop	mpr
	out	SREG, mpr
	pop mpr

	ret						; End a function with RET
;-----------------------------------------------------------
; Func: PRINTLOOP 
; Desc: move string 2 to data memory to be read by the LCD driver (LCD Line 2)
;-----------------------------------------------------------
PRINTLOOP:

	push mpr
	in	 mpr,	SREG 
	push mpr

	ldi ZH, high(STRING2_BEG<<1)
	ldi ZL, low(STRING2_BEG<<1)

	ldi XH, high($0110)
	ldi XL, low($0110)

	LOOPTWO:

		lpm mpr, Z+
		st  X+, mpr

		lpm mpr, Z
		add mpr, mpr, r0
		brne LOOPTWO

	pop	mpr
	out	SREG, mpr
	pop mpr

	ret						; End a function with RET
;-----------------------------------------------------------
; Func: PRINTLOOP2 
; Desc: move string 2 to data memory to be read by the LCD driver (LCD Line 1)
;-----------------------------------------------------------
PRINTLOOP2:

	push mpr
	in	 mpr,	SREG 
	push mpr

	ldi ZH, high(STRING2_BEG<<1)
	ldi ZL, low(STRING2_BEG<<1)

	ldi XH, high($0100)
	ldi XL, low($0100)

	LOOPTWO2:

		lpm mpr, Z+
		st  X+, mpr

		lpm mpr, Z
		add mpr, mpr, r0
		brne LOOPTWO2

	pop	mpr
	out	SREG, mpr
	pop mpr

	ret						; End a function with RET
;-----------------------------------------------------------
; Func: MARQUEE 
; Desc: loop and print LCD buffer memory for scroll effect
;-----------------------------------------------------------
MARQUEE:  ;each line of lcd is 16 spaces wide

								; 20-22 registers reserved for lcd
								; Note: at this point in my program I realized the importance of pushing/popping
								; Four registers are needed to traverse
								; Four registers will be preserved and eventually returned from the stack
    push r17					; preserve program state
    push r18
	push r19
	push mpr
	in	 mpr,	SREG 
	push mpr
    							; put start of line one in x
	ldi XH, 	high($0100)		;
	ldi XL, 	low($0100)		; Load Z pointer with top row
    
    							; put start of line one in z
	ldi ZH, 	high($0100)		;
	ldi ZL, 	low($0100)		; Load X pointer with second row
    
   
   ld r16, 		X+ 				; load the contents of the first space of line 1
   ldi r18, 	low($011f) 		; setup for loop conditional check
    
	SWAPLOOP:					; Loop for swaping the rest of the rows

    	ld r17, 	X 				; load the value whose space we are about to overwrite so it is not corrupted
   		st X+, 		r16 			; place the previous spots value in the current spot
    	mov r16, 	r17 			; put r17 into r16, make newly found value the value we will swap in at the start of the next loop
    	cp XL, 	r18 				; check to see if we are on the last spot in the lcd memory region
    	brne SWAPLOOP 
    
    
	ld r17, X 					; when we get out of loop x points to last spot in the second line
    st X, r16
    st Z, r17
    
    
	rcall LCDWrite				; Write the new data to LCD
	rcall Wait					; Call wait
    
    pop	mpr						; return program to former state
	out	SREG, mpr
	pop	mpr
	pop r19
	pop r18
    pop r17
	
	ret							; End with a return
;***********************************************************
;*	Stored Program Data
;***********************************************************

;-----------------------------------------------------------
; An example of storing a string. Note the labels before and
; after the .DB directive; these can help to access the data
;-----------------------------------------------------------
STRING1_BEG:
.DB		"Grant Lance     "	; my name	
STRING1_END:

STRING2_BEG:
.db 	"Hello, World    "  ; a second string for testing
SRING2_END:
;***********************************************************
;*	Additional Program Includes
;***********************************************************
.include "LCDDriver.asm"		; Include the LCD Driver
