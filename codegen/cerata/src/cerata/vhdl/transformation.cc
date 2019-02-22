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

#include "cerata/vhdl/transformation.h"

#include <memory>
#include <deque>
#include <string>

#include "cerata/types.h"
#include "cerata/graphs.h"
#include "cerata/edges.h"

namespace cerata {
namespace vhdl {

std::shared_ptr<Component> Transformation::ResolvePortToPort(std::shared_ptr<Component> comp) {
  std::deque<Node *> resolved;
  for (const auto &inst : comp->GetAllInstances()) {
    for (const auto &port : inst->GetNodesOfType<Port>()) {
      for (const auto &edge : port->sinks()) {
        // If the edge is not complete, continue.
        if (!edge->IsComplete()) {
          continue;
        }
        // If either side is not a port, continue.
        if (!(*edge->src)->IsPort() || !(*edge->dst)->IsPort()) {
          continue;
        }
        // If either sides of the edges are a port node on this component, continue.
        if (((*edge->src)->parent() == comp.get()) || ((*edge->dst)->parent() == comp.get())) {
          continue;
        }
        // If the destination is already resolved, continue.
        if (contains(resolved, (*edge->dst).get())) {
          continue;
        }
        // Dealing with two port nodes that are not on the component itself. VHDL cannot handle port-to-port connections
        // of instances. Insert a signal in between and add it to the component.
        std::string prefix;
        if ((*edge->dst)->parent()) {
          prefix = (*(*edge->dst)->parent())->name() + "_";
        } else if ((*edge->src)->parent()) {
          prefix = (*(*edge->src)->parent())->name() + "_";
        }
        auto sig = insert(edge, prefix);
        // Add the signal to the component
        comp->AddObject(sig);
        // Remember we've touched these nodes already
        resolved.push_back((*edge->src).get());
        resolved.push_back((*edge->dst).get());
      }
    }
  }
  return comp;
}

}  // namespace vhdl
}  // namespace cerata
