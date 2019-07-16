#pragma once

#include <ap_int.h>
#include <hls_half.h>
#include "packet.h"

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

using f_base_length_type = ap_int<32>;
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