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
#include <locale>

#include "../../../common/cpp/src/fletcher/common/arrow-utils.h"

#include "./types.h"
#include "./nodes.h"

namespace fletchgen {

// Create basic types corresponding to and in the manner of Arrow's types
#define BIT_DECL_FACTORY(NAME)        std::shared_ptr<Type> NAME();
#define VEC_DECL_FACTORY(NAME, WIDTH) std::shared_ptr<Type> NAME();

BIT_DECL_FACTORY(null);
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

/// @brief Fletcher

#define PARAM_DECL_FACTORY(NAME) std::shared_ptr<Node> NAME();
PARAM_DECL_FACTORY(bus_addr_width);
PARAM_DECL_FACTORY(bus_data_width);
PARAM_DECL_FACTORY(bus_len_width);
PARAM_DECL_FACTORY(bus_burst_step_len);
PARAM_DECL_FACTORY(bus_burst_max_len);

std::shared_ptr<ClockDomain> acc_domain(); ///< @brief Fletcher accelerator clock domain
std::shared_ptr<ClockDomain> bus_domain(); ///< @brief Fletcher bus clock domain
std::shared_ptr<Type> incomplete_data(); ///< @brief Fletcher data
std::shared_ptr<Type> dvalid(); ///< @brief Fletcher dvalid
std::shared_ptr<Type> last(); ///< @brief Fletcher last
std::shared_ptr<Type> acc_clk(); ///< @brief Fletcher accelerator clock
std::shared_ptr<Type> acc_reset(); ///< @brief Fletcher accelerator reset
std::shared_ptr<Type> bus_clk(); ///< @brief Fletcher bus clock
std::shared_ptr<Type> bus_reset(); ///< @brief Fletcher bus reset
std::shared_ptr<Type> bus_read_request(); ///< @brief Fletcher bus read request channel
std::shared_ptr<Type> bus_read_data(); ///< @brief Fletcher bus read data channel
std::shared_ptr<Type> bus_write_request(); ///< @brief Fletcher bus write request channel
std::shared_ptr<Type> bus_write_data(); ///< @brief Fletcher bus write data channel
std::shared_ptr<Type> cmd(); ///< @brief Fletcher command stream
std::shared_ptr<Type> unlock(); ///< @brief Fletcher unlock stream
std::shared_ptr<Type> read_data(); ///< @brief Fletcher read data
std::shared_ptr<Type> write_data(); ///< @brief Fletcher write data

/**
 * @brief Convert an arrow::DataType to a Fletcher Type.
 *
 * Does not take into consideration nesting.
 *
 * @param arrow_type    The arrow::DataType.
 * @return              The corresponding Type
 */
std::shared_ptr<Type> GenTypeFrom(const std::shared_ptr<arrow::DataType> &arrow_type);

/**
 * @brief Convert an Arrow::Field into a stream type.
 * @param field The Arrow::Field to convert.
 * @param level Nesting level.
 * @return The Stream Type.
 */
std::shared_ptr<Type> GetStreamType(const std::shared_ptr<arrow::Field> &field, fletcher::Mode mode, int level = 0);

std::shared_ptr<TypeMapper> GetStreamTypeConverter(const std::shared_ptr<Type> &stream_type, fletcher::Mode mode);

}  // namespace fletchgen
