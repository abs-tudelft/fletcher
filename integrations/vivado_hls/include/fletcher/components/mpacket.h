#pragma once

#include "packet.h"

/// @brief Packet template (multi).
template <typename T, unsigned int N>
struct f_mpacket : public f_packet_base
{
    ap_uint<f_log2<N>::value> count = N; // For true minimum use N-1
    T data[N];
    f_mpacket() = default;
    f_mpacket(T _data[N]) : data(_data), f_packet_base() {}
};