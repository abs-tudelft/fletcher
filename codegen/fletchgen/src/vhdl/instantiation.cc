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

std::deque<Range> GetRanges(const std::deque<FlatType> &types) {
  std::deque<Range> ret;
  std::shared_ptr<Node> offset = intl<0>();
  for (const auto &ft : types) {
    Range r;
    std::optional<std::shared_ptr<Node>> w;
    if (ft.type_->Is(Type::STREAM)) {
      // For the sake of this function, stream widths are 1
      w = intl<1>();
    } else {
      w = ft.type_->width();
    }

    if (w) {
      if (*w == intl<1>()) {
        r.type = Range::SINGLE;
      } else {
        r.type = Range::MULTI;
      }
      r.bottom = offset->ToString();
      offset = offset + *w;
      r.top = (offset - 1)->ToString();
    }

    ret.push_back(r);
  }
  return ret;
}

Block Inst::Generate(std::string lh_prefix,
                     const FlatType &lh,
                     Range lh_range,
                     std::string rh_prefix,
                     const FlatType &rh,
                     Range rh_range) {
  Block ret;

  Identifier lhn(lh.name_parts_);
  Identifier rhn(rh.name_parts_);
  lhn.prepend(lh_prefix);
  rhn.prepend(rh_prefix);

  // Nested types
  if (lh.type_->Is(Type::STREAM)) {
    // Streams generate additional valid and ready
    Line v;
    Line r;
    auto lhnv = lhn;
    auto lhnr = lhn;
    auto rhnv = rhn;
    auto rhnr = rhn;
    lhnv.append("valid");
    lhnr.append("ready");
    rhnv.append("valid");
    rhnr.append("ready");

    // Valid and ready port map
    v << lhnv.ToString() + lh_range.ToString() << "=> " << rhnv.ToString() + rh_range.ToString();
    r << lhnr.ToString() + lh_range.ToString() << "=> " << rhnr.ToString() + rh_range.ToString();

    // Comments
    v << " -- Stream valid: (" + lh.type_->name() + ":" + lh.type_->ToString() + " <-> " + rh.type_->name() + ":"
        + rh.type_->ToString() + ")";
    r << " -- Stream ready: (" + lh.type_->name() + ":" + lh.type_->ToString() + " <-> " + rh.type_->name() + ":"
        + rh.type_->ToString() + ")";

    ret << v << r;
  } else if (lh.type_->Is(Type::RECORD)) {
    // Records generate nothing
  } else {
    // Other types
    Line l;
    // Port map
    l << lhn.ToString() + lh_range.ToString() << "=> " << rhn.ToString() + rh_range.ToString();
    // Comment
    l << " -- (" + lh.type_->name() + ":" + lh.type_->ToString() + " <-> " + rh.type_->name() + ":"
        + rh.type_->ToString() + ")";
    ret << l;
  }
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
      //std::cout << tm->ToString() << std::endl;

      // Loop over all flat types for type A (the instance port)
      for (size_t ia = 0; ia < tm->flat_a().size(); ia++) {
        // Get all the flat type indices on type B (the connecting object)
        auto b_types = tm->GetOrderedBTypesFor(ia);

        for (size_t a_offset = 0; a_offset < b_types.size(); a_offset++) {
          Line l;
          l << tm->flat_a()[ia].name(port->name()) + "(" + std::to_string(a_offset) + ")";
          l << " => ";
          l << b_types[a_offset].name(other->name());
          ret << l;
        }
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
