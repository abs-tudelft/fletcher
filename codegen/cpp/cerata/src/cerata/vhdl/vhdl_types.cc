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

#include "cerata/vhdl/vhdl_types.h"

#include <memory>
#include <deque>

#include "cerata/vhdl/vhdl.h"
#include "cerata/type.h"

namespace cerata::vhdl {

std::shared_ptr<Type> valid() {
  static std::shared_ptr<Type> result = std::make_shared<Bit>("valid");
  result->meta[metakeys::EXPAND_TYPE] = "valid";
  return result;
}

std::shared_ptr<Type> ready() {
  static std::shared_ptr<Type> result = std::make_shared<Bit>("ready");
  result->meta[metakeys::EXPAND_TYPE] = "ready";
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

std::deque<FlatType> FilterForVHDL(const std::deque<FlatType> &list) {
  std::deque<FlatType> result;
  for (const auto &ft : list) {
    // If the type is abstract, we can't represent it, so it is filtered out
    if (ft.type_->IsAbstract() && !ft.type_->Is(Type::BOOLEAN)) {

    } else {
      // Otherwise VHDL can express the type already
      result.push_back(ft);
    }
  }
  return result;
}

std::string Range::ToString() {
  if (type == SINGLE) {
    return "(" + bottom + ")";
  } else if (type == MULTI) {
    return "(" + top + " downto " + bottom + ")";
  } else {
    return "";
  }
}
}  // namespace cerata::vhdl
