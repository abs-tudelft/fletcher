#pragma once

#include <hls_stream.h>
#include <ap_int.h>
#include <hls_half.h>
#include <utility>
#include <string.h>

// A log function to get the number of count bits.
template <int x>
struct f_log2
{
	enum
	{
		value = 1 + f_log2<x / 2>::value
	};
};
template <>
struct f_log2<1>
{
	enum
	{
		value = 1
	};
};

/**
 * Stream packet structs and types corresponding to Fletcher / Arrow types.
 */

/// @brief Base packet containing count, dvalid and last.
struct f_packet_base
{
	bool dvalid = true;
	bool last = false;

	void SetDataValid(bool val)
	{
		dvalid = val;
	}

	bool DataValid()
	{
		return dvalid;
	}

	f_packet_base() = default;

	f_packet_base(bool _dvalid, bool _last) : dvalid(_dvalid), last(_last) {}
};

/// @brief Packet template.
template <typename T>
struct f_packet : public f_packet_base
{
	T data = 0;
	f_packet() = default;
	f_packet(T _data) : data(_data), f_packet_base() {}
	f_packet(T _data, bool dvalid, bool last) : data(_data), f_packet_base(dvalid, last) {}

	friend bool operator<(f_packet<T> &lhs, f_packet<T> &rhs)
	{
		return lhs.data < rhs.data;
	}
	f_packet<T> &operator=(const T val)
	{
		data = val;
		return *this;
	}
	friend bool operator>(f_packet<T> &lhs, f_packet<T> &rhs)
	{
		return rhs < lhs;
	}
	friend bool operator<=(f_packet<T> &lhs, f_packet<T> &rhs)
	{
		return !(rhs < lhs);
	}
	friend bool operator>=(f_packet<T> &lhs, f_packet<T> &rhs)
	{
		return !(lhs < rhs);
	}
	friend f_packet<T> operator+(f_packet<T> &lhs, f_packet<T> &rhs)
	{
		return f_packet<T>(lhs.data + rhs.data, lhs.dvalid, lhs.last);
	}
	friend f_packet<T> operator+(f_packet<T> &rhs)
	{
		return f_packet<T>(+rhs.data, rhs.dvalid, rhs.last);
	}
	friend f_packet<T> operator-(f_packet<T> &lhs, f_packet<T> &rhs)
	{
		return f_packet<T>(lhs.data - rhs.data, lhs.dvalid, lhs.last);
	}
	friend f_packet<T> operator-(f_packet<T> &rhs)
	{
		return f_packet<T>(-rhs.data, rhs.dvalid, rhs.last);
	}
	friend f_packet<T> operator*(f_packet<T> &lhs, f_packet<T> &rhs)
	{
		return f_packet<T>(lhs.data * rhs.data, lhs.dvalid, lhs.last);
	}
	friend f_packet<T> operator/(f_packet<T> &lhs, f_packet<T> &rhs)
	{
		return f_packet<T>(lhs.data / rhs.data, lhs.dvalid, lhs.last);
	}
	friend bool operator==(f_packet<T> &lhs, f_packet<T> &rhs)
	{
		return lhs.data == rhs.data;
	}
	friend bool operator!=(f_packet<T> &lhs, f_packet<T> &rhs)
	{
		return !(rhs == lhs);
	}
};

/// @brief Packet template (multi).
template <typename T, unsigned int N>
struct f_mpacket : public f_packet_base
{
	ap_uint<f_log2<N>::value> count = N; // For true minimum use N-1
	T data[N];
	f_mpacket() = default;
	f_mpacket(T _data[N]) : data(_data), f_packet_base() {}
};

/// @brief Packet for signed integers.
template <unsigned int W>
using f_spacket = f_packet<ap_int<W>>;

/// @brief Packet for unsigned integers.
template <unsigned int W>
using f_upacket = f_packet<ap_uint<W>>;

/// @brief Packet for half precision floats.
using f_hpacket = f_packet<half>;

/// @brief Packet for single precision floats.
using f_fpacket = f_packet<float>;

/// @brief Packet for double precision floats.
using f_dpacket = f_packet<double>;

