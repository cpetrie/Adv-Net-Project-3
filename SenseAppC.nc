#include "printf.h"
#include "MsgProgram3.h"

configuration SenseAppC 
{ } 
implementation { 
  
	components SenseC as App, MainC, LedsC;
	components new TimerMilliC() as RssiTimer;
	components new TimerMilliC() as SubnetTimeoutTimer;
	components new TimerMilliC() as BaseStationTimer;
	components new AMSenderC(AM_RADIO_PACKET_MSG) as RadioPacketSender;
	components new AMReceiverC(AM_RADIO_PACKET_MSG) as RadioPacketReceiver;
	components new AMSenderC(REP) as ReportMsgSender;
	components new AMReceiverC(BCAST) as SimpleBeaconMsgReceiver;
	components new AMReceiverC(REQ) as RequestMsgReceiver;
	components new AMReceiverC(TMSG) as TargetMsgReceiver;
	components ActiveMessageC;

	components CC2420ControlC, CC2420PacketC;

	App.Boot -> MainC.Boot;
	App.Leds -> LedsC;
	App.RssiTimer -> RssiTimer;
	App.SubnetTimeoutTimer -> SubnetTimeoutTimer;
	App.BaseStationTimer -> BaseStationTimer;

	App.RadioReceive -> RadioPacketReceiver;
	App.RadioAMSend -> RadioPacketSender;
	App.RadioPacket -> RadioPacketSender;

	App.ReportMsgSend -> ReportMsgSender;
	App.ReportMsgPacket -> ReportMsgSender;

	App.SimpleBeaconMsgReceive -> SimpleBeaconMsgReceiver;
	App.RequestMsgReceive -> RequestMsgReceiver;
	App.TargetMsgReceive -> TargetMsgReceiver;

	App.RadioAMControl -> ActiveMessageC;

	App.CC2420Packet -> CC2420PacketC;
	App.CC2420Config -> CC2420ControlC.CC2420Config;
}
