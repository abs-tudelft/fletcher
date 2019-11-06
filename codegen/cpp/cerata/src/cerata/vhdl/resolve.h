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

#include <memory>

#include "cerata/graph.h"

namespace cerata::vhdl {

/// Functions to resolve VHDL-specific problems with graphs.
struct Resolve {
  /**
   * @brief Transforms the component, inserting signals for every instance port.
   *
   * Many things are terrible in VHDL when it comes to instance ports.
   * - We cannot have port-to-port connections of instances.
   * - We cannot use VHDL generics on the left hand side of port map associativity lists.
   * - We cannot read from output ports.
   * - ...
   *
   * To solve this elegantly and in a "readable" way (similar to how handcrafted designs would do it)turns out to be
   * slightly non-trivial, as there are an incredible bunch of combinations to consider.
   *
   * We choose to solve this by just inserting signals for every port onto the component and reroute all connections
   * through the signals. This generates a massive amount of signals, but hey, at least I haven't thrown myself out of
   * a window yet.
   *
   * @param comp  The component to transform.
   * @return      The transformed component.
   */
  // TODO(johanpel): this should create a transformed copy, but currently mutates the component.
  static Component *SignalizePorts(Component *comp);
};

}  // namespace cerata::vhdl
