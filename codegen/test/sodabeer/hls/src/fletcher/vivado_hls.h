#pragma once

#include <hls_stream.h>
#include <ap_int.h>

// A log function to get the number of count bits.
template <int x>
 struct f_log2 { enum { value = 1 + f_log2<x/2>::value }; };
template <> struct f_log2<1> { enum { value = 1 }; };

/**
 * Stream packet structs and types corresponding to Fletcher / Arrow types.
 */

/// @brief Base packet containing count, dvalid and last.
struct f_packet_base {
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
template<unsigned int W>
struct f_spacket : public f_packet_base {
	ap_int<W> data = 0;
};

/// @brief Packet for unsigned integers.
template<unsigned int W>
struct f_upacket : public f_packet_base {
	ap_uint<W> data = 0;
};

/// @brief Packet for half precision floats.
struct f_hpacket : public f_packet_base {
	half data = 0.0f;
};

/// @brief Packet for single precision floats.
struct f_fpacket : public f_packet_base {
	float data = 0.0f;
};

/// @brief Packet for double precision floats.
struct f_dpacket : public f_packet_base {
	double data = 0.0;
};

/// @brief Packet for signed integers for multiple element per cycle.
template<unsigned int W, unsigned int N>
struct f_mspacket : public f_packet_base {
	ap_uint<f_log2<N>::value> count = N; // For true minimum use N-1
	ap_int<W> data[N];
};

/// @brief Packet for unsigned integers for multiple element per cycle..
template<unsigned int W, unsigned int N>
struct f_mupacket : public f_packet_base {
	ap_uint<f_log2<N>::value> count = N; // For true minimum use N-1
	ap_uint<W> data[N];
};

/// @brief Packet for half precision floats for multiple element per cycle.
template<unsigned int N>
struct f_mhpacket : public f_packet_base {
	ap_uint<f_log2<N>::value> count = N; // For true minimum use N-1
	half data[N];
};

/// @brief Packet for single precision floats for multiple element per cycle.
template<unsigned int N>
struct f_mfpacket : public f_packet_base {
	ap_uint<f_log2<N>::value> count = N; // For true minimum use N-1
	float data[N];
};

/// @brief Packet for double precision floats for multiple element per cycle..
template<unsigned int N>
struct f_mdpacket : public f_packet_base {
	ap_uint<f_log2<N>::value> count = N; // For true minimum use N-1
	double data[N];
};

/// @brief Wrapper for nullable types
template<typename T>
struct nullable : public T {
	bool valid = true;
};

// Lengths, offsets

typedef f_spacket<32> f_size;

// Arrow primitive types:
struct f_bool : f_upacket< 1> {};
struct f_int8 : f_spacket< 8> {};
struct f_int16 :  f_spacket<16> {};
struct f_int32 :  f_spacket<32> {};
struct f_int64 :  f_spacket<64> {};
struct f_uint8 :  f_upacket< 8> {};
struct f_uint16 :  f_upacket<16> {};
struct f_uint32 :  f_upacket<32> {};
struct f_uint64 :  f_upacket<64> {};
struct f_float16 :  f_hpacket     {};
struct f_float32 :  f_fpacket     {};
struct f_float64 :  f_dpacket     {};
struct f_date32 :  f_upacket<32> {};
struct f_date64 :  f_upacket<64> {};

// Arrow primitive list types:
template<unsigned int N>
struct f_mbool : f_mupacket< 1, N> {};
template<unsigned int N>
struct f_mint8 : f_mspacket< 8, N> {};
template<unsigned int N>
struct f_mint16 : f_mspacket<16, N> {};
template<unsigned int N>
struct f_mint32 : f_mspacket<32, N> {};
template<unsigned int N>
struct f_mint64 : f_mspacket<64, N> {};
template<unsigned int N>
struct f_muint8 : f_mupacket< 8, N> {};
template<unsigned int N>
struct f_muint16 : f_mupacket<16, N> {};
template<unsigned int N>
struct f_muint32 : f_mupacket<32, N> {};
template<unsigned int N>
struct f_muint64 : f_mupacket<64, N> {};
template<unsigned int N>
struct f_mfloat16 : f_mhpacket<N> {};
template<unsigned int N>
struct f_mfloat32 : f_mfpacket<N> {};
template<unsigned int N>
struct f_mfloat64 : f_mdpacket<N> {};
template<unsigned int N>
struct f_mdate32 : f_mupacket<32, N> {};
template<unsigned int N>
struct f_mdate64 : f_mupacket<64, N> {};

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
