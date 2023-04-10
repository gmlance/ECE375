
;***********************************************************
;*  	Rock Paper Scissors
;* 	Requirement:
;* 	1. USART1 communication
;* 	2. Timer/counter1 Normal mode to create a 1.5-sec delay
;***********************************************************
;*
;*	 Author: Grant Lance
;*		   : Albert Zeien
;*	   Date: 12/02/22
;*
;***********************************************************

.include "m32U4def.inc"         ; Include definition file

;***********************************************************
;*  Internal Register Definitions and Constants
;***********************************************************
.def  	mpr = r16               ; Multi-Purpose Register
.def	count1 = r17			; for loop count
.def	choice = r18			;
.def 	hold = r2				; temp
.def    ready = r19
.def	other = r3

; Use this signal code between two boards for their game ready
.equ    SendReady = 0b11111111

;***********************************************************
;*  Start of Code Segment
;***********************************************************
.cseg                           ; Beginning of code segment

;***********************************************************
;*  Interrupt Vectors
;***********************************************************
.org    $0000                   ; Beginning of IVs
	    rjmp    INIT            	; Reset interrupt

.org 	$0002
		rcall Butt4
		reti

.org	$0004
		rcall Butt7
		reti

.org	$0032
		rcall Receiver 
		reti

.org    $0056                   ; End of Interrupt Vectors

;***********************************************************
;*  Program Initialization
;***********************************************************
INIT:
	;Stack Pointer (VERY IMPORTANT!!!!)
	ldi	mpr, low(RAMEND)
	out	SPL, mpr		; Load SPL with low byte of RAMEND
	ldi	mpr, high(RAMEND)
	out	SPH, mpr		; Load SPH with high byte of RAMEND

	;I/O Ports
	; Initialize Port B for output
	ldi	mpr, $FF		; Set Port B Data Direction Register
	out	DDRB, mpr		; for output
	ldi	mpr, $00		; Initialize Port B Data Register
	out	PORTB, mpr		; so all Port B outputs are low

	; Initialize Port D for input
	ldi	mpr, 0b00001000	; Set Port D Data Direction Register
	out	DDRD, mpr		; for input ... PD3 is transmit is output
	ldi	mpr, 0b11110111	; Initialize Port D Data Register
	out	PORTD, mpr		; so all Port D inputs are Tri-State
	;USART1

		;Set baudrate at 2400bps
	ldi	mpr, high(416)		; Desired Baud Rate 416
	sts 	UBRR1H, mpr
	ldi	mpr, low(416)
	sts 	UBRR1L, mpr

		;Enable receiver and transmitter
	ldi 	mpr, 0b10011000		; R on (INT too), T on, 8 bit data
	sts 	UCSR1B, mpr

		;Set frame format: 8 data bits, 2 stop bits
	ldi	mpr, 0b00000010		; 2x Speed
	sts	UCSR1A, mpr
	ldi	mpr, 0b00001110		; 2Stop, no Parity, 8bit, 
	sts	UCSR1C, mpr
	
	
	; Set the Interrupt Sense Control to falling edge
		ldi	mpr, 0b00001010
		sts 	EICRA, mpr

	; Configure the External Interrupt Mask
		ldi 	mpr, 0b00000011 		;
		out 	EIMSK, mpr

	; Timer/Counter1 
	; Configure 16-bit Timer/Counter 1A and 1B
	ldi 	mpr, 0b00000000 	;Normal Mode, compare disabled
	sts	TCCR1A, mpr
	ldi 	mpr, 0b00000101		; normal mode, 1024 prescale 
	sts	TCCR1B, mpr
	; Normal, 1024 prescaling
	ldi 	mpr, high(53817)
	sts	TCNT1H, mpr		; TCNT1 53817 up to 65536
	ldi 	mpr, low(53817)		; Write high first
	sts	TCNT1L, mpr


	;LCDDriver
	rcall LCDInit
	rcall LCDClr
	rcall LCDBackLightOn

	;Other
	sei			; int flag

