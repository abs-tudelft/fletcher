#pragma once

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

#include <tuple>
#include <type_traits>

template<typename T>
struct innermost_impl
{
    using type = T;
};

template<template<typename> class E, typename T>
struct innermost_impl<E<T>>
{
    using type = typename innermost_impl<T>::type;
};

template<template<typename...> class E, typename... Ts>
struct innermost_impl<E<Ts...>>
{
    using type = std::tuple<typename innermost_impl<Ts>::type...>;
};

template<typename T>
using innermost = typename innermost_impl<T>::type;
