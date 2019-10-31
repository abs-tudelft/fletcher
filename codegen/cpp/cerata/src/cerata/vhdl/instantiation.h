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

#include <algorithm>
#include <string>
#include <memory>
#include <vector>

#include "cerata/node.h"
#include "cerata/type.h"
#include "cerata/graph.h"

#include "cerata/vhdl/block.h"
#include "cerata/vhdl/vhdl_types.h"

namespace cerata::vhdl {

/// Functions to generate VHDL instantiation code.
struct Inst {
  /// @brief Generate a VHDL instantiation of a graph.
  static MultiBlock Generate(const Graph &graph);
  /// @brief Generate an associativity list for an instantiated Port.
  static Block GeneratePortMaps(const Port &port, bool full_array = false);
  /// @brief Generate an associativity list for an instantiated PortArray.
  static Block GeneratePortArrayMaps(const PortArray &array);
  /// @brief Generate an associativity list for an instantiated Parameter.
  static Block GenerateGenericMap(const Parameter &par);
};

}  // namespace cerata::vhdl