;***********************************************************
;*  Main Program
;***********************************************************
MAIN:

	rcall PmemDmemWelcome	; Welcome Statement

	clr 	ready			; New game, not yet ready
	ldi 	choice, $FF			;

	ldi 	mpr, 0b00000010 	; Reset INT 1 (BUTT7)
	out 	EIMSK, mpr			; For Gamestart

	;ldi 	ready, 2

	rcall CountDown		; Start CountDown

	GS:				; Gamestart Loop
		ldi 	choice	, 2	; Current choice scissors (hidden)
		ldi	ready, 4	; ready = 4 signifies game is running
		rcall PmemDmemGS	; Load LCD
		rcall CountDown	; Start CountDown

		UW:			; User Wins
	
			rcall WriteWon	; WriteLCD
			rcall CountDown	; CountDown before next game
			rjmp  MAIN		; Restart Game

		UL:			; User Losses
			rcall WriteLost	; WriteLCD
			rcall CountDown	; CountDown Before next game
			rjmp	MAIN		; Restart Game

		DR:			; Draw
			rcall WriteDraw	; WriteLCD
			rcall CountDown	; CountDown Before next game
			rjmp	MAIN		; Restart Game

;***********************************************************
;*	Functions and Subroutines
;***********************************************************
;-----------------------------------------------------------
; Func:	Butt7
; Desc:	Upon Button 7 Depress
;-----------------------------------------------------------
Butt7:	; Begin a function with a label

		; Turn off Button 7 (INT 1)
		ldi 	mpr, 0b00000001 		
		out 	EIMSK, mpr

		inc	ready		; ready must be 2 for gamestart
						; other inc is receiver 

		sbrc	ready, 1    ; if ready is 2 then game start!
		RJMP 	GS			; this part does seem to work
	
		rcall Transmitter



		ret

;-----------------------------------------------------------
; Func:	Butt4
; Desc:	Upon Button 4 Depress
;-----------------------------------------------------------
Butt4:	; Begin a function with a label

		cli		; Clear interrupt flag

		sbrc	choice, 1	; if current choice scissors, now rock
		rjmp	RC
		sbrc	choice, 0	; if current choice paper, scissors
		rjmp	SC
		rjmp	PPC		; if rock, now paper

		RC:
		rcall WriteRock
		ldi	choice, 0

		ret

		SC:
		rcall WriteScissors
		ldi 	choice, 2

		ret

		PPC:
		rcall WritePaper
		ldi 	choice, 1
		
		ret 
;-----------------------------------------------------------
; Func:	Transmitter
; Desc:	Trans options
;-----------------------------------------------------------
Transmitter:	; Begin a function with a label

		push mpr
		; if welcome statement
		; lds mpr, UCSR1A
		; sbrs mpr, UDRE1 ; Loop until UDR1 is empty
		; rjmp Transmitter

		sts 	UDR1, choice

		; if ready is already 2 game start
		sbrc	ready, 1 
		RJMP	GS

		sbrs	ready, 2	; skip if ready is 4
		RJMP 	ReadyNWait

		; wait for receive 
		; So it's sent? YEAH!

		ret

;-----------------------------------------------------------
; Func:	ReadyNWait
; Desc:	Wait for Recieve interrupt for game start
;-----------------------------------------------------------
ReadyNWait:	; Begin a function with a label

		rcall PmemDmemReady	; Waiting for Opponent

		sei
		Looper:

		sbrc	ready, 1		; if ready is 2 then game start!
		RJMP 	GS
		
		rjmp Looper 		; wait for receive 

		ret

