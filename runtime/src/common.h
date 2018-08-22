// Copyright 2018 Delft University of Technology
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#pragma once

#include <cstdint>

namespace fletcher {

constexpr int OK=0;
constexpr int ERROR=-1;

/// Fletcher Address Type
typedef uint64_t fa_t;

/// Fletcher Register Type
typedef uint64_t fr_t;

/**
 * A Buffer configuration element
 */
typedef struct _BufConfig {
  std::string name;
  fa_t address;
  int64_t size;     // Arrow makes this signed int
  int64_t capacity;  // This as well
} BufConfig;

/**
 * A structure to help in converting from 2x32 bit registers to 1x64 bit register and vice versa
 */
struct reg_conv_hilo {
  uint32_t lo;
  uint32_t hi;
};

/**
 * A union type to help in converting from 2x32 bit registers to 1x64 bit register and vice versa
 */
typedef union {
  fr_t full;
  struct reg_conv_hilo half;
} reg_conv_t;

}
