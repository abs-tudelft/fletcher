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
#include "cerata/port.h"

namespace cerata::vhdl {

// VHDL specific type data

/// @brief Obtain the width of a primitive, synthesizable type. If it is not primitive, returns a Literal 0 node
std::shared_ptr<Node> GetWidth(const std::shared_ptr<Type> &type);

// VHDL implementation specific types

/// @brief A stream ready-valid handshake "valid" signal.
std::shared_ptr<Type> valid();
/// @brief A stream ready-valid handshake "ready" signal.
std::shared_ptr<Type> ready();

// VHDL port stuff
/// @brief Return a VHDL version of a terminator direction.
std::string ToString(Term::Dir dir);
/// @brief Reverse a terminator direction.
Term::Dir Reverse(Term::Dir dir);

/**
 * @brief Filter abstract types from a list of flattened types
 * @param list  The list to filter
 * @return      The filtered list
 */
std::deque<FlatType> FilterForVHDL(const std::deque<FlatType> &list);

/// A VHDL range.
struct Range {
  /// Range types.
  enum {
    NIL,      ///< For null ranges.
    SINGLE,   ///< For range of size 1.
    MULTI,    ///< For a range of size > 1.
  } type = NIL;

  /// Bottom of the range.
  std::string bottom;
  /// Top of the range.
  std::string top;

  /// @brief Return a human-readable version of the range.
  std::string ToString();
};

}  // namespace cerata::vhdl
