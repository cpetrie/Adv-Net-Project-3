#include "printf.h"
#include "MsgProgram3.h"

configuration TargetMoteAppC 
{ } 
implementation {
  
	components RadioC as App, MainC, LedsC;
	components new TimerMilliC() as Timer;
	components new AMSenderC(TMSG);
	components ActiveMessageC;
	components CC2420ControlC as RadioConfig;

	App.Boot -> MainC.Boot;
	App.Leds -> LedsC;

	App.Timer -> Timer;
  
	App.RadioAMSend -> AMSenderC;
	App.RadioAMControl -> ActiveMessageC;

	App.RadioConfig -> RadioConfig.CC2420Config;
}
