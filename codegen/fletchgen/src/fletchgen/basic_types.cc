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

#include "fletchgen/basic_types.h"

#include <memory>
#include <cmath>

#include <cerata/api.h>
#include <fletcher/common.h>

namespace fletchgen {

using cerata::Type;
using cerata::Vector;
using cerata::Bit;
using cerata::bit;
using cerata::intl;
using cerata::integer;
using cerata::Clock;
using cerata::Reset;
using cerata::Parameter;
using cerata::RecField;
using cerata::Record;
using cerata::Stream;
using cerata::Literal;

// Create basic types similar to Arrow cpp/type.cc for convenience
#define BIT_FACTORY(NAME)                                               \
  std::shared_ptr<Type> NAME() {                                        \
    static std::shared_ptr<Type> result = std::make_shared<Bit>(#NAME); \
    return result;                                                      \
}

#define VEC_FACTORY(NAME, WIDTH)                                                     \
  std::shared_ptr<Type> NAME() {                                                     \
    static std::shared_ptr<Type> result = Vector::Make(#NAME, bit(), intl<WIDTH>()); \
    return result;                                                                   \
}

BIT_FACTORY(null)
VEC_FACTORY(int8, 8)
VEC_FACTORY(uint8, 8)
VEC_FACTORY(int16, 16)
VEC_FACTORY(uint16, 16)
VEC_FACTORY(int32, 32)
VEC_FACTORY(uint32, 32)
VEC_FACTORY(int64, 64)
VEC_FACTORY(uint64, 64)
VEC_FACTORY(float8, 8)
VEC_FACTORY(float16, 16)
VEC_FACTORY(float32, 32)
VEC_FACTORY(float64, 64)
VEC_FACTORY(date32, 32)
VEC_FACTORY(date64, 64)
VEC_FACTORY(utf8c, 8)
VEC_FACTORY(byte, 8)
VEC_FACTORY(offset, 32)

#define PARAM_FACTORY(NAME, TYPE, DEFAULT)                    \
std::shared_ptr<Node> NAME() {                                \
  static auto result = Parameter::Make(#NAME, TYPE, DEFAULT); \
  return result;                                              \
}                                                             \

PARAM_FACTORY(bus_addr_width, integer(), intl<64>())
PARAM_FACTORY(bus_data_width, integer(), intl<512>())
PARAM_FACTORY(bus_strobe_width, integer(), intl<64>())
PARAM_FACTORY(bus_len_width, integer(), intl<8>())
PARAM_FACTORY(bus_burst_step_len, integer(), intl<4>())
PARAM_FACTORY(bus_burst_max_len, integer(), intl<16>())
PARAM_FACTORY(index_width, integer(), intl<32>())

// Create basic clock domains
std::shared_ptr<ClockDomain> kernel_domain() {
  static std::shared_ptr<ClockDomain> result = std::make_shared<ClockDomain>("kcd");
  return result;
}

std::shared_ptr<ClockDomain> bus_domain() {
  static std::shared_ptr<ClockDomain> result = std::make_shared<ClockDomain>("bcd");
  return result;
}

// Create basic clocks & resets
std::shared_ptr<Type> kernel_cr() {
  static std::shared_ptr<Type> result = Record::Make("kcd", {
      RecField::Make("clk", std::make_shared<Clock>("kcd_clk", kernel_domain())),
      RecField::Make("reset", std::make_shared<Reset>("kcd_reset", kernel_domain()))});
  return result;
}

std::shared_ptr<Type> bus_cr() {
  static std::shared_ptr<Type> result = Record::Make("bcd", {
      RecField::Make("clk", std::make_shared<Clock>("bcd_clk", bus_domain())),
      RecField::Make("reset", std::make_shared<Reset>("bcd_reset", bus_domain()))});
  return result;
}

// Data channel
std::shared_ptr<Type> data(const std::shared_ptr<Node> &width) {
  std::shared_ptr<Type> result = Vector::Make("data", width);
  // Mark this type so later we can figure out that it was concatenated onto the data port of an ArrayReader/Writer.
  result->meta["array_data"] = "true";
  return result;
}

// Length channel
std::shared_ptr<Type> length(const std::shared_ptr<Node> &width) {
  std::shared_ptr<Type> result = Vector::Make("length", width);
  // Mark this type so later we can figure out that it was concatenated onto the data port of an ArrayReader/Writer.
  result->meta["array_data"] = "true";
  return result;
}


std::shared_ptr<Type> count(const std::shared_ptr<Node> &width) {
  std::shared_ptr<Type> result = Vector::Make("count", width);
  // Mark this type so later we can figure out that it was concatenated onto the data port of an ArrayReader/Writer.
  result->meta["array_data"] = "true";
  return result;
}

std::shared_ptr<Type> dvalid() {
  static std::shared_ptr<Type> result = std::make_shared<Bit>("dvalid");
  return result;
}

std::shared_ptr<Type> last() {
  static std::shared_ptr<Type> result = std::make_shared<Bit>("last");
  return result;
}

std::shared_ptr<Type> GenTypeFrom(const std::shared_ptr<arrow::DataType> &arrow_type) {
    // Only need to cover fixed-width data types in this function
  switch (arrow_type->id()) {
    case arrow::Type::UINT8: return uint8();
    case arrow::Type::UINT16: return uint16();
    case arrow::Type::UINT32: return uint32();
    case arrow::Type::UINT64: return uint64();
    case arrow::Type::INT8: return int8();
    case arrow::Type::INT16: return int16();
    case arrow::Type::INT32: return int32();
    case arrow::Type::INT64: return int64();
    case arrow::Type::HALF_FLOAT: return float16();
    case arrow::Type::FLOAT: return float32();
    case arrow::Type::DOUBLE: return float64();
    default:throw std::runtime_error("Unsupported Arrow DataType: " + arrow_type->ToString());
  }
}

}  // namespace fletchgen
