
template <typename T>
f_packet<T> operator OP(f_packet<T> &rhs) {
    return f_packet<T>(OP rhs.data, rhs.dvalid, rhs.last);
}
template <typename T>
f_packet<T> operator OP(f_packet<T> &&rhs) {
    return OP rhs;
}

template <typename T>
nullable<T> operator OP(nullable<T> &rhs){
    return nullable<T>(rhs.valid, (OP (static_cast<T&>(rhs))));
}

template <typename T>
nullable<T> operator OP(nullable<T> &&rhs){
    return OP rhs;
}