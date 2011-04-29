#include "printf.h"
#include "MsgProgram3.h"

module TargetMoteC
{
	uses {
		interface Boot;
		interface Leds;
		interface AMSend as RadioAMSend;
		interface SplitControl as RadioAMControl;
		interface Packet as RadioPacket;
		interface Timer<TMilli> as Timer;

		interface CC2420Config as RadioConfig;
	}
}
implementation
{
	message_t packet;
	bool radioLocked;
  
	event void Boot.booted() {
		call Leds.led0On();
		call Leds.led1Off();
		call RadioAMControl.start();
		radioLocked = FALSE;
	}

	event void RadioAMControl.startDone(error_t err) {
		if (err == SUCCESS) {
			call Timer.startPeriodic(TARGETPERIOD);
		}
		else {
			call RadioAMControl.start();
		}
	}

	event void RadioAMControl.stopDone(error_t err) {
		// do nothing
	}

	event void Timer.fired(){
		TargetMsg *msg;
		
		msg = (TargetMsg *)call RadioPacket.getPayload(&packet, sizeof(TargetMsg));
		if (msg == NULL) {return;}
		
		// send out the local LED state to other motes
		if (!radioLocked) {
			if (call RadioAMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(TargetMsg)) == SUCCESS) {
				radioLocked = TRUE;
			}
		}
	}

	event void RadioAMSend.sendDone(message_t* bufPtr, error_t error) {
		if (&packet == bufPtr) {
			radioLocked = FALSE;
			call Leds.led0Toggle();
			call Leds.led1Toggle();

		}
	}

	event void RadioConfig.syncDone (error_t err) {
	}
}