;-----------------------------------------------------------
; Func:	Receiver INT
; Desc:	Receive options
;-----------------------------------------------------------
Receiver:	; Begin a function with a label

		push mpr
		push count
		; if welcome statement
		; rcall LCDBackLightOff
		;ldi 	mpr, 1
		ldi		count, 0b11111111
		lds		mpr, UDR1
		;cp	ready, mpr	; if ready Is 1 branch to Welcome receive 
		cp		mpr, count
		BREQ	WER
		;BREQ	ROC
		
		ldi 	mpr, 1
		cp	ready, mpr	; if ready Is 0 branch to Welcome receive 
		BREQ	WER

		ldi 	mpr, 0
		cp	ready, mpr	; if ready Is 0 branch to Welcome receive 
		BREQ	WER

		;lds	mpr, UDR1
		;and	other, mpr
		;BREQ	TEST
		

		; Never receive when ready is two

		;ready is 4
		RJMP ROC		; jump to receive other choice


		; Welcome receive
	WER:
		inc 	ready
		lds 	mpr, UDR1
		
		sbrc	ready, 1	; if ready is 2 then game start
		RJMP	 GS
		ret
		

		; else game start
	ROC:				; Receive other's choice
		lds	mpr, UDR1

		cp	choice, mpr	; Draw?
		BREQ	DR		; Draw.

		sbrc	choice, 1	; Skip if my choice isn't scissors
		RJMP	MCS		; other wise it is scissors
		sbrc	choice, 0	; skip if my choice isn't paper
		RJMP	MCP		; otherwise it is paper	
		RJMP	MCR		; must be rock!

		MCS:
			sbrc mpr, 0; skip if other isn't paper
			RJMP UW	; They have paper so User wins
			RJMP UL	; They have rock so User Losses
		MCP:
			sbrc mpr, 1; skip if other isn't scissors
			RJMP UL	; Other has Scissors so User Losses
			RJMP UW	; Other has Rock so User Wins

		MCR:
			sbrc mpr, 1; skip if other isn't scissors
			RJMP UW	; Other has scissors so user wins
			RJMP UL	; other has paper so user losses

		pop count
		pop mpr


		ret
;-----------------------------------------------------------
; Func:	Countdown
; Desc:	6 sec countdown changing LEDs 4-7
;-----------------------------------------------------------
Countdown:	; Begin a function with a label

	push mpr
	push r17

	sei
	
	sbi	$16, 0		; clear tov in TIFR1

	ldi 	mpr, high(53817)
	sts	TCNT1H, mpr		; TCNT1 = $48E5 = 18661
	ldi 	mpr, low(53817)		; Write high first
	sts	TCNT1L, mpr

	ldi	mpr, 0b11110000
	mov	hold,	mpr
	out 	PORTB, hold
	
	; load led then wait 1.5 sec (1)

	;ldi mpr, 8
	;ldi	r17, 10
	;add mpr, ready
	;cp  ready, mpr
	;BREQ GS



CLoop1:	
	
	sbrc	ready, 1		; if ready is 2 then game start!
	RJMP 	GS
					; else: loop
	sbis	TIFR1, TOV1		; TOV1 set?
	rjmp	CLoop1			; 1.5 sec wait


	sbi	TIFR1, TOV1		; clear tov in TIFR1

	ldi 	mpr, high(53817)
	sts	TCNT1H, mpr		; TCNT1 = $48E5 = 18661
	ldi 	mpr, low(53817)		; Write high first
	sts	TCNT1L, mpr

	ldi	mpr, 0b01110000
	mov	hold, mpr
	out 	PORTB, hold
	
	; load led then wait 1.5 sec (2)
CLoop2:
	
	sbrc	ready, 1		; if ready is 2 then game start!
	RJMP 	GS
					; else loop
	sbis	TIFR1, 0		; TOV1 set?
	rjmp	CLoop2			; 1.5 sec wait


	sbi	$16, 0		; clear tov in TIFR1

	ldi 	mpr, high(53817)
	sts	TCNT1H, mpr		; TCNT1 = $48E5 = 18661
	ldi 	mpr, low(53817)		; Write high first
	sts	TCNT1L, mpr
	
	ldi	mpr, 0b00110000
	mov 	hold, mpr
	out 	PORTB, hold

	; load led then wait 1.5 sec (3)
CLoop3:

	sbrc	ready, 1		; if ready is 2 then game start!
	RJMP 	GS
					; else, loop
	sbis	TIFR1, 0		; TOV1 set?
	rjmp	CLoop3			; 1.5 sec wait


	sbi	$16, 0		; clear tov in TIFR1

	ldi 	mpr, high(53817)
	sts	TCNT1H, mpr		; TCNT1 = $48E5 = 18661
	ldi 	mpr, low(53817)		; Write high first
	sts	TCNT1L, mpr

	ldi	mpr, 0b00010000
	mov	hold, mpr
	out 	PORTB, hold
	

