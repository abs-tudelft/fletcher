#pragma once

#include <hls_stream.h>
#include <ap_int.h>

/**
 * Stream packet structs and types corresponding to Fletcher / Arrow types.
 */

/// @brief Base packet containing count, dvalid and last.
template<unsigned int C>
struct f_packet_base {
	ap_uint<C> 	count 	= 1;
	bool 		dvalid 	= true;
	bool 		last 	= false;

	void SetDataValid(bool val) {
		dvalid = val;
	}

	bool DataValid() {
		return dvalid;
	}
};

/// @brief Packet for signed integers.
template<unsigned int W, unsigned int C>
struct f_spacket : public f_packet_base<C> {
	ap_int<W> data = 0;
};

/// @brief Packet for unsigned integers.
template<unsigned int W, unsigned int C>
struct f_upacket : public f_packet_base<C> {
	ap_uint<W> data = 0;
};

/// TODO(johanpel): packet for floats

/// @brief Wrapper for nullable types
template<class T>
struct nullable : public T {
	bool null = false;
};

// Lengths, offsets
typedef f_spacket<32,1> f_size;

// Arrow primitive types:
typedef f_upacket< 1,1> f_bool;
typedef f_spacket< 8,1> f_int8;
typedef f_spacket<16,1> f_int16;
typedef f_spacket<32,1> f_int32;
typedef f_spacket<64,1> f_int64;
typedef f_upacket< 8,1> f_uint8;
typedef f_upacket<16,1> f_uint16;
typedef f_upacket<32,1> f_uint32;
typedef f_upacket<64,1> f_uint64;
typedef f_upacket<16,1> f_float16;
typedef f_upacket<32,1> f_float32;
typedef f_upacket<64,1> f_float64;
typedef f_upacket<32,1> f_date32;
typedef f_upacket<64,1> f_date64;

/**
 * RecordBatch & Schema support
 */

/// @brief RecordBatch metadata.
struct RecordBatchMeta {
	int length;
};


/**
 * String utilities
 */

#define MAX_STRING_LENGTH 256

inline void PullString(f_uint8 buffer[MAX_STRING_LENGTH], f_size length, hls::stream<f_uint8>& chars) {
	for (int i = 0; i < length.data; i++) {
		chars >> buffer[i];
	}
}

inline void PushString(f_uint8 buffer[MAX_STRING_LENGTH], f_size length, hls::stream<f_uint8>& chars) {
	for (int i = 0; i < length.data; i++) {
		chars << buffer[i];
	}
}
