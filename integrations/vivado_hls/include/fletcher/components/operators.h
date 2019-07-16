#pragma once

#include "fletcher/components/operators/arith.h"
#include "fletcher/components/operators/indecrement.h"
#include "fletcher/components/operators/logical.h"

//template <typename T>
//f_packet<T> operator+(f_packet<T> &rhs) {
//    return f_packet<T>(+rhs.data, rhs.dvalid, rhs.last);
//}
//template <typename T>
//f_packet<T> operator-(f_packet<T> &rhs) {
//    return f_packet<T>(-rhs.data, rhs.dvalid, rhs.last);
//}
//
//#pragma region Packet <-> Packet operators
//template <typename T>
//friend bool operator<(f_packet<T> &lhs, f_packet<T> &rhs) {
//    return lhs.data < rhs.data;
//}
//template <typename T>
//friend bool operator>(f_packet<T> &lhs, f_packet<T> &rhs) {
//    return rhs < lhs;
//}
//template <typename T>
//friend bool operator<=(f_packet<T> &lhs, f_packet<T> &rhs) {
//    return !(rhs < lhs);
//}
//template <typename T>
//friend bool operator>=(f_packet<T> &lhs, f_packet<T> &rhs) {
//    return !(lhs < rhs);
//}
//
//template <typename T>
//friend f_packet<T> operator-(f_packet<T> &lhs, f_packet<T> &rhs) {
//    return f_packet<T>(lhs.data - rhs.data, lhs.dvalid, lhs.last);
//}
//template <typename T>
//friend f_packet<T> operator*(f_packet<T> &lhs, f_packet<T> &rhs) {
//    return f_packet<T>(lhs.data * rhs.data, lhs.dvalid, lhs.last);
//}
//template <typename T>
//friend f_packet<T> operator/(f_packet<T> &lhs, f_packet<T> &rhs) {
//    return f_packet<T>(lhs.data / rhs.data, lhs.dvalid, lhs.last);
//}
//template <typename T>
//friend bool operator==(f_packet<T> &lhs, f_packet<T> &rhs) {
//    return lhs.data == rhs.data;
//}
//template <typename T>
//friend bool operator!=(f_packet<T> &lhs, f_packet<T> &rhs) {
//    return !(rhs == lhs);
//}
//
//#pragma endregion
//
//#pragma region Packet <-> Base type operators
//template <typename T>
//friend bool operator<(f_packet<T> &lhs, T &rhs) {
//    return lhs.data < rhs;
//}
//template <typename T>
//friend bool operator>(f_packet<T> &lhs, T &rhs) {
//    return rhs < lhs;
//}
//template <typename T>
//friend bool operator<=(f_packet<T> &lhs, T &rhs) {
//    return !(rhs < lhs);
//}
//template <typename T>
//friend bool operator>=(f_packet<T> &lhs, T &rhs) {
//    return !(lhs < rhs);
//}
//template <typename T>
//friend f_packet<T> operator+(f_packet<T> &lhs, T &rhs) {
//    return f_packet<T>(lhs.data + rhs, lhs.dvalid, lhs.last);
//}
//template <typename T>
//friend f_packet<T> operator-(f_packet<T> &lhs, T &rhs) {
//    return f_packet<T>(lhs.data - rhs, lhs.dvalid, lhs.last);
//}
//template <typename T>
//friend f_packet<T> operator*(f_packet<T> &lhs, T &rhs) {
//    return f_packet<T>(lhs.data * rhs, lhs.dvalid, lhs.last);
//}
//template <typename T>
//friend f_packet<T> operator/(f_packet<T> &lhs, T &rhs) {
//    return f_packet<T>(lhs.data / rhs, lhs.dvalid, lhs.last);
//}
//template <typename T>
//friend bool operator==(f_packet<T> &lhs, T &rhs) {
//    return lhs.data == rhs;
//}
//template <typename T>
//friend bool operator!=(f_packet<T> &lhs, T &rhs) {
//    return !(rhs == lhs);
//}
//
//#pragma endregion
//
//#pragma region Base type <-> Packet operators
//template <typename T>
//friend bool operator<(T &lhs, f_packet<T> &rhs) {
//    return lhs < rhs.data;
//}
//template <typename T>
//friend bool operator>(T &lhs, f_packet<T> &rhs) {
//    return rhs < lhs;
//}
//template <typename T>
//friend bool operator<=(T &lhs, f_packet<T> &rhs) {
//    return !(rhs < lhs);
//}
//template <typename T>
//friend bool operator>=(T &lhs, f_packet<T> &rhs) {
//    return !(lhs < rhs);
//}
//template <typename T>
//friend f_packet<T> operator+(T &lhs, f_packet<T> &rhs) {
//    return f_packet<T>(lhs + rhs.data, rhs.dvalid, rhs.last);
//}
//template <typename T>
//friend f_packet<T> operator-(T &lhs, f_packet<T> &rhs) {
//    return f_packet<T>(lhs - rhs.data, rhs.dvalid, rhs.last);
//}
//template <typename T>
//friend f_packet<T> operator*(T &lhs, f_packet<T> &rhs) {
//    return f_packet<T>(lhs * rhs.data, rhs.dvalid, rhs.last);
//}
//template <typename T>
//friend f_packet<T> operator/(T &lhs, f_packet<T> &rhs) {
//    return f_packet<T>(lhs / rhs.data, rhs.dvalid, rhs.last);
//}
//template <typename T>
//friend bool operator==(T &lhs, f_packet<T> &rhs) {
//    return lhs == rhs.data;
//}
//template <typename T>
//friend bool operator!=(T &lhs, f_packet<T> &rhs) {
//    return !(rhs == lhs);
//}
//
//#pragma endregion
