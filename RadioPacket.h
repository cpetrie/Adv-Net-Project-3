#ifndef RADIO_PACKET_H
#define RADIO_PACKET_H

typedef nx_struct radio_packet_msg {
	nx_uint8_t msg_type;
	nx_uint8_t node_id;
	nx_int16_t data;
} radio_packet_msg_t;

enum {
  AM_RADIO_PACKET_MSG = 41,
};

enum {
	MASTER_POWER_REQUEST,
	SLAVE_POWER_RESPONSE,
	NEAR_ID,
};

#endif
