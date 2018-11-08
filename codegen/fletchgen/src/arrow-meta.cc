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

#include <string>
#include <memory>
#include <vector>
#include <utility>
#include <iostream>
#include <algorithm>

#include "arrow-meta.h"
#include "fletcher/common/arrow-utils.h"

using vhdl::Value;

namespace fletchgen {

Value getWidth(arrow::DataType *type) {
  // Fixed-width:
  if (type->id() == arrow::Type::BOOL) return Value(1);
  else if (type->id() == arrow::Type::DATE32) return Value(32);
  else if (type->id() == arrow::Type::DATE64) return Value(64);
  else if (type->id() == arrow::Type::DOUBLE) return Value(64);
  else if (type->id() == arrow::Type::FLOAT) return Value(32);
  else if (type->id() == arrow::Type::HALF_FLOAT) return Value(16);
  else if (type->id() == arrow::Type::INT8) return Value(8);
  else if (type->id() == arrow::Type::INT16) return Value(16);
  else if (type->id() == arrow::Type::INT32) return Value(32);
  else if (type->id() == arrow::Type::INT64) return Value(64);
  else if (type->id() == arrow::Type::TIME32) return Value(32);
  else if (type->id() == arrow::Type::TIME64) return Value(64);
  else if (type->id() == arrow::Type::TIMESTAMP) return Value(64);
  else if (type->id() == arrow::Type::UINT8) return Value(8);
  else if (type->id() == arrow::Type::UINT16) return Value(16);
  else if (type->id() == arrow::Type::UINT32) return Value(32);
  else if (type->id() == arrow::Type::UINT64) return Value(64);

    // Lists:
  else if (type->id() == arrow::Type::LIST) return Value("INDEX_WIDTH");
  else if (type->id() == arrow::Type::BINARY) return Value("INDEX_WIDTH");
  else if (type->id() == arrow::Type::STRING) return Value("INDEX_WIDTH");

    // Others:
    //if (type->id() == arrow::Type::INTERVAL) return 0;
    //if (type->id() == arrow::Type::MAP) return 0;
    //if (type->id() == arrow::Type::NA) return 0;
    //if (type->id() == arrow::Type::DICTIONARY) return 0;
    //if (type->id() == arrow::Type::UNION) return 0;


    // Structs have no width
  else if (type->id() == arrow::Type::STRUCT) return Value(0);

  else if (type->id() == arrow::Type::FIXED_SIZE_BINARY) {
    auto t = dynamic_cast<arrow::FixedSizeBinaryType *>(type);
    return Value(t->bit_width());
  } else if (type->id() == arrow::Type::DECIMAL) {
    auto t = dynamic_cast<arrow::DecimalType *>(type);
    return Value(t->bit_width());
  }

  return Value(-1);
}

ConfigType getConfigType(arrow::DataType *type) {
  ConfigType ret = ConfigType::PRIM;

  /* Fixed-width:
  if (type->id() == arrow::Type::BOOL)
  if (type->id() == arrow::Type::DATE32)
  if (type->id() == arrow::Type::DATE64)
  if (type->id() == arrow::Type::DOUBLE)
  if (type->id() == arrow::Type::FLOAT)
  if (type->id() == arrow::Type::HALF_FLOAT)
  if (type->id() == arrow::Type::INT8)
  if (type->id() == arrow::Type::INT16)
  if (type->id() == arrow::Type::INT32)
  if (type->id() == arrow::Type::INT64)
  if (type->id() == arrow::Type::TIME32)
  if (type->id() == arrow::Type::TIME64)
  if (type->id() == arrow::Type::TIMESTAMP)
  if (type->id() == arrow::Type::UINT8)
  if (type->id() == arrow::Type::UINT16)
  if (type->id() == arrow::Type::UINT32)
  if (type->id() == arrow::Type::UINT64)
  if (type->id() == arrow::Type::FIXED_SIZE_BINARY)
  if (type->id() == arrow::Type::DECIMAL)
  */

  // Lists:
  if (type->id() == arrow::Type::LIST) ret = ConfigType::LIST;
  else if (type->id() == arrow::Type::BINARY) ret = ConfigType::LISTPRIM;
  else if (type->id() == arrow::Type::STRING) ret = ConfigType::LISTPRIM;

    // Others:
    //if (type->id() == arrow::Type::INTERVAL) return 0;
    //if (type->id() == arrow::Type::MAP) return 0;
    //if (type->id() == arrow::Type::NA) return 0;
    //if (type->id() == arrow::Type::DICTIONARY) return 0;
    //if (type->id() == arrow::Type::UNION) return 0;

    // Structs
  else if (type->id() == arrow::Type::STRUCT) ret = ConfigType::STRUCT;

  return ret;
}

std::string getModeString(Mode mode) {
  if (mode == Mode::READ) {
    return "read";
  } else {
    return "write";
  }
}

}  // namespace fletchgen