CLoop4:	

	
	sbrc	ready, 1		; if ready is 2 then game start!
	RJMP 	GS
					; else, loop
	sbis	TIFR1, 0		; TOV1 set?
	rjmp	CLoop4			; 1.5 sec wait


	ldi	mpr, 0b000000000
	mov	hold, mpr
	out 	PORTB, hold
	
	sbrc	ready, 2		; 
	RJMP	Transmitter		; ready is 4 so Transmit my choice
					; wait for receive to take over
	pop		r17
	pop     mpr
	sbrs	ready, 1		; ready isn't 2, meaning no gamestart yet, 
	RJMP	MAIN			; so restart program


;-----------------------------------------------------------
; Func:PmemDmemWelcome
; Desc:Loads opening statement to LCD
;-----------------------------------------------------------
PmemDmemWelcome:	; Begin a function with a label

		push count1				; Lines Via Stack
		rcall LCDClr
		ldi count1, 2*(Plea_START-Wel_START); 
		ldi yl, $00
		ldi yh, $01
		ldi zh, (high(2*Wel_START))
		ldi zl, (low(2*Wel_START))
		L1:
		lpm mpr, z+
		st y+, mpr
		dec count1
		BRNE L1

		ldi count, 2*(Ready_START-Plea_START)
		ldi yl, $10
		ldi yh, $01
		ldi zh, (high(2*Plea_START))
		ldi zl, (low(2*Plea_START))
		L2:
		lpm mpr, z+
		st y+, mpr
		dec count1
		BRNE L2
		
		rcall LCDWrite

		pop count1 ; Reload for Counting Hits		

		ret	

;-----------------------------------------------------------
; Func:PmemDmemReady
; Desc:Loads opening statement to LCD
;-----------------------------------------------------------
PmemDmemReady:	; Begin a function with a label

		push count1				; Lines Via Stack
		rcall LCDClr
		ldi count1, 2*(For_START-Ready_START); 
		ldi yl, $00
		ldi yh, $01
		ldi zh, (high(2*Ready_START))
		ldi zl, (low(2*Ready_START))
		L3:
		lpm mpr, z+
		st y+, mpr
		dec count1
		BRNE L3

		ldi count1, 2*(Start_START-For_START)
		ldi yl, $10
		ldi yh, $01
		ldi zh, (high(2*For_START))
		ldi zl, (low(2*For_START))
		L4:
		lpm mpr, z+
		st y+, mpr
		dec count1
		BRNE L4

		rcall LCDWrite
		pop count1 ; Reload for Counting Hits		

		ret	

;-----------------------------------------------------------
; Func:PmemDmemGS
; Desc:Loads opening statement to LCD

;-----------------------------------------------------------
PmemDmemGS:	; Begin a function with a label

		push count1				; Lines Via Stack
		rcall LCDClr
		ldi count1, 2*(Lost_START-Start_START); 
		ldi yl, $00
		ldi yh, $01
		ldi zh, (high(2*Start_START))
		ldi zl, (low(2*Start_START))
		L5:
		lpm mpr, z+
		st y+, mpr
		dec count1
		BRNE L5


		rcall LCDWrLn1
		pop count1 ; Reload for Counting Hits		

		ret	

;-----------------------------------------------------------
; Func: WriteRock
; Desc: ClrLine2 Then Write Rock

;-----------------------------------------------------------
WriteRock:	; Begin a function with a label

		push count1				; Lines Via Stack
		rcall LCDClrLn2
		ldi count1, 2*(Scissors_START-Rock_START); 
		ldi yl, $10
		ldi yh, $01
		ldi zh, (high(2*Rock_START))
		ldi zl, (low(2*Rock_START))
		L6:
		lpm mpr, z+
		st y+, mpr
		dec count1
		BRNE L6


		rcall LCDWrLn2
		pop count1 ; Reload for Counting Hits		

		ret	

;-----------------------------------------------------------
; Func: WriteScissors
; Desc: ClrLine2 Then Write Sciz

