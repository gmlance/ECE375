;***********************************************************
;*	This is the skeleton file for Lab 4 of ECE 375
;*
;*	 Author: Grant Lance
;*	   Date: 11/4/2022
;*
;***********************************************************

.include "m128def.inc"			; Include definition file

;***********************************************************
;*	Internal Register Definitions and Constants
;***********************************************************
.def	mpr = r16				; Multipurpose register
.def	rlo = r0				; Low byte of MUL result
.def	rhi = r1				; High byte of MUL result
.def	zero = r2				; Zero register, set to zero in INIT, useful for calculations
.def	A = r3					; A variable
.def	B = r4					; Another variable

.def	oloop = r17				; Outer Loop Counter
.def	iloop = r18				; Inner Loop Counter


;***********************************************************
;*	Start of Code Segment
;***********************************************************
.cseg							; Beginning of code segment

;-----------------------------------------------------------
; Interrupt Vectors
;-----------------------------------------------------------
.org	$0000					; Beginning of IVs
 		rjmp 	INIT			; Reset interrupt

.org	$0056					; End of Interrupt Vectors

;-----------------------------------------------------------
; Program Initialization
;-----------------------------------------------------------
INIT:
    ; Initialize the Stack Pointer (VERY IMPORTANT!!!!)
		ldi		mpr, low(RAMEND)
		out		SPL, mpr		; Load SPL with low byte of RAMEND
		ldi		mpr, high(RAMEND)
		out		SPH, mpr		; Load SPH with high byte of RAMEND

		clr		zero			; Set the zero register to zero, maintain
										; these semantics, meaning, don't
										; load anything else into it.

