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
#include "printf.h"
#include "RadioPacket.h"

// enumeration of mote IDs
enum {
	MASTER_MOTE = 0,
	SLAVE_MOTE = 1
};

// the mote number (either 0 or 1)
#define MY_MOTE_ID MASTER_MOTE

// sampling delays in milliseconds
#define LIGHT_READ_DELAY 200

// the delay between determining near/far nodes
#define NODE_DECISION_DELAY 1000
#define NODE_DECISION_START_DELAY 500

// light threshold
#define LIGHT_THRES 50

module SenseC
{
	uses {
		interface Boot;
		interface Leds;
		interface Receive as RadioReceive;
		interface AMSend as RadioAMSend;
		interface SplitControl as RadioAMControl;
		interface Packet as RadioPacket;
		interface Timer<TMilli> as LightSampleTimer;
		interface Timer<TMilli> as RssiTimer;
		interface Read<uint16_t>;
	}
}
implementation
{
	// current packet
	message_t packet;

	// mutex lock for packet operations
	bool radioLocked = FALSE;

	// signal strength
	unsigned int signalStrength = 0;
	
	event void Boot.booted() {
		call RadioAMControl.start();
	}

/* Configure Radio **************************************************************/
	event void RadioAMControl.startDone(error_t err) {
		if (err == SUCCESS) {
			call LightSampleTimer.startPeriodic(LIGHT_READ_DELAY);
			
			// start the RssiTimer only if the master mote
			if (MY_MOTE_ID == MASTER_MOTE){
				call RssiTimer.startPeriodicAt(NODE_DECISION_START_DELAY, NODE_DECISION_DELAY);
			}
		}
		else {
			call RadioAMControl.start();
		}
	}

	event void RadioAMControl.stopDone(error_t err) {
		// do nothing
	}
	
/* Receive from radio ***********************************************************/
	event message_t* RadioReceive.receive(message_t* bufPtr, void* payload, uint8_t len) {
		radio_packet_msg_t* message = (radio_packet_msg_t*)payload;
		radio_packet_msg_t* newMessage;

		if (len != sizeof(radio_packet_msg_t)) {
			return bufPtr;
		} else {
		
			// if the message is a MASTER_POWER_REQUEST, send a response
			if (message->msg_type == MASTER_POWER_REQUEST) {
				printf("Received MASTER_POWER_REQUEST message from %d.\n", (unsigned int) message->node_id);
				printfflush();		    	
				
				newMessage = (radio_packet_msg_t*)call RadioPacket.getPayload(&packet, sizeof(radio_packet_msg_t));
				if (newMessage == NULL) {return bufPtr;}	
	
				// build message
				newMessage->msg_type = SLAVE_POWER_RESPONSE;
				newMessage->node_id = SLAVE_MOTE;
				newMessage->data = signalStrength;
			
				// send out a mote value request message
				if (!radioLocked) {
					if (call RadioAMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(radio_packet_msg_t)) == SUCCESS) {
						radioLocked = TRUE;
					}
				}	
			} 
			
			// if the message is a SLAVE_POWER_RESPONSE, do SOMETHING
			else if (message->msg_type == SLAVE_POWER_RESPONSE){
				printf("\nReceived SLAVE_POWER_RESPONSE message from %d.\n", (unsigned int) message->node_id);
				printf("  value was: %d, (my value is %d)\n\n", message->data, signalStrength);
				printfflush();
			}
		}
		
		return bufPtr;
	}
	
/* Sending via radio *********************************************************/
	event void RadioAMSend.sendDone(message_t* bufPtr, error_t error) {
		if (&packet == bufPtr) {
			radioLocked = FALSE;
		}
	}
	
/* Reading from the light sensor **********************************************/
	event void LightSampleTimer.fired(){
		call Read.read();
	}

	event void Read.readDone(error_t result, uint16_t data) {
		
		// save the signal strength
		signalStrength = data;

		printf("Mote %d data value: %d.\n", (int) MY_MOTE_ID, signalStrength);
		printfflush();
	}

/* Sending out the slave value requests ***************************************/
	event void RssiTimer.fired(){
		radio_packet_msg_t* message;
		message = (radio_packet_msg_t*)call RadioPacket.getPayload(&packet, sizeof(radio_packet_msg_t));
		if (message == NULL) {return;}

		// build message
		message->msg_type = MASTER_POWER_REQUEST;
		message->node_id = MASTER_MOTE;
		message->data = 0;
		
		// send out a mote value request message
		if (!radioLocked) {
			if (call RadioAMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(radio_packet_msg_t)) == SUCCESS) {
				radioLocked = TRUE;
			}
		}
		
		printf("Mote %d just sent out an Rssi request!\n", (int) MY_MOTE_ID);
		printfflush();
	}
}
