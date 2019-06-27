#pragma once

#include "../packet.h"
#include "../nullable.h"

#define OP ==

#include "base_logical_main.inc"

#define OP <

#include "base_logical_main.inc"

#undef OP
// Packet <-> Packet
#define TYPEL f_packet<T> &
#define TYPER TYPEL

#include "base_logical_derived.inc"

#define TYPEL f_packet<T> &&
#define TYPER TYPEL

#include "base_logical_derived.inc"

#define TYPEL f_packet<T> &&
#define TYPER f_packet<T> &

#include "base_logical_derived.inc"

#define TYPEL f_packet<T> &
#define TYPER f_packet<T> &&

#include "base_logical_derived.inc"

// Packet <-> base types
#define TYPEL f_packet<T> &
#define TYPER T &

#include "base_logical_derived.inc"

#define TYPEL T &
#define TYPER f_packet<T> &

#include "base_logical_derived.inc"

// Packet <-> ctypes (like ints and other castable basics)
#define TYPEL f_packet<T> &
#define TYPER typename f_packet<T>::inner_type &&

#include "base_logical_derived.inc"

#define TYPEL typename f_packet<T>::inner_type &&
#define TYPER f_packet<T> &

#include "base_logical_derived.inc"

// Nullable <-> Nullable
#define TYPEL nullable<T> &
#define TYPER TYPEL

#include "base_logical_derived.inc"

#define TYPEL nullable<T> &&
#define TYPER TYPEL

#include "base_logical_derived.inc"

#define TYPEL nullable<T> &&
#define TYPER nullable<T> &

#include "base_logical_derived.inc"

#define TYPEL nullable<T> &
#define TYPER nullable<T> &&

#include "base_logical_derived.inc"

// Nullable <-> Packet
#define TYPEL nullable<T> &
#define TYPER T &&

#include "base_logical_derived.inc"

#define TYPEL T &&
#define TYPER nullable<T> &

#include "base_logical_derived.inc"

// Nullable <-> Base types and ctypes
#define TYPEL nullable<T> &
#define TYPER typename T::inner_type

#include "base_logical_derived.inc"

#define TYPEL typename T::inner_type
#define TYPER nullable<T> &

#include "base_logical_derived.inc"