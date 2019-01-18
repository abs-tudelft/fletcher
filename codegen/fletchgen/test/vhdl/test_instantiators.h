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

#include "../../src/fletcher_types.h"

namespace fletchgen {

TEST(VHDL, StreamConcat) {
  auto top = GetConcattedStreamsComponent();

  auto x_inst = vhdl::Instantiator::Generate(top->children[0]);
  auto y_inst = vhdl::Instantiator::Generate(top->children[1]);

  std::cout << x_inst.str();
  std::cout << y_inst.str();
}

}