/// @brief Packet for signed integers for multiple element per cycle.
template <unsigned int W, unsigned int N>
using f_mspacket = f_mpacket<ap_int<W>, N>;

/// @brief Packet for unsigned integers for multiple element per cycle..
template <unsigned int W, unsigned int N>
using f_mupacket = f_mpacket<ap_uint<W>, N>;

/// @brief Packet for half precision floats for multiple element per cycle.
template <unsigned int N>
using f_mhpacket = f_mpacket<half, N>;

/// @brief Packet for single precision floats for multiple element per cycle.
template <unsigned int N>
using f_mfpacket = f_mpacket<float, N>;

/// @brief Packet for double precision floats for multiple element per cycle..
template <unsigned int N>
using f_mdpacket = f_mpacket<double, N>;

//Add valid bit at the end, because data packing in vivado flips the order, and in hardware it needs to be the most significant bit.
template <typename T>
struct nullable_tb {   
   T data;
   bool valid;
};
// Lengths, offsets

/// @brief Wrapper for nullable types
template <typename T>
struct nullable : public T
{
	bool valid = true;

	template <typename... Args>
	nullable(bool _valid,Args &&... args) : T(std::forward<Args>(args)...), valid(_valid) {}

	nullable(bool _valid) : T(), valid(_valid) {}

	nullable(bool _valid, nullable<T> _nullable) : T(_nullable.data, _nullable.dvalid, _nullable.last), valid(_valid) {}

	template <typename IT>
	nullable(nullable_tb<IT> _nullable_tb) : T(_nullable_tb.data), valid(_nullable_tb.valid) {}

	template <typename IT>
	nullable(nullable_tb<IT> _nullable_tb, bool _dvalid, bool _last) : T(_nullable_tb.data, _dvalid, _last), valid(_nullable_tb.valid) {}

	nullable() = default;
};

using f_size = f_spacket<32>;

// Arrow primitive types:
using f_bool = f_upacket<1>;
using f_int8 = f_spacket<8>;
using f_int16 = f_spacket<16>;
using f_int32 = f_spacket<32>;
using f_int64 = f_spacket<64>;
using f_uint8 = f_upacket<8>;
using f_uint16 = f_upacket<16>;
using f_uint32 = f_upacket<32>;
using f_uint64 = f_upacket<64>;
using f_float16 = f_hpacket;
using f_float32 = f_fpacket;
using f_float64 = f_dpacket;
using f_date32 = f_upacket<32>;
using f_date64 = f_upacket<64>;

// Arrow primitive list types:
template <unsigned int N>
using f_mbool = f_mupacket<1, N>;
template <unsigned int N>
using f_mint8 = f_mspacket<8, N>;
template <unsigned int N>
using f_mint16 = f_mspacket<16, N>;
template <unsigned int N>
using f_mint32 = f_mspacket<32, N>;
template <unsigned int N>
using f_mint64 = f_mspacket<64, N>;
template <unsigned int N>
using f_muint8 = f_mupacket<8, N>;
template <unsigned int N>
using f_muint16 = f_mupacket<16, N>;
template <unsigned int N>
using f_muint32 = f_mupacket<32, N>;
template <unsigned int N>
using f_muint64 = f_mupacket<64, N>;
template <unsigned int N>
using f_mfloat16 = f_mhpacket<N>;
template <unsigned int N>
using f_mfloat32 = f_mfpacket<N>;
template <unsigned int N>
using f_mfloat64 = f_mdpacket<N>;
template <unsigned int N>
using f_mdate32 = f_mupacket<32, N>;
template <unsigned int N>
using f_mdate64 = f_mupacket<64, N>;

//Strings
using f_string = f_uint8 *;

/// @brief Utility function to create f_string arrays from const char arrays.
// f_string new_f_string(const char *src)
// {
// 	int len = strlen(src);
// 	f_string str = new f_uint8[len];
// 	for (int i = 0; i < len; i++)
// 	{
// 		str[i].data = src[i];
// 	}
// 	str[len - 1].last = true;

// 	return str;
// }

/**
 * RecordBatch & Schema support
 */

/// @brief RecordBatch metadata.
struct RecordBatchMeta
{
	unsigned int length;
};