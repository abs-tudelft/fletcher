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

#include "cerata/graphs.h"

namespace cerata::vhdl {

struct Resolve {
  /**
   * @brief Transforms the component, inserting signals between port-to-port connections of instances.
   *
   * In VHDL, port-to-port connections of instances are not supported.
   *
   * @param comp  The component to transform.
   * @return      The transformed component.
   */
  static std::shared_ptr<Component> ResolvePortToPort(std::shared_ptr<Component> comp);

  /**
   * @brief Transforms the component, materialize the abstract Stream type by expanding it with a ready and valid bit.
   * @param comp  The component to transform.
   * @return      The transformed component.
   */
  static std::shared_ptr<Component> ExpandStreams(std::shared_ptr<Component> comp);
};

}  // namespace cerata::vhdl
