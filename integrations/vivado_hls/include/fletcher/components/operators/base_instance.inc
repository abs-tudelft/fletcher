
template <typename T>
f_packet<T> operator OP(f_packet<T> &val) {
    OP val.data;
    return val;
}

template <typename T>
nullable<T> operator OP(nullable<T> &val){
    if(val.valid){
        (OP val);
    }
    return val;
}

template <typename T>
f_packet<T> operator OP(f_packet<T> &val, int) {
    f_packet<T> tmp(val);
    OP val; // prefix-increment this instance
    return tmp;   // return value before increment
}

template <typename T>
nullable<T> operator OP(nullable<T> &val, int){
    nullable<T> tmp(val);
    if(val.valid){
        (OP(static_cast<T&>(val)));
    }
    return tmp;
}