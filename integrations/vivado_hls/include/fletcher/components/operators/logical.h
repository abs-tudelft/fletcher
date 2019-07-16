#pragma once

#include "../packet.h"
#include "../nullable.h"
#define OP ==

#include "base_logical_main.inc"
#undef OP
#define OP <

#include "base_logical_main.inc"

#undef OP
// Packet <-> Packet
#undef TYPEL
#undef TYPER
#define TYPEL f_packet<T> &
#define TYPER TYPEL

#include "base_logical_derived.inc"

#undef TYPEL
#undef TYPER
#define TYPEL f_packet<T> &&
#define TYPER TYPEL

#include "base_logical_derived.inc"

#undef TYPEL
#undef TYPER
#define TYPEL f_packet<T> &&
#define TYPER f_packet<T> &

#include "base_logical_derived.inc"

#undef TYPEL
#undef TYPER
#define TYPEL f_packet<T> &
#define TYPER f_packet<T> &&

#include "base_logical_derived.inc"

// Packet <-> base types
#undef TYPEL
#undef TYPER
#define TYPEL f_packet<T> &
#define TYPER T &

#include "base_logical_derived.inc"

#undef TYPEL
#undef TYPER
#define TYPEL T &
#define TYPER f_packet<T> &

#include "base_logical_derived.inc"

// Packet <-> ctypes (like ints and other castable basics)
#undef TYPEL
#undef TYPER
#define TYPEL f_packet<T> &
#define TYPER typename f_packet<T>::inner_type &&

#include "base_logical_derived.inc"

#undef TYPEL
#undef TYPER
#define TYPEL typename f_packet<T>::inner_type &&
#define TYPER f_packet<T> &

#include "base_logical_derived.inc"

// Nullable <-> Nullable
#undef TYPEL
#undef TYPER
#define TYPEL nullable<T> &
#define TYPER TYPEL

#include "base_logical_derived.inc"

#undef TYPEL
#undef TYPER
#define TYPEL nullable<T> &&
#define TYPER TYPEL

#include "base_logical_derived.inc"

#undef TYPEL
#undef TYPER
#define TYPEL nullable<T> &&
#define TYPER nullable<T> &

#include "base_logical_derived.inc"

#undef TYPEL
#undef TYPER
#define TYPEL nullable<T> &
#define TYPER nullable<T> &&

#include "base_logical_derived.inc"

// Nullable <-> Packet
#undef TYPEL
#undef TYPER
#define TYPEL nullable<T> &
#define TYPER T &&

#include "base_logical_derived.inc"

#undef TYPEL
#undef TYPER
#define TYPEL T &&
#define TYPER nullable<T> &

#include "base_logical_derived.inc"

// Nullable <-> Base types and ctypes
#undef TYPEL
#undef TYPER
#define TYPEL nullable<T> &
#define TYPER typename T::inner_type

#include "base_logical_derived.inc"

#undef TYPEL
#undef TYPER
#define TYPEL typename T::inner_type
#define TYPER nullable<T> &

#include "base_logical_derived.inc"

#undef TYPEL
#undef TYPER