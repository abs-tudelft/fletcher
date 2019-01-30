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
  std::deque<std::shared_ptr<Node>> resolved;
  for (const auto &inst : comp->GetAllInstances()) {
    for (const auto &port : inst->GetAllNodesOfType<Port>()) {
      for (const auto &edge : port->edges()) {
        // Both sides of the edge must be a port
        if (edge->src->IsPort() && edge->dst->IsPort()) {
          // Either of the ports cannot be on the component itself. Component port to instance port edges are allowed.
          if ((edge->src->parent() != comp.get()) && (edge->dst->parent() != comp.get())) {
            // Only resolve if not already resolved
            if (!contains(resolved, edge->src) && !contains(resolved, edge->dst)) {
              // Insert a signal in between
              std::string prefix;
              if (edge->dst->parent()) {
                prefix = (*edge->dst->parent())->name() + "_";
              } else if (edge->src->parent()) {
                prefix = (*edge->src->parent())->name() + "_";
              }
              auto sig = insert(edge, prefix);
              // Add the signal to the component
              comp->AddNode(sig);
              // Remember we've touched these nodes already
              resolved.push_back(edge->src);
              resolved.push_back(edge->dst);
            }
          }
        }
      }
    }
  }
  return comp;
}

}  // namespace vhdl
}  // namespace fletchgen
