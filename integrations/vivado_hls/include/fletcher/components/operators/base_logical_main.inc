// Packet <-> Packet
template <typename T>
bool operator OP(f_packet<T> &lhs, f_packet<T> &rhs) {
    return lhs.data OP rhs.data;
}
template <typename T>
bool operator OP(f_packet<T> &&lhs, f_packet<T> &&rhs) {
    return lhs OP rhs;
}
template <typename T>
bool operator OP(f_packet<T> &&lhs, f_packet<T> &rhs) {
    return lhs OP rhs;
}
template <typename T>
bool operator OP(f_packet<T> &lhs, f_packet<T> &&rhs) {
    return lhs OP rhs;
}

// Packet <-> base types
template <typename T>
bool operator OP(T &lhs, f_packet<T> &rhs) {
    return lhs OP rhs.data;
}

template <typename T>
bool operator OP(f_packet<T> &lhs, T &rhs) {
    return lhs.data OP rhs;
}

// Packet <-> ctypes (like ints and other castable basics)
template <typename T>
bool operator OP(f_packet<T> &lhs, typename f_packet<T>::inner_type &&rhs) {
    return lhs.data OP rhs;
}

template <typename T>
bool operator OP(typename f_packet<T>::inner_type &&lhs, f_packet<T> &rhs) {
    return lhs OP rhs.data;
}

// Nullable <-> Nullable
template <typename T>
bool operator OP(nullable<T> &lhs, nullable<T> &rhs) {
    if (lhs.valid && rhs.valid) {
        return (static_cast<T&>(lhs) OP static_cast<T&>(rhs));
    }
    return false;
}

template <typename T>
bool operator OP(nullable<T> &&lhs, nullable<T> &&rhs) {
    return lhs OP rhs;
}

template <typename T>
bool operator OP(nullable<T> &&lhs, nullable<T> &rhs) {
    return lhs OP rhs;
}

template <typename T>
bool operator OP(nullable<T> &lhs, nullable<T> &&rhs) {
    return lhs OP rhs;
}

// Nullable <-> Packet
template <typename T>
bool operator OP(nullable<T> &lhs, T &&rhs) {
    if (lhs.valid) {
        return (static_cast<T&>(lhs) OP rhs);
    }
    return false;
}

template <typename T>
bool operator OP(T &&lhs, nullable<T> &rhs) {
    if (rhs.valid) {
        return (lhs OP static_cast<T>(rhs));
    }
    return false;
}

// Nullable <-> Base types and ctypes
template <typename T>
bool operator OP(nullable<T> &lhs, typename T::inner_type rhs){
    if (lhs.valid) {
        return (static_cast<T&>(lhs) OP static_cast<typename T::inner_type>(rhs));
    }
    return false;
}

template <typename T>
bool operator OP(typename T::inner_type lhs, nullable<T> &rhs){
    if (rhs.valid) {
        return (static_cast<typename T::inner_type>(lhs) OP static_cast<T&>(rhs));
    }
    return false;
}
