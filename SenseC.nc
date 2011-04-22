/*
 * Copyright (c) 2006, Technische Universitaet Berlin
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * - Redistributions of source code must retain the above copyright notice,
 *   this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the distribution.
 * - Neither the name of the Technische Universitaet Berlin nor the names
 *   of its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 * TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
 * OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
 * USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * - Revision -------------------------------------------------------------
 * $Revision: 1.4 $
 * $Date: 2006/12/12 18:22:49 $
 * @author: Jan Hauer
 * ========================================================================
 */

/**
 * 
 * Sensing demo application. See README.txt file in this directory for usage
 * instructions and have a look at tinyos-2.x/doc/html/tutorial/lesson5.html
 * for a general tutorial on sensing in TinyOS.
 *
 * @author Jan Hauer
 */

#include "Timer.h"
#include "RadioDataToLeds.h"

// enumeration of mote IDs
enum {
	MOTE0 = 0,
	MOTE1 = 1,
	MOTE2 = 2
};
  
// the mote number (either 0 or 1)
#define MY_MOTE_ID MOTE0

// sampling delays in binary milliseconds
#define SAMPLING_DELAY 250
#define BLUE_LED_SAMPLING_DELAY 1000
  
// light threshold
#define LIGHT_THRES 150
  

/** Serial Packet Code ******************************************/
#define ID_MASK 0x0F
#define LED_OFFSET 4
#define LED_MASK 0x01

uint16_t serial_pack(int radioId, bool ledOn){
	uint16_t newPacket = 0;
	newPacket |= (radioId & ID_MASK);
	newPacket |= (ledOn? (1 << LED_OFFSET) : 0);
	return newPacket;
}

int serial_getRadioId(uint16_t packet){
	return (packet & ID_MASK);
}

bool serial_getLedState(uint16_t packet){
	return ((packet >> LED_OFFSET) & LED_MASK)? TRUE : FALSE;
}
/*****************************************************************/

module SenseC
{
  uses {
    interface Boot;
    interface Leds;
    interface Receive;
    interface AMSend;
    interface SplitControl as AMControl;
    interface Packet;
    interface Timer<TMilli> as SamplingTimer;
    interface Timer<TMilli> as BlueLedTimer;
    interface Read<uint16_t>;
  }
}
implementation
{
  // current packet
  message_t packet;
  
  // mutex lock for packet operations
  bool locked = FALSE;
  
  // designates if LED should be on or not
  bool led0On = FALSE;
  bool led1On = FALSE;
  
  event void Boot.booted() {
    call AMControl.start();
  }
  
  event void AMControl.startDone(error_t err) {
    if (err == SUCCESS) {
		call SamplingTimer.startPeriodic(SAMPLING_DELAY);
		call BlueLedTimer.startPeriodic(BLUE_LED_SAMPLING_DELAY);
    }
    else {
      call AMControl.start();
    }
  }

  event void AMControl.stopDone(error_t err) {
    // do nothing
  }

  event void BlueLedTimer.fired(){
  	if (led0On && led1On) {
  		call Leds.led2On();
  	} else {
  		call Leds.led2Off();
  	}
  }

  event void SamplingTimer.fired(){
    call Read.read();
    
	// send out the local LED state to other motes
    if (locked) {return;}
    else {
      radio_data_msg_t* rcm = (radio_data_msg_t*)call Packet.getPayload(&packet, sizeof(radio_data_msg_t));
      if (rcm == NULL) {return;}

		// send different data based on which mote is configured
		if (MY_MOTE_ID == MOTE0){
      		rcm->data = serial_pack(MY_MOTE_ID, led0On);
      	} else if (MY_MOTE_ID == MOTE1){
      		rcm->data = serial_pack(MY_MOTE_ID, led1On);
      	} else {
      		rcm->data = serial_pack(MY_MOTE_ID, FALSE);
      	}
      	
      if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(radio_data_msg_t)) == SUCCESS) {
			locked = TRUE;
      }
    }
  }


  event void Read.readDone(error_t result, uint16_t data) {
    if (result == SUCCESS){
		
		// store the local LED state
    	if (data > LIGHT_THRES){
    		switch(MY_MOTE_ID){
    			case MOTE0:
    				led0On = TRUE;
    			break;
    			case MOTE1:
    				led1On = TRUE;
    			break;
    		}
    	} else {
			switch(MY_MOTE_ID){
    			case MOTE0:
    				led0On = FALSE;
    			break;
    			case MOTE1:
    				led1On = FALSE;
    			break;
    		}
    	}
    	
    	// change the state of the LED 0
    	if (led0On){
   			call Leds.led0On();
    	} else {
    		call Leds.led0Off();
    	}	
    	
    	// change the state of the LED 1
    	if (led1On){
    		call Leds.led1On();
    	} else {
    		call Leds.led1Off();
    	} 	
    }
  }
  
  
    event message_t* Receive.receive(message_t* bufPtr, void* payload, uint8_t len) {
	    if (len != sizeof(radio_data_msg_t)) {return bufPtr;}
	    else {
		    radio_data_msg_t* rcm = (radio_data_msg_t*)payload;
		       
		    // if data from mote 0
		    if (serial_getRadioId(rcm->data) == MOTE0){
		    		
		    	// If LED should be on
				if (serial_getLedState(rcm->data)){
					led0On = TRUE;
					
				// If LED should be off
				} else {
					led0On = FALSE;
				}
		    } 
		    
		    // if data from mote 1
		    else if (serial_getRadioId(rcm->data) == MOTE1){
		    
		    	// If LED should be on, turn on
		    	if (serial_getLedState(rcm->data)){
		    		led1On = TRUE;
		    		
		    	// If LED should be off, turn off
		    	} else {
		    		led1On = FALSE;
		    	}
		    }
		}
	    return bufPtr;
  	}
  
    event void AMSend.sendDone(message_t* bufPtr, error_t error) {
	    if (&packet == bufPtr) {
	      locked = FALSE;
	    }
  	}
}
