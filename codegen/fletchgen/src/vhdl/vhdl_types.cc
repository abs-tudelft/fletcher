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

#include "./vhdl_types.h"

#include <memory>

#include "../types.h"

#include "./flatnode.h"

namespace fletchgen {
namespace vhdl {

std::shared_ptr<Type> valid() {
  static std::shared_ptr<Type> result = std::make_shared<Bit>("valid");
  return result;
}

std::shared_ptr<Type> ready() {
  static std::shared_ptr<Type> result = std::make_shared<Bit>("ready");
  return result;
}

std::string ToString(Port::Dir dir) {
  if (dir == Port::Dir::IN) {
    return "in";
  } else {
    return "out";
  }
}

Port::Dir Reverse(Port::Dir dir) {
  if (dir == Port::Dir::IN) {
    return Port::Dir::OUT;
  } else {
    return Port::Dir::IN;
  }
}

bool IsCompatible(const std::shared_ptr<Node> &a, const std::shared_ptr<Node> &b) {
  auto fa = FlatNode(a);
  auto fb = FlatNode(b);

  // Not compatible if the top level type flattens to something with another number of tuples
  if (fa.size() != fb.size()) {
    return false;
  }

  // Not compatible if the type ids of flat view is different
  // TODO(johanpel): is this really necessary?
  for (size_t i = 0; i < fa.size(); i++) {
    if (std::get<1>(fa.pair(i))->id() != std::get<1>(fb.pair(i))->id()) {
      return false;
    }
  }

  // Otherwise, it is compatible
  return true;
}

}  // namespace vhdl
}  // namespace fletchgen
