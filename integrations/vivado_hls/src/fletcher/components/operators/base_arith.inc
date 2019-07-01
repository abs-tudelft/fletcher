// Packet <-> Packet
template <typename T>
f_packet<T> operator OP(f_packet<T> &lhs, f_packet<T> &rhs) {
    return f_packet<T>(lhs.data OP rhs.data, lhs.dvalid, lhs.last);
}

template <typename T>
f_packet<T> operator OP(f_packet<T> &&lhs, f_packet<T> &&rhs) {
    return lhs OP rhs;
}

template <typename T>
f_packet<T> operator OP(f_packet<T> &lhs, f_packet<T> &&rhs) {
    return lhs OP rhs;
}

template <typename T>
f_packet<T> operator OP(f_packet<T> &&lhs, f_packet<T> &rhs) {
    return lhs OP rhs;
}

// Packet <-> base types
template <typename T>
f_packet<T> operator OP(f_packet<T> &lhs,T &rhs) {
    return f_packet<T>(lhs.data OP rhs, lhs.dvalid, lhs.last);
}

template <typename T>
f_packet<T> operator OP(T &lhs, f_packet<T> &rhs) {
    return f_packet<T>(lhs OP rhs.data, rhs.dvalid, rhs.last);
}

// Packet <-> ctypes (like ints and other castable basics)
template <typename T>
f_packet<T> operator OP(f_packet<T> &lhs, typename f_packet<T>::inner_type &&rhs) {
    return f_packet<T>(lhs.data OP rhs, lhs.dvalid, lhs.last);
}

template <typename T>
f_packet<T> operator OP(typename f_packet<T>::inner_type &&lhs, f_packet<T> &rhs) {
    return f_packet<T>(lhs OP rhs.data, rhs.dvalid, rhs.last);
}

// Nullable <-> Nullable
template <typename T>
nullable<T> operator OP(nullable<T> &lhs, nullable<T> &rhs){
    return nullable<T>(lhs.valid && rhs.valid, (static_cast<T&>(lhs) OP static_cast<T&>(rhs)));
}

template <typename T>
nullable<T> operator OP(nullable<T> &&lhs, nullable<T> &&rhs){
    return lhs OP rhs;
}

template <typename T>
nullable<T> operator OP(nullable<T> &&lhs, nullable<T> &rhs){
    return lhs OP rhs;
}

template <typename T>
nullable<T> operator OP(nullable<T> &lhs, nullable<T> &&rhs){
    return lhs OP rhs;
}

// Nullable <-> Packet
template <typename T>
nullable<T> operator OP(nullable<T> &lhs, T &&rhs){
    return nullable<T>(lhs.valid, (static_cast<T&>(lhs) OP rhs));
}

template <typename T>
nullable<T> operator OP(T &&lhs, nullable<T> &rhs){
    return nullable<T>(rhs.valid, (lhs OP static_cast<T&>(rhs)));
}

// Nullable <-> Base types and ctypes
template <typename T>
nullable<T> operator OP(nullable<T> &lhs, typename T::inner_type rhs){
    return nullable<T>(lhs.valid, (static_cast<T&>(lhs) OP static_cast<typename T::inner_type>(rhs)));
}

template <typename T>
nullable<T> operator OP(typename T::inner_type lhs, nullable<T> &rhs){
    return nullable<T>(rhs.valid, (static_cast<typename T::inner_type>(lhs) OP static_cast<T&>(rhs)));
}
