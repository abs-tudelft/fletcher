#pragma once

#include "../packet.h"
#include "../nullable.h"
#define OP ++

#include "base_instance.inc"
#undef OP
#define OP --

#include "base_instance.inc"

#undef OP