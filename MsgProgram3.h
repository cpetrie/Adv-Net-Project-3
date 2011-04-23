#ifndef MSGPROGRAM2_H_
#define MSGPROGRAM2_H_


// Message Types

#define REP 0xAA // ReportMsg
#define BCAST 0xBB // BeaconMsg: Simple beacon message
#define REQ 0xCC // BeaconMsg: Request-for-report beacon message
#define TMSG 0xDD // TargetMsg

// ReportMsg structure
typedef nx_struct Message
{
  nx_uint8_t subnetid;
  nx_uint8_t nodeid;
} Message_t;

// Defining the intervals TargetMsg and BeaconMsg are sent
enum
{
	TARGETPERIOD = 512, BEACONPERIOD = 1024
};

#endif
