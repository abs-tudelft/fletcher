#pragma once
#include <utility>
//Add valid bit at the end, because data packing in vivado flips the order, and in hardware it needs to be the most significant bit.
template <typename T>
struct nullable_tb {
    T data;
    bool valid;
};
// Lengths, offsets

/// @brief Wrapper for nullable types
template <typename T>
struct nullable : public T {
    bool valid = true;

    template<typename... Args>
    explicit nullable(bool _valid, Args &&... args) : T(std::forward<Args>(args)...), valid(_valid) {}

    explicit nullable(bool _valid) : T(), valid(_valid) {}

    nullable(bool _valid, nullable<T> _nullable) : T(_nullable.data, _nullable.dvalid, _nullable.last), valid(_valid) {}

    template<typename IT>
    nullable(nullable_tb<IT> _nullable_tb) : T(_nullable_tb.data), valid(_nullable_tb.valid) {}

    template<typename IT>
    nullable(nullable_tb<IT> _nullable_tb, bool _dvalid, bool _last) : T(_nullable_tb.data, _dvalid, _last),
                                                                       valid(_nullable_tb.valid) {}

    nullable() = default;

};
