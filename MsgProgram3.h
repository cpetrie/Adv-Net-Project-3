#ifndef MSGPROGRAM2_H_
#define MSGPROGRAM2_H_


// Message Types

#define REP 0xAA // ReportMsg
#define BCAST 0xBB // BeaconMsg: Simple beacon message
#define REQ 0xCC // BeaconMsg: Request-for-report beacon message
#define TMSG 0xDD // TargetMsg

// ReportMsg structure
typedef nx_struct ReportMsg 
{
	nx_uint8_t msgtype;
	nx_uint16_t nodeid; // nodeid contains the subnetid
} ReportMsg;

// BeaconMsg structure
typedef nx_struct BeaconMsg 
{
	nx_uint8_t msgtype;     //BCAST or REQ
	nx_uint8_t subnetid;
} BeaconMsg;

// TargetMsg structure
typedef nx_struct TargetMsg
{
	nx_uint8_t msgtype;
} TargetMsg;

// Defining the intervals TargetMsg and BeaconMsg are sent
enum
{
	TARGETPERIOD = 512, BEACONPERIOD = 1024
};

#endif
