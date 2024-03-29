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

/**
 * This file contains the Fletcher run-time global C header.
 */

#include <stdint.h>

/**
 * \brief Names of platforms to attempt to autodetect by checking if a driver is available.
 *
 * Echo should always be the last platform to test for, as the platforms are attempted in the order of this list.
 */
#define FLETCHER_AUTODETECT_PLATFORMS "oc-accel", "snap", "aws", "echo"

#define FLETCHER_STATUS_OK 0
#define FLETCHER_STATUS_ERROR 1
#define FLETCHER_STATUS_NO_PLATFORM 2
#define FLETCHER_STATUS_DEVICE_OUT_OF_MEMORY 3

/// Status for function return values
typedef uint64_t fstatus_t;

/// Device Address type
typedef uint64_t da_t;

/// Register type
typedef uint32_t freg_t;

/// Convenience union to convert addresses to a high and low part
typedef union {
  struct {
    uint32_t lo;
    uint32_t hi;
  };
  da_t full;
} dau_t;

/// Device nullptr
#define D_NULLPTR (da_t) 0x0

/// Hardware default registers
#define FLETCHER_REG_CONTROL        0
#define FLETCHER_REG_STATUS         1
#define FLETCHER_REG_RETURN0        2
#define FLETCHER_REG_RETURN1        3

/// Offset for schema derived registers
#define FLETCHER_REG_SCHEMA         4

#define FLETCHER_REG_CONTROL_START  0x0u
#define FLETCHER_REG_CONTROL_STOP   0x1u
#define FLETCHER_REG_CONTROL_RESET  0x2u

#define FLETCHER_REG_STATUS_IDLE    0x0u
#define FLETCHER_REG_STATUS_BUSY    0x1u
#define FLETCHER_REG_STATUS_DONE    0x2u
