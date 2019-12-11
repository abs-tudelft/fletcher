// Copyright 2018-2019 Delft University of Technology
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

namespace fletchgen {

/// Fletchgen metadata keys for Cerata objects.
namespace meta {
/// Key for automated type mapping.
constexpr char ARRAY_DATA[] = "fletchgen_array_data";
/// Key to mark the count field in Arrow data streams.
constexpr char COUNT[] = "fletchgen_count";
/// Key to mark the last field in Arrow data streams.
constexpr char LAST[] = "fletchgen_last";
}

using cerata::Type;
using cerata::Node;
using cerata::ClockDomain;
using cerata::TypeMapper;
using cerata::Parameter;

// Generate declaration for basic types corresponding to and in the manner of Arrow's types
#define BIT_DECL_FACTORY(NAME) std::shared_ptr<Type> NAME();

/// Creates basic, single-bit types similar to Arrow cpp/type.cc for convenience
#define BIT_FACTORY(NAME)                        \
  std::shared_ptr<Type> NAME() {                 \
    static std::shared_ptr<Type> result = bit(); \
    return result;                               \
  }

/// Generate declaration for basic, multi-bit types similar to Arrow cpp/type.cc for convenience
#define VEC_DECL_FACTORY(NAME, WIDTH) std::shared_ptr<Type> NAME();

/// Creates basic, multi-bit types similar to Arrow cpp/type.cc for convenience, including their nullable versions.
#define VEC_FACTORY(NAME, WIDTH)                                \
  std::shared_ptr<Type> NAME() {                                \
    static std::shared_ptr<Type> result = vector(#NAME, WIDTH); \
    return result;                                              \
  }

/// Macro for declarations for Fletcher parameters.
#define PARAM_DECL_FACTORY(NAME, VALUE) std::shared_ptr<Parameter> NAME(int64_t value = VALUE,           \
                                                                        const std::string& prefix = "");

/// Macro for implementation of Fletcher parameters.
#define PARAM_FACTORY(NAME)                                                 \
std::shared_ptr<Parameter> NAME(int64_t value, const std::string& prefix) { \
  auto name = std::string(#NAME);                                           \
  for (auto &ch : name) ch = std::toupper(ch);                              \
  if (!prefix.empty()) {name = prefix + "_" + name;}                        \
  auto result = parameter(name, cerata::integer(), intl(value));            \
  return result;                                                            \
}

// Arrow equivalent Cerata types:
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

/// @brief Fletcher accelerator clock domain
std::shared_ptr<ClockDomain> kernel_cd();
/// @brief Fletcher bus clock domain
std::shared_ptr<ClockDomain> bus_cd();
/// @brief Fletcher clock/reset;
std::shared_ptr<Type> cr();
/// @brief Fletcher valid
std::shared_ptr<Type> valid(int width = 1, bool on_primitive = false);
/// @brief Fletcher ready
std::shared_ptr<Type> ready(int width = 1, bool on_primitive = false);
/// @brief Fletcher data
std::shared_ptr<Type> data(int width);
/// @brief Fletcher length
std::shared_ptr<Type> length(int width);
/// @brief Fletcher count
std::shared_ptr<Type> count(int width);
/// @brief Fletcher dvalid
std::shared_ptr<Type> dvalid(int width = 1, bool on_primitive = false);
/// @brief Fletcher last
std::shared_ptr<Type> last(int width = 1, bool on_primitive = false);

/**
 * @brief Convert a fixed-width arrow::DataType to a fixed-width Fletcher Type.
 *
 * Does not take into consideration nesting.
 *
 * @param arrow_type    The arrow::DataType.
 * @return              The corresponding Type
 */
std::shared_ptr<Type> ConvertFixedWidthType(const std::shared_ptr<arrow::DataType> &arrow_type, int epc = 1);

/**
 * @brief Return the clock/reset port of a graph for a specific clock domain, if it exists.
 * @param graph   The graph to find the port for.
 * @param domain  The domain to find the port for.
 * @return        Optionally, the port node that holds the clock/reset record.
 */
std::optional<cerata::Port *> GetClockResetPort(cerata::Graph *graph, const ClockDomain &domain);

}  // namespace fletchgen
