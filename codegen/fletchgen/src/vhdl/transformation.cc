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

#include "./transformation.h"

#include <memory>

#include "../types.h"
#include "../graphs.h"
#include "../edges.h"

namespace fletchgen {
namespace vhdl {

std::shared_ptr<Component> Transformation::ResolvePortToPort(std::shared_ptr<Component> comp) {
  for (const auto &inst : comp->GetAllInstances()) {
    for (const auto &port : inst->GetAllNodesOfType<Port>()) {
      for (const auto &edge : port->edges()) {
        if (edge->src->IsPort() && edge->dst->IsPort()) {
          auto sig = insert(edge, "int_");
          comp->AddNode(sig);
        }
      }
    }
  }
  return comp;
}

}  // namespace vhdl
}  // namespace fletchgen
