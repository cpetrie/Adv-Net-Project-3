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

#include "UserButton.h"
#include "RadioPacket.h"
#include "printf.h"

#define RECEIVER 1
#define SENDER (!RECEIVER)

#define DELAY() (512 * (1 + RECEIVER))

module RadioC
{
  uses {
    interface Boot;
    interface Leds;
	interface Get<button_state_t> as ButtonGet;
	interface Notify<button_state_t> as ButtonNotify;
    interface Receive as RadioReceive;
    interface AMSend as RadioAMSend;
    interface SplitControl as RadioAMControl;
    interface Packet as RadioPacket;
    interface Timer<TMilli> as Timer;

    interface CC2420Config as RadioConfig;
//	interface Init as RadioConfigInit;
  }
}
implementation
{
  message_t packet;
  bool radioLocked;
  uint8_t channel;
  
  event void Boot.booted() {
  	call ButtonNotify.enable();
	if (SENDER) {
	  	call Leds.led0On();
	}
  	call RadioAMControl.start();
  	radioLocked = FALSE;
	channel = 11;
    call RadioConfig.setChannel (channel);
  }
  event void ButtonNotify.notify (button_state_t val) {
		
  	if (val == BUTTON_RELEASED) {
  		channel++;
  		if (channel > 26) {
  			channel = 11;
  		}
  		if (call RadioConfig.getChannel() > 13) {
  			call Leds.led2On();
  		} else {
  			call Leds.led2Off();
  		}
  		call RadioConfig.setChannel (channel);
		printf ("%s changed channel to %d\n", RECEIVER ? "RECEIVER" : "SENDER",
				call RadioConfig.getChannel());
		printfflush ();
  	}
  }

  event void RadioAMControl.startDone(error_t err) {
    if (err == SUCCESS) {
		call Timer.startPeriodic(DELAY());
    }
    else {
      call RadioAMControl.start();
    }
  }

  event void RadioAMControl.stopDone(error_t err) {
    // do nothing
  }

  event void Timer.fired(){
	if (SENDER) {
		radio_packet_msg_t* msg;
    
    	msg = (radio_packet_msg_t*)call RadioPacket.getPayload(&packet, sizeof(radio_packet_msg_t));
    	if (msg == NULL) {return;}
    
		// send out the local LED state to other motes
    	if (!radioLocked) {
      		if (call RadioAMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(radio_packet_msg_t)) == SUCCESS) {
				radioLocked = TRUE;
      		}
    	}
  	} else if (RECEIVER) {
  		call Leds.led1Off();
  	}
  }

  event void RadioAMSend.sendDone(message_t* bufPtr, error_t error) {
   if (&packet == bufPtr) {
     radioLocked = FALSE;
   }
  }

  event message_t* RadioReceive.receive(message_t* bufPtr, void* payload, uint8_t len) {

	    if (len != sizeof(radio_packet_msg_t)) {return bufPtr;}
	    else {
//		    radio_packet_msg_t* msg = (radio_packet_msg_t*)payload;
			call Leds.led1On();
		}
	    return bufPtr;
  }  

  event void RadioConfig.syncDone (error_t err) {
  }
}
