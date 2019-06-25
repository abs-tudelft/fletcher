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

#include <memory>

#include "cerata/graph.h"

namespace cerata::vhdl {

/// Functions to resolve VHDL-specific problems with graphs.
struct Resolve {
  /**
   * @brief Transforms the component, inserting signals between port-to-port connections of instances.
   *
   * In VHDL, port-to-port connections of instances are not supported. This can be solved by splitting port-to-port
   * edges, inserting a signal node.
   *
   * @param comp  The component to transform.
   * @return      The transformed component.
   */
  // TODO(johanpel): this should create a transformed copy, but currently mutates the component.
  static Component *ResolvePortToPort(Component *comp);

  /**
   * @brief Transforms the component, materialize the abstract Stream type by expanding it with a ready and valid bit.
   * @param comp  The component to transform.
   * @return      The transformed component.
   */
  // TODO(johanpel): this should create a transformed copy, but currently mutates the component.
  static Component *ExpandStreams(Component *comp);
};

}  // namespace cerata::vhdl