;-----------------------------------------------------------
WriteScissors:	; Begin a function with a label

		push count1				; Lines Via Stack
		rcall LCDClrLn2
		ldi count1, 2*(Paper_START-Scissors_START); 
		ldi yl, $10
		ldi yh, $01
		ldi zh, (high(2*Scissors_START))
		ldi zl, (low(2*Scissors_START))
		L7:
		lpm mpr, z+
		st y+, mpr
		dec count1
		BRNE L7


		rcall LCDWrLn2
		pop count1 ; Reload for Counting Hits	
	

		ret	

;-----------------------------------------------------------
; Func: WritePaper
; Desc: ClrLine2 Then Write Paper

;-----------------------------------------------------------
WritePaper:	; Begin a function with a label

		push count1				; Lines Via Stack
		rcall LCDClrLn2
		ldi count1, 2*(Paper_END-Paper_START); 
		ldi yl, $10
		ldi yh, $01
		ldi zh, (high(2*Paper_START))
		ldi zl, (low(2*Paper_START))
		L8:
		lpm mpr, z+
		st y+, mpr
		dec count1
		BRNE L8


		rcall LCDWrLn2
		pop count1 ; Reload for Counting Hits	
	

		ret	

;-----------------------------------------------------------
; Func: WriteLost
; Desc: ClrLine1 Then Write You Lost!

;-----------------------------------------------------------
WriteLost:	; Begin a function with a label

		push count1				; Lines Via Stack
		rcall LCDClrLn1
		ldi count1, 2*(Draw_START-Lost_START); 
		ldi yl, $10
		ldi yh, $01
		ldi zh, (high(2*Lost_START))
		ldi zl, (low(2*Lost_START))
		L9:
		lpm mpr, z+
		st y+, mpr
		dec count1
		BRNE L9


		rcall LCDWrLn1
		pop count1 ; Reload for Counting Hits		

		ret	

;-----------------------------------------------------------
; Func: WriteDraw
; Desc: ClrLine1 Then Write You Lost!

;-----------------------------------------------------------
WriteDraw:	; Begin a function with a label

		push count1				; Lines Via Stack
		rcall LCDClrLn1
		ldi count1, 2*(Won_START-Draw_START); 
		ldi yl, $10
		ldi yh, $01
		ldi zh, (high(2*Draw_START))
		ldi zl, (low(2*Draw_START))
		L10:
		lpm mpr, z+
		st y+, mpr
		dec count1
		BRNE L10


		rcall LCDWrLn1
		pop count1 ; Reload for Counting Hits		

		ret	

;-----------------------------------------------------------
; Func: WriteWon
; Desc: ClrLine1 Then Write You Lost!

;-----------------------------------------------------------
WriteWon:	; Begin a function with a label

		push count1				; Lines Via Stack
		rcall LCDClrLn1
		ldi count1, 2*(Won_END-Won_START); 
		ldi yl, $10
		ldi yh, $01
		ldi zh, (high(2*Won_START))
		ldi zl, (low(2*Won_START))
		L11:
		lpm mpr, z+
		st y+, mpr
		dec count1
		BRNE L11


		rcall LCDWrLn1
		pop count1 ; Reload for Counting Hits		

		ret	

		
;***********************************************************
;*	Stored Program Data
;***********************************************************

;-----------------------------------------------------------
; An example of storing a string. Note the labels before and
; after the .DB directive; these can help to access the data
;-----------------------------------------------------------
.org 	$0600
Wel_START:
    .DB		"Welcome!"		; Declaring data in ProgMem
Plea_START:
    .DB		"Please press PD7"
Ready_START:
    .DB 		"Ready. Waiting  "
For_START:
    .DB		"for the opponent"
Start_START: 
    .DB		"Game Start"
Lost_START:
    .DB		"You Lost"
Draw_START:
    .DB		"Draw"
Won_START:
    .DB		"You Won!"
Won_END:

.org	$0700
Rock_START:
    .DB		"Rock"
Scissors_START:
    .DB		"Scissors"
Paper_START:
    .DB		"Paper "
Paper_END:

;***********************************************************
;*	Additional Program Includes
;***********************************************************
.include "LCDDriver.asm"		; Include the LCD Driver
