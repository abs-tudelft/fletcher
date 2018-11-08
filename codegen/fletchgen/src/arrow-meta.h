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

#include <vector>
#include <memory>
#include <string>

#include <arrow/type.h>

#include "./vhdl/vhdl.h"
#include "./common.h"

#include "fletcher/common/arrow-utils.h"

namespace fletchgen {

using fletcher::Mode;

/// @brief Types for configuration string.
enum class ConfigType {
  ARB,        ///< Arbiter level
  NUL,        ///< Null bitmap
  PRIM,       ///< Primitive (fixed-width) fields
  LIST,       ///< Variable length fields
  LISTPRIM,   ///< List of primitives, can have epc>1
  STRUCT      ///< Structs, composed of multiple fields
};

/**
 * @brief Convert an Arrow DataType to a port Width.
 * @param type The type to convert.
 * @return Width corresponding to the Arrow DataType.
 */
vhdl::Value getWidth(arrow::DataType *type);

/**
 * @brief Convert the Arrow type to a Fletcher configuration string type.
 * @param type The arrow::DataType to convert.
 * @return The Fletcher type for the configuration string
 */
ConfigType getConfigType(arrow::DataType *type);

/**
 * @brief Return a human readable version of a mode.
 * @param mode The mode
 * @return A string saying "read" or "write" depending on the mode.
 */
std::string getModeString(Mode mode);

}  // namespace fletchgen
