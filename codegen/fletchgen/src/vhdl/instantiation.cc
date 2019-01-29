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
  // Iterate over every edge of this port.
  for (const auto &e : lhs->edges()) {
    // Get the other end
    auto rhs = e->GetOtherNode(lhs);

    // Check if other end is compatible
    if (IsCompatible(lhs, rhs)) {

      // Flatten nodes of both sides into the required VHDL objects: ports on the lhs and ports xor signals on the rhs
      auto fl = FlatNode(lhs);
      auto fr = FlatNode(rhs);

      // Iterate over the flattened vhdl objects
      for (size_t i = 0; i < fl.size(); i++) {
        Line line;
        // LHS name
        line << std::get<0>(fl.GetTuple(i)).ToString();

        // Check if LHS indexing is applicable
        if (e->num_siblings(lhs) > 1) {
          line += "(" + std::to_string(Edge::GetIndexOf(e, lhs)) + ")";
        }

        line << " => ";

        // RHS name
        line << std::get<0>(fr.GetTuple(i)).ToString();

        // Check if RHS indexing is applicable
        if (e->num_siblings(rhs) > 1) {
          line += "(" + std::to_string(Edge::GetIndexOf(e, rhs)) + ")";
        }

        ret << line;
      }
    }
  }
  return ret;
}

MultiBlock Inst::Generate(const std::shared_ptr<Graph> &graph) {
  MultiBlock ret;

  // Instantiation header
  Block lh;
  lh << graph->name() + " : " + graph->name();
  ret << lh;

  // Generic map
  if (graph->CountNodes(Node::PARAMETER) > 0) {
    Block gmh(ret.indent + 1);
    Block gm(ret.indent + 2);
    Block gmf(ret.indent + 1);
    Line gh, gf;
    gh << "generic map (";
    gmh << gh;
    for (const auto &g : graph->GetAllNodesOfType<Parameter>()) {
      gm << Generate(g);
    }
    gf << ")";
    gmf << gf;
    ret << gmh << gm << gmf;
  }

  if (graph->CountNodes(Node::PORT) > 0) {
    // Port map
    Block pmh(ret.indent + 1);
    Block pmb(ret.indent + 2);
    Block pmf(ret.indent + 1);
    Line ph, pf;
    ph << "port map (";
    pmh << ph;
    for (const auto &p : graph->GetAllNodesOfType<Port>()) {
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
