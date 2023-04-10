/*
This code will cause a TekBot connected to the AVR board to
move forward and when it touches an obstacle, it will reverse
and turn away from the obstacle and resume forward motion.

PORT MAP
Port B, Pin 5 -> Output -> Right Motor Enable
Port B, Pin 4 -> Output -> Right Motor Direction
Port B, Pin 6 -> Output -> Left Motor Enable
Port B, Pin 7 -> Output -> Left Motor Direction
Port D, Pin 5 -> Input -> Left Whisker
Port D, Pin 4 -> Input -> Right Whisker
*/

#define F_CPU 16000000
#include <avr/io.h>
#include <util/delay.h>
#include <stdio.h>

int main(void)
{
      DDRD = 0b00000000;      // configure port D pins for input (whiskers)
      DDRB = 0b11110000;      // configure Port B pins for input/output (motors)
      PORTB = 0b11110000;     // set initial value for Port B outputs
      PORTD = 0b00110000;     // set initial value for Port D
                              // (initially, disable both motors)

      /* Copy pasted from lab slides for reference
      uint8_t mpr = PIND & 0b00110000; //extract only 4,5th bit
      If (mpr == 0b00100000) //check if the right whisker is hit
      */

while (1) // loop forever
      {
	// Your code goes here

      uint8_t mpr = PIND & 0b00110000; //mask everything except whisker bits on PIND

      if((mpr == 0b00100000) & (mpr == 0b00010000)) { //read whats on PIND
             PORTB = 0b00000000;     // move backward
              _delay_ms(1000);        // wait for 1 s
             PORTB = 0b10000000;     // turn right
             _delay_ms(1000);        // wait for 1 s
             PORTB = 0b10010000;     // make TekBot move forward
      }
      if(mpr == 0b00010000) {
             PORTB = 0b00000000;     // move backward
              _delay_ms(1000);        // wait for 1 s
             PORTB = 0b00010000;     // turn left
             _delay_ms(1000);        // wait for 1 s
             PORTB = 0b10010000;     // make TekBot move forward
      }
      if(mpr == 0b00100000) {
             PORTB = 0b00000000;     // move backward
              _delay_ms(1000);        // wait for 1 s
             PORTB = 0b10000000;     // turn right
             _delay_ms(1000);        // wait for 1 s
             PORTB = 0b10010000;     // make TekBot move forward
      }

      
      }
}
