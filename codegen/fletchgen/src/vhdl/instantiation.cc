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

#include "./instantiation.h"

#include "../edges.h"

#include "./flatnode.h"
#include "./vhdl_types.h"

namespace fletchgen {
namespace vhdl {

Block Inst::Generate(const std::shared_ptr<Port> &lhs) {
  Block ret;

  return ret;
}

MultiBlock Inst::Generate(const std::shared_ptr<Graph> &graph) {
  MultiBlock ret;

  if (!Cast<Instance>(graph)) {
    throw std::runtime_error("Graph is not an instance.");
  }

  auto inst = *Cast<Instance>(graph);

  // Instantiation header
  Block lh;
  lh << inst->name() + " : " + inst->component->name();
  ret << lh;

  // Generic map
  if (inst->CountNodes(Node::PARAMETER) > 0) {
    Block gmh(ret.indent + 1);
    Block gm(ret.indent + 2);
    Block gmf(ret.indent + 1);
    Line gh, gf;
    gh << "generic map (";
    gmh << gh;
    for (const auto &g : inst->GetNodesOfType<Parameter>()) {
      gm << Generate(g);
    }
    gf << ")";
    gmf << gf;
    ret << gmh << gm << gmf;
  }

  if (inst->CountNodes(Node::PORT) > 0) {
    // Port map
    Block pmh(ret.indent + 1);
    Block pmb(ret.indent + 2);
    Block pmf(ret.indent + 1);
    Line ph, pf;
    ph << "port map (";
    pmh << ph;
    for (const auto &p : inst->GetNodesOfType<Port>()) {
      Block pm;
      pm << Generate(p);
      pmb << pm;
    }
    pf << ")";
    pmf << pf;
    ret << pmh << pmb << pmf;
  }

  return ret;
}

Block Inst::Generate(const std::shared_ptr<Parameter> &port) {
  return Block();
}

}  // namespace vhdl
}  // namespace fletchgen