;-----------------------------------------------------------
; Main Program
;-----------------------------------------------------------
MAIN:							; The Main program

		rcall LOAD_ADD16; Call function to load ADD16 operands
		nop ; Check load ADD16 operands (Set Break point here #1)

		rcall ADD16; Call ADD16 function to display its results (calculate FCBA + FFFF)
		nop ; Check ADD16 result (Set Break point here #2)


		rcall LOAD_SUB16; Call function to load SUB16 operands
		nop ; Check load SUB16 operands (Set Break point here #3)

		rcall SUB16; Call SUB16 function to display its results (calculate FCB9 - E420)
		nop ; Check SUB16 result (Set Break point here #4)


		rcall LOAD_MUL24; Call function to load MUL24 operands
		nop ; Check load MUL24 operands (Set Break point here #5)
		rcall LOAD_MUL24_LEAD0COUNT; Call function to copy MUL24 operands
		rcall MUL24_LEAD0COUNT; count leading zeros (if any)
		rcall MUL24; Call MUL24 function to display its results (calculate FFFFFF * FFFFFF)
		rcall MUL24_SHIFT; apply logical shift (if any)
		nop ; Check MUL24 result (Set Break point here #6)

		rcall COMPOUND; Setup the COMPOUND function direct test
		nop ; Check load COMPOUND operands (Set Break point here #7)

		; Call the COMPOUND function
		nop ; Check COMPOUND result (Set Break point here #8)

DONE:	rjmp	DONE			; Create an infinite while loop to signify the
								; end of the program.

;***********************************************************
;*	Functions and Subroutines
;***********************************************************

;-----------------------------------------------------------
; Func: ADD16
; Desc: Adds two 16-bit numbers and generates a 24-bit number
;       where the high byte of the result contains the carry
;       out bit. Takes from memory low to high. Stores high to low
;-----------------------------------------------------------
ADD16:
		; Load beginning address of first operand into X

		push	r15
		push	r16
		push	r17
		push	r18
		push	r19

		ldi		XL, low(ADD16_OP1)	; Load low byte of address
		ldi		XH, high(ADD16_OP1)	; Load high byte of address

		; Load beginning address of second operand into Y
		ldi		YL, low(ADD16_OP2)
		ldi		YH, high(ADD16_OP2)

		; Load beginning address of result into Z
		ldi		ZL, low(ADD16_Result)
		ldi		ZH, high(ADD16_Result)

		; Execute the function

        ld		r15, X+ ;lower byte of operand A
        ld		r16, X ;upper byte of operand A
        ld		r17, Y+ ;lower byte of operand B
        ld		r18, Y ;upper byte of operand B

		clr		r19

		add		r15, r17
		adc		r16, r18
		adc		r19, r19
		nop
		st		Z+, r19
		st		Z+, r15
		st		Z, r16

		pop		r19
		pop		r18
		pop		r17
		pop		r16
		pop		r15

		ret						; End a function with RET

;-----------------------------------------------------------
; Func: SUB16
; Desc: Subtracts two 16-bit numbers and generates a 16-bit
;       result. Always subtracts from the bigger values. 
;		Subtracts value in memory stored high to low. Stores result high to low
;-----------------------------------------------------------
SUB16:
		push	r15
		push	r16
		push	r17
		push	r18
		push	r19
		; Execute the function here
		; Load beginning address of first operand into X
		ldi		XL, low(SUB16_OP1)	; Load low byte of address
		ldi		XH, high(SUB16_OP1)	; Load high byte of address

		; Load beginning address of second operand into Y
		ldi		YL, low(SUB16_OP2)
		ldi		YH, high(SUB16_OP2)

		; Load beginning address of result into Z
		ldi		ZL, low(SUB16_Result)
		ldi		ZH, high(SUB16_Result)

        ld		r15, X+ ;upper byte of operand B
        ld		r16, X ;lower byte of operand B
        ld		r17, Y+ ;upper byte of operand A
        ld		r18, Y ;lower byte of operand A

		; compare R15:R16 and R17:R18
		clc
		cp		r18, r16
		cpc		r17, r15 
		brcc	greateq ;operand A is greater than or equal to operand B
        nop
        ;operand B is greater than operand A
			SUB		r16, r18;subtract lower bytes or operand LOW(B) - LOW(A)
			SBC		r15, r17;subtrace upper bytes with carry/borrow from upper byte
			;store result into correct data memory space
			st		Z+, r15
			st		Z, r16
			rjmp end_sub


greateq: ;A >= B
        	SUB		r18, r16 ;subtract lower bytes or operand LOW(A) - LOW(B)
			SBC		r17, r15 ;subtrace upper bytes with carry/borrow from upper byte
			;store result into correct data memory space
			st		Z+, r18
			st		Z, r17
			nop
        	rjmp end_sub
			

end_sub: 
		pop		r19
		pop		r18
		pop		r17
		pop		r16
		pop		r15
		ret						; End a function with RET
;-----------------------------------------------------------
; Func: MUL24
; Desc: Multiplies two 24-bit numbers and generates a 48-bit
;       result.
;		Takes values from memory stored high to low. Stores low to high
;				 A2 A1
;			*	 B2 B1
;		-----------------
;				H11 L11 (A1 * B1 = H11:L11)
;			H21 L21 ___ (A2 * B1 = H21:L21, but properly aligned)
;			H12 L12 ___ (A1 * B2 = H12:L12, but properly aligned)
;+		H22 L22 ___ ___ (A2 * B2 = H22:L22, but properly aligned)
;		-----------------
;-----------------------------------------------------------
MUL24:
		push r15
		push r16
		push r17
		push r18
		push r19
		push r20
		push r21

		ldi YL, low(MUL24_OP1)
        ldi YH, high(MUL24_OP1)

		ldi XL, low(MUL24_OP2)
        ldi XH, high(MUL24_OP2)

		ldi ZL, low(MUL24_Result)
        ldi ZH, high(MUL24_Result)

		clr zero	; make sure zero is 0

		ld	r15, Y+; load low byte of op1
		ld	r16, X+; load low byte of op2
		mul r15, r16; multiply
		st	Z+, r0; store 32 bit answer low low into result
		mov	r17, r1; store carry amount to add to
		ld	r16, X+; load mid byte of op2
		mul r15, r16; multiply
		add r17, r0; add low from mul to carry amount to add
		mov	r18, r1; store high to next place carry amount to add
		ld	r16, X+; load high byte of op2
		mul r15, r16; multiply
		add r18, r0; add low and possible carry to its place carry amount
		mov	r19, r1; store high to its place carry amount
		adc r19, zero; add possible carry to r19

		nop
		ldi XL, low(MUL24_OP2); reset x
        ldi XH, high(MUL24_OP2)
		ld  r15, Y+; load mid byte of op1
		ld	r16, X+; load low byte of op2
		mul r15, r16
		add r17, r0; add low to its place r17
		st`	Z+, r17; done with r17 store and clear
		clr r17    ; r17 will now be used for next highest place value
		adc r18, r1; add with carry the high to its place
		adc r19, zero;
		ld  r16, X+; load mid byte of op2
		mul r15, r16
		add r18, r0; add the low to r18
		adc r19, r1; continue carry r20 should be at most (decimal) 2
		;no need to move carry all the way through. r19 should be empty
		adc r20, zero; add the high to r19
		ld  r16, X+
		mul r15, r16
		add r19, r0; add low to r19
		adc r20, r1; add high to r1 and move carry through

		nop
		ldi XL, low(MUL24_OP2); reset x
        ldi XH, high(MUL24_OP2)
		ld  r15, Y+; load high byte of op1
		ld	r16, X+; load low byte of op2
		mul r15, r16
		add r18, r0; add to r18 and no move carry through. just happened above
		st  Z+, r18; store r18. no clear, wont be used again
		adc r19, r1; add the carry here and high from mul
		adc r20, zero; add possible carry here. continue carry through
		adc r17, zero;
		ld  r16, X+; load mid byte of op2
		mul r15, r16
		add r19, r0; add low to r19. move carry through
		st  Z+, r19; store r19. done with it
		adc r20, r1; add high and continue move carry
		adc r17, zero;
		ld  r16, X+
		mul r15, r16
		add r20, r0; add low to r20 and move carry through
		st  Z+, r20
		adc r17, r1; max value cannot pass this bit. store and done
		st	Z, r17


		pop r21
		pop r20
		pop r19
		pop r18
		pop r17
		pop r16
		pop r15

		ret						; End a function with RET
;-----------------------------------------------------------
; Func: MUL24_LEAD0COUNT
; Desc: Counts leading zeros to determine byte shifts required for MUL24.
;-----------------------------------------------------------
MUL24_LEAD0COUNT:

		push r15
		push r16
		push r17
		push r18
		push r19
		push r20
		push r21

		ldi XH, high(MUL24_LEAD0COUNT_OP1); load operands to X and Y
		ldi XL, low(MUL24_LEAD0COUNT_OP1)

		ldi YH, high(MUL24_LEAD0COUNT_OP2)
		ldi	YL, low(MUL24_LEAD0COUNT_OP2)

		ldi ZH, high(MUL24_LEAD0_COUNT)
		ldi ZL, low(MUL24_LEAD0_COUNT)

		clr zero;	make sure zero is 0
		ldi r21, 5; load count
		leadcountloop:
			ld r15, X+
			cp r15, zero
			breq addonebranchA; compare first byte to zero. branch and increment count if equal
			rjmp secondoperand; if there are no leading zeros jump to second operand
		
			addonebranchA:
				inc r20; count leading zero from first operand
				dec r21; decrement loop count
				rjmp leadcountloop;

			secondoperand:
				ld r15, Y+
				cp r15, zero
				breq addonebranchB; compare first byte to zero. branch and increment count if equal
				rjmp endleadcount; if we get here no more leading zeros. jump to end

				addonebranchB:
					inc r20; count leading zero from second operand
					dec	r21; decrement loop count
					brne secondoperand; continue loop 
		endleadcount:
		st Z, r20; store result to memory
		pop r21
		pop r20
		pop r19
		pop r18
		pop r17
		pop r16
		pop r15

		ret						; End a function with RET
;-----------------------------------------------------------
; Func: MUL24_SHIFT
; Desc: Applies logical shift based on the count of leading zeros
;-----------------------------------------------------------
MUL24_SHIFT:

		push r15; shift count holder
		push r16; mpr
		push r17; cycle count holder
		push r18; shift cycle counter
		push r19; copy of cycle count
		push r20
		push r21

		ldi ZH, high(MUL24_LEAD0_COUNT)
		ldi ZL, low(MUL24_LEAD0_COUNT)

		clr zero; make sure zero is 0.
		ld r15, Z; load r15 with shift count (same as leading zero count)

		cp r15, zero
		breq endshift; no shift required. exit

		clr r17; make sure r17 is 0
		ldi r18, 6; load r18 with cycle counter
		ld r19, Z; copy of shift count. needed for cycle count
		sub r18, r19; subtract total possible length from shift count for cycle counter
		mov r19, r18; copy of cycle count for replacing zeros at the end

		byteshift:
				ldi ZH, high(MUL24_Result)
				ldi	ZL, low(MUL24_Result)
				
				add ZL, r15; add the shift to low of address
				add ZL, r17; add the cycle count to address low
				ld  r16, Z; load r16 with byte to shift

				ldi ZH, high(MUL24_Result)
				ldi	ZL, low(MUL24_Result)

				add ZL, r17; add the cycle count to address low
				st  Z, r16

				inc r17
				dec r18
				brne byteshift; increment cycle count. decrement cycle counter. break to end if counter is 0.
				ldi ZH, high(MUL24_LEAD0_COUNT)
				ldi ZL, low(MUL24_LEAD0_COUNT)
				ld r18, Z; reset cycle count for replace zeros

				ldi ZH, high(MUL24_Result)
				ldi	ZL, low(MUL24_Result)
				add ZL, r19; point Z to the correct place in memory (number of shifts made forward)

		replacezeros:
				st  Z+, zero
				dec r18
				brne replacezeros

		endshift:
			pop r21
			pop r20
			pop r19
			pop r18
			pop r17
			pop r16
			pop r15

			ret						; End a function with RET


;-----------------------------------------------------------
; Func: COMPOUND
; Desc: Computes the compound expression ((G - H) + I)^2
;       by making use of SUB16, ADD16, and MUL24.
;
;       D, E, and F are declared in program memory, and must
;       be moved into data memory for use as input operands.
;
;       All result bytes should be cleared before beginning.
;-----------------------------------------------------------
COMPOUND:

		rcall LOAD_SUBCOM; Setup SUB16 with operands G and H
		rcall SUB16; Perform subtraction to calculate G - H
		nop

		rcall LOAD_ADDCOM; Setup the ADD16 function with SUB16 result and operand I
		rcall ADD16; Perform addition next to calculate (G - H) + I
		nop

		rcall LOAD_MULCOM; Setup the MUL24 function with ADD16 result as both operands
		rcall LOAD_MUL24_LEAD0COUNT; Call function to copy MUL24 operands
		rcall MUL24_LEAD0COUNT; count leading zeros (if any)
		rcall MUL24; Perform multiplication to calculate ((G - H) + I)^2
		rcall MUL24_SHIFT; apply logical shift (if any)
		nop

		ret						; End a function with RET

;-----------------------------------------------------------
; Func: MUL16
; Desc: An example function that multiplies two 16-bit numbers
;       A - Operand A is gathered from address $0101:$0100
;       B - Operand B is gathered from address $0103:$0102
;       Res - Result is stored in address
;             $0107:$0106:$0105:$0104
;       You will need to make sure that Res is cleared before
;       calling this function.
;-----------------------------------------------------------
MUL16:
		push 	A				; Save A register
		push	B				; Save B register
		push	rhi				; Save rhi register
		push	rlo				; Save rlo register
		push	zero			; Save zero register
		push	XH				; Save X-ptr
		push	XL
		push	YH				; Save Y-ptr
		push	YL
		push	ZH				; Save Z-ptr
		push	ZL
		push	oloop			; Save counters
		push	iloop

		clr		zero			; Maintain zero semantics

		; Set Y to beginning address of B
		ldi		YL, low(addrB)	; Load low byte
		ldi		YH, high(addrB)	; Load high byte

		; Set Z to begginning address of resulting Product
		ldi		ZL, low(LAddrP)	; Load low byte
		ldi		ZH, high(LAddrP); Load high byte

		; Begin outer for loop
		ldi		oloop, 2		; Load counter
MUL16_OLOOP:
		; Set X to beginning address of A
		ldi		XL, low(addrA)	; Load low byte
		ldi		XH, high(addrA)	; Load high byte

		; Begin inner for loop
		ldi		iloop, 2		; Load counter
MUL16_ILOOP:
		ld		A, X+			; Get byte of A operand
		ld		B, Y			; Get byte of B operand
		mul		A,B				; Multiply A and B
		ld		A, Z+			; Get a result byte from memory
		ld		B, Z+			; Get the next result byte from memory
		add		rlo, A			; rlo <= rlo + A
		adc		rhi, B			; rhi <= rhi + B + carry
		ld		A, Z			; Get a third byte from the result
		adc		A, zero			; Add carry to A
		st		Z, A			; Store third byte to memory
		st		-Z, rhi			; Store second byte to memory
		st		-Z, rlo			; Store first byte to memory
		adiw	ZH:ZL, 1		; Z <= Z + 1
		dec		iloop			; Decrement counter
		brne	MUL16_ILOOP		; Loop if iLoop != 0
		; End inner for loop

		sbiw	ZH:ZL, 1		; Z <= Z - 1
		adiw	YH:YL, 1		; Y <= Y + 1
		dec		oloop			; Decrement counter
		brne	MUL16_OLOOP		; Loop if oLoop != 0
		; End outer for loop

		pop		iloop			; Restore all registers in reverves order
		pop		oloop
		pop		ZL
		pop		ZH
		pop		YL
		pop		YH
		pop		XL
		pop		XH
		pop		zero
		pop		rlo
		pop		rhi
		pop		B
		pop		A
		ret						; End a function with RET

;-----------------------------------------------------------
; Func: LOAD_ADD16
; Desc: load ADD16 operands
;-----------------------------------------------------------
LOAD_ADD16:	

		push r15
		push r16
		push r17
		push r18
								
		; Execute the function here
		ldi ZH, high(OperandA<<1)
		ldi ZL, low(OperandA<<1)

		lpm r15, Z+
		lpm r16, Z+

		ldi ZH, high(ADD16_OP1)
		ldi ZL, low(ADD16_OP1)

		st Z+, r15
		st Z, r16

		ldi ZH, high(OperandB<<1)
		ldi ZL, low(OperandB<<1)

		lpm r17, Z+
		lpm r18, Z+

		ldi ZH, high(ADD16_OP2)
		ldi ZL, low(ADD16_OP2)

		st Z+, r17
		st Z, r18

		pop r18
		pop r17
		pop r16
		pop r15

		ret							; End a function with RET


;-----------------------------------------------------------
; Func: LOAD_SUB16
; Desc: load SUB16 operands
;-----------------------------------------------------------
LOAD_SUB16:	

		push r15
		push r16
		push r17
		push r18						
		; Execute the function here
		ldi ZH, high(OperandC<<1)
		ldi ZL, low(OperandC<<1)

		lpm r15, Z+
		lpm r16, Z+

		ldi ZH, high(SUB16_OP1)
		ldi ZL, low(SUB16_OP1)

		st Z+, r16
		st Z, r15

		ldi ZH, high(OperandD<<1)
		ldi ZL, low(OperandD<<1)

		lpm r17, Z+
		lpm r18, Z+

		ldi ZH, high(SUB16_OP2)
		ldi ZL, low(SUB16_OP2)

		st Z+, r18
		st Z, r17
		pop r18
		pop r17
		pop r16
		pop r15
		ret							; End a function with RET
;-----------------------------------------------------------
; Func: LOAD_SUBCOM
; Desc: load SUB16 operands with Operand G and H
;-----------------------------------------------------------
LOAD_SUBCOM:	

		push r15
		push r16
		push r17
		push r18						
		; Execute the function here
		ldi ZH, high(OperandG<<1)
		ldi ZL, low(OperandG<<1)

		lpm r15, Z+
		lpm r16, Z+

		ldi ZH, high(SUB16_OP1)
		ldi ZL, low(SUB16_OP1)

		st Z+, r16
		st Z, r15

		ldi ZH, high(OperandH<<1)
		ldi ZL, low(OperandH<<1)

		lpm r17, Z+
		lpm r18, Z+

		ldi ZH, high(SUB16_OP2)
		ldi ZL, low(SUB16_OP2)

		st Z+, r18
		st Z, r17
		pop r18
		pop r17
		pop r16
		pop r15
		ret						; End a function with RET
;-----------------------------------------------------------
; Func: LOAD_ADDCOM
; Desc: load ADD16 operands with result from SUB16 and Operand I
;-----------------------------------------------------------
LOAD_ADDCOM:	

		push r15
		push r16
		push r17
		push r18						
		; Execute the function here
		ldi ZH, high(OperandI<<1)
		ldi ZL, low(OperandI<<1)

		lpm r15, Z+
		lpm r16, Z+

		ldi ZH, high(ADD16_OP1)
		ldi ZL, low(ADD16_OP1)

		st Z+, r15
		st Z, r16

		ldi ZH, high(SUB16_Result)
		ldi ZL, low(SUB16_Result)

		ld r17, Z+
		ld r18, Z+

		ldi ZH, high(ADD16_OP2)
		ldi ZL, low(ADD16_OP2)

		st Z+, r18
		st Z, r17

		pop r18
		pop r17
		pop r16
		pop r15
		ret							; End a function with RET
;-----------------------------------------------------------
; Func: LOAD_MULCOM
; Desc: load MUL24 operands with compound results (ADD16 results)
;-----------------------------------------------------------
LOAD_MULCOM:

		push r15
		push r16
		push r17
		push r18
		push r19
		push r20							
		; Execute the function here
		ldi ZH, high(ADD16_Result)
		ldi ZL, low(ADD16_Result)

		ld r15, Z+
		ld r16, Z+
		ld r17, Z

		ldi ZH, high(MUL24_OP1)
		ldi ZL, low(MUL24_OP1)

		st Z+, r15
		st Z+, r16
		st Z, r17

		ldi ZH, high(ADD16_Result)
		ldi ZL, low(ADD16_Result)

		ld  r18, Z+
		ld  r19, Z+
		ld  r20, Z

		ldi ZH, high(MUL24_OP2)
		ldi ZL, low(MUL24_OP2)

		st Z+, r18
		st Z+, r19
		st Z, r20

		pop r20
		pop r19
		pop r18
		pop r17
		pop r16
		pop r15

		ret	
;-----------------------------------------------------------
; Func: LOAD_MUL24
; Desc: load MUL24 operands
;-----------------------------------------------------------
LOAD_MUL24:

		push r15
		push r16
		push r17
		push r18
		push r19
		push r20							
		; Execute the function here
		ldi ZH, high(OperandE1<<1)
		ldi ZL, low(OperandE1<<1)

		lpm r15, Z+
		lpm r16, Z+
		lpm r17, Z

		ldi ZH, high(MUL24_OP1)
		ldi ZL, low(MUL24_OP1)

		st Z+, r15
		st Z+, r16
		st Z, r17

		ldi ZH, high(OperandF1<<1)
		ldi ZL, low(OperandF1<<1)

		lpm r18, Z+
		lpm r19, Z+
		lpm r20, Z

		ldi ZH, high(MUL24_OP2)
		ldi ZL, low(MUL24_OP2)

		st Z+, r18
		st Z+, r19
		st Z, r20

		pop r20
		pop r19
		pop r18
		pop r17
		pop r16
		pop r15

		ret							; End a function with RET

;-----------------------------------------------------------
; Func: LOAD_MUL24_LEAD0COUNT
; Desc: copy MUL24 operands. stores high to low
;-----------------------------------------------------------
LOAD_MUL24_LEAD0COUNT:

		push r15
		push r16
		push r17
		push r18
		push r19
		push r20							
		; Execute the function here
		ldi ZH, high(MUL24_OP1)
		ldi ZL, low(MUL24_OP1)

		ld r15, Z+
		ld r16, Z+
		ld r17, Z

		ldi ZH, high(MUL24_LEAD0COUNT_OP1)
		ldi ZL, low(MUL24_LEAD0COUNT_OP1)

		st Z+, r15
		st Z+, r16
		st Z, r17

		ldi ZH, high(MUL24_OP2)
		ldi ZL, low(MUL24_OP2)

		ld  r18, Z+
		ld  r19, Z+
		ld  r20, Z

		ldi ZH, high(MUL24_LEAD0COUNT_OP2)
		ldi ZL, low(MUL24_LEAD0COUNT_OP2)

		st Z+, r18
		st Z+, r19
		st Z, r20

		pop r20
		pop r19
		pop r18
		pop r17
		pop r16
		pop r15

		ret	
;***********************************************************
;*	Stored Program Data
;*	Do not  section.
;***********************************************************
; ADD16 operands
OperandA:
	.DW 0xFCBA
OperandB:
	.DW 0xFFFF

; SUB16 operands
OperandC:
	.DW 0XFCB9
OperandD:
	.DW 0XE420

; MUL24 operands
OperandE1:
	.DW	0XFFFF
OperandE2:
	.DW	0X00FF
OperandF1:
	.DW	0XFFFF
OperandF2:
	.DW	0X00FF

; Compoud operands
OperandG:
	.DW	0xFCBA				; test value for operand G
OperandH:
	.DW	0x2022				; test value for operand H
OperandI:
	.DW	0x21BB				; test value for operand I

;***********************************************************
;*	Data Memory Allocation
;***********************************************************
.dseg
.org	$0100				; data memory allocation for MUL16 example
addrA:	.byte 2
addrB:	.byte 2
LAddrP:	.byte 4

; Below is an example of data memory allocation for ADD16.
; Consider using something similar for SUB16 and MUL24.
.org	$0110				; data memory allocation for operands
ADD16_OP1:
		.byte 2				; allocate two bytes for first operand of ADD16
ADD16_OP2:
		.byte 2				; allocate two bytes for second operand of ADD16

.org	$0115				; data memory allocation for results
ADD16_Result:
		.byte 3				; allocate three bytes for ADD16 result

.org	$0119				; data memory allocation for operands
SUB16_OP1:
		.byte 2				; allocate two bytes for first operand of SUB16
SUB16_OP2:
		.byte 2				; allocate two bytes for second operand of SUB16

.org	$011e				; data memory allocation for results
SUB16_Result:
		.byte 2				; allocate three bytes for SUB16 result

.org	$0121
MUL24_OP1:
		.byte 3				; allocate two bytes for first operand of MUL24
MUL24_OP2:
		.byte 3				; allocate two bytes for second operand of MUL24

.org	$0128
MUL24_LEAD0COUNT_OP1:
		.byte 3				; allocate two bytes for first operand of MUL24_LEAD0COUNT
MUL24_LEAD0COUNT_OP2:
		.byte 3				; allocate two bytes for second operand of MUL24_LEAD0COUNT

.org	$012f				; data memory allocation for results
MUL24_LEAD0_COUNT:
		.byte 1
.org	$0131
MUL24_Result:
		.byte 6				; allocate three bytes for MUL24 result
;***********************************************************
;*	Additional Program Includes
;***********************************************************
; There are no additional file includes for this program