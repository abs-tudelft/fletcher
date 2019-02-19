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

#include <gtest/gtest.h>

#include "../../src/vhdl/vhdl.h"

#include "../../src/dot/dot.h"

#include "../../src/nodes.h"
#include "../../src/types.h"
#include "../../src/hardware/basic_types.h"

#include "../test_designs.h"

namespace fletchgen {
namespace hardware {

TEST(VHDL, ComponentDecl) {
  auto code = vhdl::Decl::Generate(GetAllPortTypesComponent());
  std::cout << code.ToString() << std::endl;
}

TEST(VHDL, ArrayPort) {
  auto top = GetArrayComponent();

  auto code = vhdl::Design::Generate(top);
  std::cout << code.ToString() << std::endl;

  dot::Grapher dot(dot::Style::normal());
  std::cout << dot.GenFile(top, "graph.dot");
}

}
}
