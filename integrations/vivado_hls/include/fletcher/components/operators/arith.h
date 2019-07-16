#pragma once

#include "../packet.h"
#include "../nullable.h"
#define OP +

#include "base_arith.inc"
#include "base_unary.inc"
#undef OP
#define OP -

#include "base_arith.inc"
#include "base_unary.inc"
#undef OP
#define OP *

#include "base_arith.inc"
#undef OP
#define OP /

#include "base_arith.inc"
#undef OP
#define OP %

#include "base_arith.inc"
#undef OP
#define OP &

#include "base_arith.inc"
#undef OP
#define OP |

#include "base_arith.inc"
#undef OP
#define OP ^

#include "base_arith.inc"
#undef OP
#define OP ~

#include "base_unary.inc"
#undef OP
#define OP <<

#include "base_arith.inc"
#undef OP
#define OP >>

#include "base_arith.inc"
#undef OP