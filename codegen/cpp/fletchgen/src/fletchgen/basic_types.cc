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

#include "fletchgen/basic_types.h"

#include <cerata/api.h>
#include <fletcher/common.h>

#include <memory>

namespace fletchgen {

using cerata::vector;
using cerata::bit;
using cerata::intl;
using cerata::integer;
using cerata::parameter;
using cerata::field;
using cerata::record;
using cerata::stream;

// Validity bit
BIT_FACTORY(validity)

// Non-nullable fixed-width types.
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

// Create basic clock domains
std::shared_ptr<ClockDomain> kernel_cd() {
  static std::shared_ptr<ClockDomain> result = std::make_shared<ClockDomain>("kcd");
  return result;
}

std::shared_ptr<ClockDomain> bus_cd() {
  static std::shared_ptr<ClockDomain> result = std::make_shared<ClockDomain>("bcd");
  return result;
}

// Create basic clock & reset record type
std::shared_ptr<Type> cr() {
  static std::shared_ptr<Type> result = record("cr", {
      field("clk", bit()),
      field("reset", bit())});
  return result;
}

std::shared_ptr<Type> valid(int width, bool on_primitive) {
  if (width > 1 || on_primitive) {
    return vector("valid", width);
  } else {
    return bit("valid");
  }
}

std::shared_ptr<Type> ready(int width, bool on_primitive) {
  if (width > 1 || on_primitive) {
    return vector("ready", width);
  } else {
    return bit("ready");
  }
}

// Data channel
std::shared_ptr<Type> data(int width) {
  std::shared_ptr<Type> result = vector("data", width);
  // Mark this type so later we can figure out that it was concatenated onto the data port of an ArrayReader/Writer.
  result->meta[meta::ARRAY_DATA] = "true";
  return result;
}

// Length channel
std::shared_ptr<Type> length(int width) {
  std::shared_ptr<Type> result = vector("length", width);
  // Mark this type so later we can figure out that it was concatenated onto the data port of an ArrayReader/Writer.
  result->meta[meta::ARRAY_DATA] = "true";
  return result;
}

std::shared_ptr<Type> count(int width) {
  std::shared_ptr<Type> result = vector(width);
  // Mark this type so later we can figure out that it was concatenated onto the data port of an ArrayReader/Writer.
  result->meta[meta::ARRAY_DATA] = "true";
  result->meta[meta::COUNT] = std::to_string(width);
  return result;
}

std::shared_ptr<Type> dvalid(int width, bool on_primitive) {
  if (width > 1 || on_primitive) {
    return vector("dvalid", width);
  } else {
    return bit("dvalid");
  }
}

std::shared_ptr<Type> last(int width, bool on_primitive) {
  std::shared_ptr<Type> result;
  if (width > 1 || on_primitive) {
    result = vector("last", width);
  } else {
    result = bit("last");
  }
  result->meta[meta::LAST] = "true";
  return result;
}

std::shared_ptr<Type> ConvertFixedWidthType(const std::shared_ptr<arrow::DataType> &arrow_type, int epc) {
  if (epc == 1) {
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
  } else {
    auto fwt = std::dynamic_pointer_cast<arrow::FixedWidthType>(arrow_type);
    if (fwt == nullptr) {
      FLETCHER_LOG(ERROR, "Not fixed width Arrow type: " + arrow_type->ToString());
    }
    return cerata::vector(epc * fwt->bit_width());
  }
}

std::optional<cerata::Port *> GetClockResetPort(cerata::Graph *graph, const ClockDomain &domain) {
  for (auto crn : graph->GetNodes()) {
    if (crn->type()->IsEqual(*cr()) && crn->IsPort()) {
      // TODO(johanpel): better comparison
      if (crn->AsPort()->domain().get() == &domain) {
        return crn->AsPort();
      }
    }
  }
  return std::nullopt;
}

}  // namespace fletchgen
