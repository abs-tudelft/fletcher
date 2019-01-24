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

#include <arrow/api.h>
#include <string>
#include <memory>

#include "./types.h"
#include "./nodes.h"

namespace fletchgen {

// Create basic types corresponding to and in the manner of Arrow's types
#define BIT_DECL_FACTORY(NAME)        std::shared_ptr<Type> NAME();
#define VEC_DECL_FACTORY(NAME, WIDTH) std::shared_ptr<Type> NAME();

BIT_DECL_FACTORY(bit);
BIT_DECL_FACTORY(null);
BIT_DECL_FACTORY(boolean);

VEC_DECL_FACTORY(int8, 8);
VEC_DECL_FACTORY(uint8, 8);
VEC_DECL_FACTORY(int16, 16);
VEC_DECL_FACTORY(uint16, 16);
VEC_DECL_FACTORY(int32, 32);
VEC_DECL_FACTORY(uint32, 32);
VEC_DECL_FACTORY(int64, 64);
VEC_DECL_FACTORY(uint64, 64);
VEC_DECL_FACTORY(float8, 8);
VEC_DECL_FACTORY(float16, 16);
VEC_DECL_FACTORY(float32, 32);
VEC_DECL_FACTORY(float64, 64);
VEC_DECL_FACTORY(date32, 32);
VEC_DECL_FACTORY(date64, 64);
VEC_DECL_FACTORY(utf8c, 8);
VEC_DECL_FACTORY(byte, 8);
VEC_DECL_FACTORY(offset, 32);
VEC_DECL_FACTORY(length, 32);
std::shared_ptr<Type> string();
std::shared_ptr<Type> natural();
std::shared_ptr<Literal> natval(int val);
std::shared_ptr<Literal> natval(std::string val);
std::shared_ptr<Literal> bool_true();
std::shared_ptr<Literal> bool_false();

/// @brief Fletcher accelerator clock domain
std::shared_ptr<ClockDomain> acc_domain();

/// @brief Fletcher bus clock domain
std::shared_ptr<ClockDomain> bus_domain();

/// @brief Fletcher accelerator clock
std::shared_ptr<Type> acc_clk();

/// @brief Fletcher accelerator reset
std::shared_ptr<Type> acc_reset();

/// @brief Fletcher bus clock
std::shared_ptr<Type> bus_clk();

/// @brief Fletcher bus reset
std::shared_ptr<Type> bus_reset();

std::shared_ptr<Type> bus_read_request();
std::shared_ptr<Type> bus_read_data();
std::shared_ptr<Type> bus_write_request();
std::shared_ptr<Type> bus_write_data();

std::shared_ptr<Type> cmd();
std::shared_ptr<Type> unlock();
std::shared_ptr<Type> read_data();

std::shared_ptr<Type> GenTypeFrom(const std::shared_ptr<arrow::DataType>& type);
std::string GenerateSuffix(const std::shared_ptr<arrow::DataType>& type);

}  // namespace fletchgen
