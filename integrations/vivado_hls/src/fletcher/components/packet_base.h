#pragma once

/// @brief Base packet containing count, dvalid and last.
struct f_packet_base
{
    bool dvalid = true;
    bool last = false;

    f_packet_base() = default;

    f_packet_base(bool _dvalid, bool _last) : dvalid(_dvalid), last(_last) {}
};
