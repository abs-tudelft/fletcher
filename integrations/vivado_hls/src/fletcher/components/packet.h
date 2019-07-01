#pragma once

#include "packet_base.h"

/// @brief Packet template.
template <typename T>
struct f_packet : public f_packet_base
{
    T data = 0;
    f_packet() = default;
    f_packet(T _data) : data(_data), f_packet_base() {}
    f_packet(T _data, bool dvalid, bool last) : data(_data), f_packet_base(dvalid, last) {}

    f_packet &operator=(const T val)
    {
        data = val;
        return *this;
    }

    using inner_type = T;
};