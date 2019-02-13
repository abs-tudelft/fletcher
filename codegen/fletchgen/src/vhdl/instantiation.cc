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
#include "../nodes.h"
#include "../types.h"
#include "../graphs.h"

#include "./flatnode.h"
#include "./vhdl_types.h"

namespace fletchgen {
namespace vhdl {

Block Inst::Generate(const std::shared_ptr<Parameter> &par) {
  Block ret;
  Line l;
  l << par->name() << " => ";
  if (par->value()) {
    auto val = *par->value();
    l << val->ToString();
  } else if (par->default_value) {
    l << (*par->default_value)->ToString();
  }
  ret << l;
  return ret;
}

Block Inst::Generate(const std::shared_ptr<Port> &port) {
  Block ret;
  std::deque<std::shared_ptr<Edge>> connections;
  // Get the connections for this port
  if (port->IsInput()) {
    connections = port->inputs();
  } else {
    connections = port->outputs();
  }

  // Iterate over all connected edges
  for (const auto &edge : connections) {
    // Get the node on the other side of the connection
    auto other = edge->GetOtherNode(port);

    // Get type mapper
    std::shared_ptr<TypeMapper> tm;

    // Check if a type mapping exists
    auto tmo = port->type()->GetMapper(other->type().get());
    if (tmo) {
      tm = *tmo;

      // Filter the flattened type for VHDL
      auto vhdl_flat_ports = tm->flat_a();

      for (size_t i = 0; i < vhdl_flat_ports.size(); i++) {
        Line l;
        l << vhdl_flat_ports[i].name(port->name()) + "(" + vhdl_flat_ports[i].type_->ToString() + ")";
        l << "=> ";
        auto vhdl_flat_others = tm->GetBTypesFor(i);
        for (size_t j = 0; j < vhdl_flat_others.size(); j++) {
          l << vhdl_flat_others[j].name(other->name()) + "(" + vhdl_flat_others[j].type_->ToString() + ")";
        }
        ret << l;
      }
    } else {
      throw std::runtime_error(
          "No type mapping available for: Port[" + port->name() + ": " + port->type()->name()
              + "] to Other[" + other->name() + " : " + other->type()->name() + "]");
    }

  }
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

  auto num_ports = inst->CountNodes(Node::PORT) + inst->CountNodes(Node::ARRAY_PORT);
  if (num_ports > 0) {
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
    //for (const auto &p : inst->GetNodesOfType<ArrayPort>()) {
    //Block pm;
    //pm << Generate(p);
    //pmb << pm;
    //}
    pf << ")";
    pmf << pf;
    ret << pmh << pmb << pmf;
  }

  return ret;
}

}  // namespace vhdl
}  // namespace fletchgen
