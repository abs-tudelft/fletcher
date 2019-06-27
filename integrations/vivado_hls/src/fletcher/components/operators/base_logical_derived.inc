template <typename T>
bool operator!=(TYPEL lhs, TYPER rhs) {
    return !(rhs == lhs);
}

template <typename T>
bool operator>(TYPEL lhs, TYPER rhs) {
    return rhs < lhs;
}
template <typename T>
bool operator<=(TYPEL lhs, TYPER rhs) {
    return !(rhs < lhs);
}
template <typename T>
bool operator>=(TYPEL lhs, TYPER rhs) {
    return !(lhs < rhs);
}