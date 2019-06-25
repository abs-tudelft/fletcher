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

#include "cerata/node.h"
#include "cerata/type.h"
#include "cerata/graph.h"

#include "cerata/vhdl/block.h"

namespace cerata::vhdl {

struct Decl {
  static std::string Generate(const Type &type,  const std::optional<std::shared_ptr<Node>> &multiplier = std::nullopt);
  static Block Generate(const Parameter &par, int depth = 0);
  static Block Generate(const Port &port, int depth = 0);
  static Block Generate(const PortArray &port, int depth = 0);
  static Block Generate(const Signal &sig, int depth = 0);
  static MultiBlock Generate(const Component &comp, bool entity = false);
};

}  // namespace cerata::vhdl
