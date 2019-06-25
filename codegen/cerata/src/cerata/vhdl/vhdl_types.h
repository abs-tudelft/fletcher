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

#include <deque>
#include <memory>
#include <string>

#include "cerata/type.h"
#include "cerata/flattype.h"
#include "cerata/node.h"

namespace cerata::vhdl {

// VHDL specific type data

/// @brief Obtain the width of a primitive, synthesizable type. If it is not primitive, returns a Literal 0 node
std::shared_ptr<Node> GetWidth(const std::shared_ptr<Type> &type);

// VHDL implementation specific types

std::shared_ptr<Type> valid();
std::shared_ptr<Type> ready();

// VHDL port stuff

std::string ToString(Port::Dir dir);
Port::Dir Reverse(Port::Dir dir);

// VHDL type checking

bool IsCompatible(const std::shared_ptr<Node> &a, const std::shared_ptr<Node> &b);

/**
 * @brief Filter abstract types from a list of flattened types
 * @param list The list to filter
 * @return The filtered list
 */
std::deque<FlatType> FilterForVHDL(const std::deque<FlatType> &list);

struct Range {
  enum {
    NIL,
    SINGLE,
    MULTI,
  } type = NIL;

  std::string bottom;
  std::string top;

  std::string ToString() {
    if (type == SINGLE) {
      return "(" + bottom + ")";
    } else if (type == MULTI) {
      return "(" + top + " downto " + bottom + ")";
    } else {
      return "";
    }
  }
};

}  // namespace cerata::vhdl
