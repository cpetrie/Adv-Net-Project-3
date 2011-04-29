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
#include "MsgProgram3.h"

// enumeration of mote IDs
enum {
	MASTER_MOTE = 0,
	SLAVE_MOTE = 1
};

// the mote number (either 0 or 1)
#define MY_MOTE_ID SLAVE_MOTE

// our subnet ID
#define SUBNET_ID 4

// sampling delays in milliseconds
#define LIGHT_READ_DELAY 200

// the delay between determining near/far nodes
#define NODE_DECISION_DELAY 1000
#define NODE_DECISION_START_DELAY 500

#define DEFAULT_FREQ_CHANNEL 26
#define GROUP4_CHANNEL_FREQ 14
module SenseC
{
	uses {
		interface Boot;
		interface Leds;
		interface Receive as RadioReceive;
		interface Receive as BeaconMsgReceive;
		interface Receive as TargetMsgReceive;
		interface AMSend as RadioAMSend;
		interface AMSend as ReportMsgSend;
		interface SplitControl as RadioAMControl;
		interface Packet as RadioPacket;
		interface Timer<TMilli> as RssiTimer;

		interface CC2420Config;
		interface CC2420Packet;
	}
}
implementation
{
	// current packet
	message_t packet;

	// mutex lock for packet operations
	bool radioLocked = FALSE;
	
	// if the led should be on (on for the nearest node)
	bool led0On = FALSE;

	// signal strength
	int8_t signalStrength = 0;

	event void Boot.booted() {
		call RadioAMControl.start();
	}
	
	int nearNodeId = MASTER_MOTE;

/* Configure Radio **************************************************************/
	event void RadioAMControl.startDone(error_t err) {
		if (err == SUCCESS) {
			// start the RssiTimer only if the master mote
			if (MY_MOTE_ID == MASTER_MOTE){
				call RssiTimer.startPeriodicAt(NODE_DECISION_START_DELAY, NODE_DECISION_DELAY);
			}

			call CC2420Config.setChannel (DEFAULT_FREQ_CHANNEL);
			call RadioAMControl.stop();
			call RadioAMControl.start();
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
			
			// if the message is a SLAVE_POWER_RESPONSE, send out the Near-Node-ID
			else if (message->msg_type == SLAVE_POWER_RESPONSE){
				printf("\nReceived SLAVE_POWER_RESPONSE message from %d.\n", (unsigned int) message->node_id);
				printf("  value was: %d, (my value is %d)\n\n", message->data, signalStrength);
				printfflush();
		
				// decide on the Near-Node ID
				if (message->data > signalStrength){
					nearNodeId = message->node_id;
				} else {
					nearNodeId = MY_MOTE_ID;
				}
				
				// broadcast the Near-Node ID to other nodes
				//--------------------------------------------
				newMessage = (radio_packet_msg_t*)call RadioPacket.getPayload(&packet, sizeof(radio_packet_msg_t));
				if (newMessage == NULL) {return bufPtr;}	
	
				printf("Sending out message with Near Node ID: %d\n", nearNodeId);
				printfflush();
	
				// build message
				newMessage->msg_type = NEAR_ID;
				newMessage->node_id = MY_MOTE_ID;
				newMessage->data = nearNodeId;
			
				// send out a mote value request message
				if (!radioLocked) {
					if (call RadioAMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(radio_packet_msg_t)) == SUCCESS) {
						radioLocked = TRUE;
					}
				}	
			}
			
			// if the message is a NEAR_ID, then set this value internally
			else if (message->msg_type == NEAR_ID){
				printf("\nReceived NEAR_ID message from %d.\n", (unsigned int) message->node_id);
				printf("  value was: %d, setting nearNodeId\n\n", message->data);
				
				nearNodeId = message->data;
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
	
	event void ReportMsgSend.sendDone (message_t* bufPtr, error_t error) {
		if (&packet == bufPtr) {
			radioLocked = FALSE;
		}
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


	/* Receive Beacon Message ***************************************************/
	event message_t* BeaconMsgReceive.receive(message_t* bufPtr, void* payload, uint8_t len) {
		BeaconMsg* message = (BeaconMsg*)payload;
		ReportMsg* newMessage;

		if (len != sizeof(BeaconMsg)) {
			return bufPtr;
		} else {
		
			// make sure the base station is talking to my subnet
			if (message->subnetid == SUBNET_ID){
			
				// send back the near node information only if the near node
				if (nearNodeId == MY_MOTE_ID) {
				
					newMessage = (ReportMsg*)call ReportMsgSend.getPayload(&packet, sizeof(ReportMsg));
					if (newMessage == NULL) {return bufPtr;}	
	
						// build message
						newMessage->msgtype = REP;
						newMessage->nodeid = nearNodeId;
				
						if (!radioLocked) {
							if (call ReportMsgSend.send(REP, &packet, sizeof(ReportMsg)) == SUCCESS) {
								radioLocked = TRUE;
							}
						}
					}
				}
			}
	}


	event void CC2420Config.syncDone (error_t err) {
	}

	event message_t* TargetMsgReceive.receive(message_t* bufPtr, void* payload, uint8_t len) {
		radio_packet_msg_t* message = (radio_packet_msg_t*)payload;
		radio_packet_msg_t* newMessage;

		if (len != sizeof(TargetMsg)) {
			return bufPtr;
		} else {
		
		  
		  // save rssi
		  
		  signalStrength = CC2420Packet.getRssi( bufPtr);

		  // change to personal frequency
		  call CC2420Config.setChannel (GROUP4_CHANNEL_FREQ);
		  call RadioAMControl.stop();
		  call RadioAMControl.start();

		  // if master transmits some stuff
		}
		  // else hang out		
		return bufPtr;
	}
}
