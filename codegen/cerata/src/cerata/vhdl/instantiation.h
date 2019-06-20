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

#include <algorithm>
#include <string>
#include <memory>
#include <deque>

#include "cerata/node.h"
#include "cerata/type.h"
#include "cerata/graph.h"

#include "cerata/vhdl/block.h"
#include "cerata/vhdl/vhdl_types.h"

namespace cerata::vhdl {

struct Inst {
  static Block GenerateMappingPair(const MappingPair &p,
                                   size_t ia,
                                   const std::shared_ptr<Node> &offset_a,
                                   size_t ib,
                                   const std::shared_ptr<Node> &offset_b,
                                   const std::string &lh_prefix,
                                   const std::string &rh_prefix,
                                   bool a_is_array,
                                   bool b_is_array);

  static Block GeneratePortMappingPair(std::deque<MappingPair> pairs, const Node &a, const Node &b);
  static MultiBlock Generate(const Graph &graph);
  static Block GeneratePortMaps(const Port &port);
  static Block GeneratePortArrayMaps(const PortArray &array);
  static Block GenerateGenericMap(const Parameter &par);
};

}  // namespace cerata::vhdl
