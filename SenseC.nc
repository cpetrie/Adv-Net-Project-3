#include "Timer.h"
#include "printf.h"
#include "RadioPacket.h"
#include "MsgProgram3.h"

// enumeration of mote IDs
enum {
	MASTER_MOTE = 41,
	SLAVE_MOTE = 42
};

// the mote number (either 0 or 1)
#define MY_MOTE_ID MASTER_MOTE

// our subnet ID
#define SUBNET_ID 4

// sampling delays in milliseconds
#define LIGHT_READ_DELAY 200

// the delay between determining near/far nodes
#define NODE_DECISION_DELAY 100
#define NODE_DECISION_START_DELAY 0

#define SUBNET_TIMEOUT 2048

#define BEACONTIMEOUT 5

#define DEFAULT_FREQ_CHANNEL 26
#define GROUP4_CHANNEL_FREQ 14
module SenseC
{
	uses {
		interface Boot;
		interface Leds;
		interface Receive as RadioReceive;
		interface Receive as SimpleBeaconMsgReceive;
		interface Receive as RequestMsgReceive;
		interface Receive as TargetMsgReceive;
		interface AMSend as RadioAMSend;
		interface Packet as RadioPacket;
		interface AMSend as ReportMsgSend;
		interface Packet as ReportMsgPacket;
		interface SplitControl as RadioAMControl;
		interface Timer<TMilli> as RssiTimer;
		interface Timer<TMilli> as SubnetTimeoutTimer;
		interface Timer<TMilli> as BaseStationTimer;

		interface CC2420Config;
		interface CC2420Packet;
	}
}
implementation
{
	// Connected to base station
	bool connected;

	// BEACONPERIODS missed
	uint8_t beaconperiods;

	// current packet
	message_t packet;

	// mutex lock for packet operations
	bool radioLocked = FALSE;
	
	// if the led should be on (on for the nearest node)
	bool led0On = FALSE;

	// signal strength
	int8_t signalStrength = 0;

	event void Boot.booted() {
		call CC2420Config.setChannel (DEFAULT_FREQ_CHANNEL);
		call RadioAMControl.start();
		connected = FALSE;
		beaconperiods = 0;
		call Leds.led2Off();
		call BaseStationTimer.startPeriodicAt (0, BEACONPERIOD);
	}
	
	int nearNodeId = MASTER_MOTE;

/* Configure Radio **************************************************************/
	event void RadioAMControl.startDone(error_t err) {
		if (err == SUCCESS) {
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
				nearNodeId = message->data;
				if (nearNodeId == MY_MOTE_ID) {
					call Leds.led0On();
					call Leds.led1Off();
				} else {
					call Leds.led1On();
					call Leds.led0Off();
				}

				call CC2420Config.setChannel (DEFAULT_FREQ_CHANNEL);

				call SubnetTimeoutTimer.stop ();
			}
		}
		
		return bufPtr;
	}
	
/* Sending via radio *********************************************************/
	event void RadioAMSend.sendDone(message_t* bufPtr, error_t error) {
		if (&packet == bufPtr) {
			radio_packet_msg_t* message;
			message = (radio_packet_msg_t*)call RadioPacket.getPayload(&packet, sizeof(radio_packet_msg_t));

			radioLocked = FALSE;

			if (MY_MOTE_ID == MASTER_MOTE
			    && message->msg_type == NEAR_ID) {

				if (nearNodeId == MY_MOTE_ID) {
					call Leds.led0On();
					call Leds.led1Off();
				} else {
					call Leds.led1On();
					call Leds.led0Off();
				}

				call CC2420Config.setChannel (DEFAULT_FREQ_CHANNEL);

				call SubnetTimeoutTimer.stop ();
			}
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
		message->data = signalStrength;
		
		// send out a mote value request message
		if (!radioLocked) {
			if (call RadioAMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(radio_packet_msg_t)) == SUCCESS) {
				radioLocked = TRUE;
			}
		}
	}

/* Subnet timeout: switch back to broadcast frequency **********************/
	event void SubnetTimeoutTimer.fired () {
		call CC2420Config.setChannel (DEFAULT_FREQ_CHANNEL);
	}

/* Count beacon periods ***************************************/
	event void BaseStationTimer.fired(){
		beaconperiods++;
		if (beaconperiods >= BEACONTIMEOUT) {
			connected = FALSE;
			call Leds.led2Off();
		}
	}


	/* Receive Request Message ***************************************************/
	event message_t* RequestMsgReceive.receive(message_t* bufPtr, void* payload, uint8_t len) {
		Message_t* message = (Message_t*)payload;
		Message_t* newMessage;

		if (len != sizeof(BeaconMsg) || message->msgtype != REQ) {
			return bufPtr;
		} else {

			// make sure the base station is talking to my subnet
		  if (message->subnetid == SUBNET_ID){
			
				// send back the near node information only if the near node
				if (nearNodeId == MY_MOTE_ID) {
				
					newMessage = (Message_t*)call ReportMsgPacket.getPayload(&packet, sizeof(Message_t));
					if (newMessage == NULL) {return bufPtr;}	
	
					// build message
					newMessage->nodeid = nearNodeId;
					newMessage->subnetid = SUBNET_ID;
				
					if (!radioLocked) {
						if (call ReportMsgSend.send(REP, &packet, sizeof(Message_t)) == SUCCESS) {
							radioLocked = TRUE;
						}
					}
				}
			}
		}
		return bufPtr;
	}

	/* Receive Simple Beacon Message ***************************************************/
	event message_t* SimpleBeaconMsgReceive.receive(message_t* bufPtr, void* payload, uint8_t len) {
		Message_t* message = (Message_t*)payload;
		
		beaconperiods = 0;

		if (len != sizeof(Message_t)) {
			return bufPtr;
		} else {
			connected = TRUE;
			call Leds.led2On();
		}

		return bufPtr;
	}

	event void CC2420Config.syncDone (error_t err) {
		call RadioAMControl.stop();
		call RadioAMControl.start();
	}

	event message_t* TargetMsgReceive.receive(message_t* bufPtr, void* payload, uint8_t len) {
		if (len != sizeof(Message_t)) {
			return bufPtr;
		} else {
				  
			// save rssi
		  
			signalStrength = call CC2420Packet.getRssi( bufPtr);

			// change to personal frequency
			call CC2420Config.setChannel (GROUP4_CHANNEL_FREQ);

			// if master transmits a MASTER_POWER_REQUEST
			if (MY_MOTE_ID == MASTER_MOTE){
				call RssiTimer.startOneShotAt(NODE_DECISION_DELAY, NODE_DECISION_START_DELAY);
			}

			// Start timeout to switch back to broadcast channel if
			// subnet takes too long
			call SubnetTimeoutTimer.startOneShot (SUBNET_TIMEOUT);
		}
		// else return
		return bufPtr;
	}
}
