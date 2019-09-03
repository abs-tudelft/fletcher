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
#include <cerata/api.h>
#include <fletcher/common.h>
#include <string>
#include <memory>
#include <locale>

namespace fletchgen {

/// Metadata keys
namespace metakeys {
  /// Key for automated type mapping.
  constexpr char ARRAY_DATA[] = "fletchgen_array_data";

  /// Key for elements-per-cycle on streams.
  constexpr char EPC[] = "fletcher_epc";

  /// Key for length-elements-per-cycle on length streams. Must be seperate from EPC for "listprim" config string.
  constexpr char LEPC[] = "fletcher_lepc";
}

using cerata::Type;
using cerata::Node;
using cerata::ClockDomain;
using cerata::TypeMapper;

// Generate declaration for basic types corresponding to and in the manner of Arrow's types
#define BIT_DECL_FACTORY(NAME)        std::shared_ptr<Type> NAME();

/// Generate declaration for basic, multi-bit types similar to Arrow cpp/type.cc for convenience
#define VEC_DECL_FACTORY(NAME, WIDTH) std::shared_ptr<Type> NAME();

BIT_DECL_FACTORY(validity)
VEC_DECL_FACTORY(int8, 8)
VEC_DECL_FACTORY(uint8, 8)
VEC_DECL_FACTORY(int16, 16)
VEC_DECL_FACTORY(uint16, 16)
VEC_DECL_FACTORY(int32, 32)
VEC_DECL_FACTORY(uint32, 32)
VEC_DECL_FACTORY(int64, 64)
VEC_DECL_FACTORY(uint64, 64)
VEC_DECL_FACTORY(float8, 8)
VEC_DECL_FACTORY(float16, 16)
VEC_DECL_FACTORY(float32, 32)
VEC_DECL_FACTORY(float64, 64)
VEC_DECL_FACTORY(date32, 32)
VEC_DECL_FACTORY(date64, 64)
VEC_DECL_FACTORY(utf8c, 8)
VEC_DECL_FACTORY(byte, 8)
VEC_DECL_FACTORY(offset, 32)

/// Generate declaration for generic Fletcher parameters.
#define PARAM_DECL_FACTORY(NAME) std::shared_ptr<Node> NAME();

PARAM_DECL_FACTORY(bus_addr_width)
PARAM_DECL_FACTORY(bus_data_width)
PARAM_DECL_FACTORY(bus_strobe_width)
PARAM_DECL_FACTORY(bus_len_width)
PARAM_DECL_FACTORY(bus_burst_step_len)
PARAM_DECL_FACTORY(bus_burst_max_len)
PARAM_DECL_FACTORY(index_width)

/// @brief Fletcher accelerator clock domain
std::shared_ptr<ClockDomain> kernel_domain();
/// @brief Fletcher bus clock domain
std::shared_ptr<ClockDomain> bus_domain();
/// @brief Fletcher data
std::shared_ptr<Type> data(const std::shared_ptr<Node> &width);
/// @brief Fletcher length
std::shared_ptr<Type> length(const std::shared_ptr<Node> &width);
/// @brief Fletcher count
std::shared_ptr<Type> count(const std::shared_ptr<Node> &width);
/// @brief Fletcher dvalid
std::shared_ptr<Type> dvalid();
/// @brief Fletcher last
std::shared_ptr<Type> last();
/// @brief Fletcher clock/reset;
std::shared_ptr<Type> cr();

/**
 * @brief Convert a fixed-width arrow::DataType to a fixed-width Fletcher Type.
 *
 * Does not take into consideration nesting.
 *
 * @param arrow_type    The arrow::DataType.
 * @return              The corresponding Type
 */
std::shared_ptr<Type> ConvertFixedWidthType(const std::shared_ptr<arrow::DataType> &arrow_type);

}  // namespace fletchgen
