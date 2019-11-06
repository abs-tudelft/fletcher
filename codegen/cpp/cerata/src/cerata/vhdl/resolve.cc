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

#include "cerata/vhdl/resolve.h"

#include <memory>
#include <vector>
#include <string>
#include <unordered_map>

#include "cerata/logging.h"
#include "cerata/type.h"
#include "cerata/graph.h"
#include "cerata/edge.h"
#include "cerata/vhdl/vhdl_types.h"

namespace cerata::vhdl {

static int ResolvePorts(Component *comp, Instance *inst, NodeMap *rebinding) {
  int i = 0;
  auto ports = inst->GetAll<Port>();
  for (const auto &port : ports) {
    AttachSignalToNode(comp, port, rebinding);
    i++;
  }
  return i;
}

/**
 * @brief Resolve VHDL-specific limitations in a Cerata graph related to ports.
 * @param comp      The component to resolve the limitations for.
 * @param inst      The instance to resolve it for.
 * @param resolved  A vector to append resolved objects to.
 * @param rebinding A map with type generic node rebindings.
 */
static int ResolvePortArrays(Component *comp, Instance *inst, NodeMap *rebinding) {
  // There is something utterly annoying in VHDL; range expressions must be "locally static" in port map
  // associativity lists on the left hand side. This means we can't use any type generic nodes.
  // Thanks, VHDL.
  int i = 0;
  // To solve this, we're just going to insert a signal array for every port array.
  for (const auto &pa : inst->GetAll<PortArray>()) {
    AttachSignalArrayToNodeArray(comp, pa, rebinding);
    i++;
  }
  return i;
}

Component *Resolve::SignalizePorts(Component *comp) {
  // We are potentially going to make a bunch of copies of type generic nodes and array sizes.
  // Remember which ones we did already and where we left their copy through a map.
  auto children = comp->children();
  for (const auto &inst : children) {
    ResolvePorts(comp, inst, comp->inst_to_comp_map());
    ResolvePortArrays(comp, inst, comp->inst_to_comp_map());
  }
  return comp;
}

}  // namespace cerata::vhdl
