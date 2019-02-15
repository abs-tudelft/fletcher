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

Block Inst::GenerateGenericMap(const std::shared_ptr<Parameter> &par) {
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

Block Inst::GenerateMappingPair(const MappingPair &p,
                                size_t ia,
                                std::shared_ptr<Node> *offset_a,
                                size_t ib,
                                std::shared_ptr<Node> *offset_b,
                                const std::string &lh_prefix,
                                const std::string &rh_prefix) {
  Block ret;

  std::shared_ptr<Node> next_offset_a;
  std::shared_ptr<Node> next_offset_b;

  if (p.flat_type_b(ib).type_->width()) {
    next_offset_a = (*offset_a) + *p.flat_type_b(ib).type_->width();
  } else {
    next_offset_a = (*offset_a);
  }
  if (p.flat_type_a(ia).type_->width()) {
    next_offset_b = (*offset_b) + *p.flat_type_a(ia).type_->width();
  } else {
    next_offset_b = (*offset_b);
  }

  if (p.flat_type_a(0).type_->Is(Type::STREAM)) {
    Line v;
    Line r;

    v << p.flat_type_a(ia).name(lh_prefix) + "_valid";
    r << p.flat_type_a(ia).name(lh_prefix) + "_ready";

    if (p.num_b() > 1) {
      v += "(" + (*offset_a)->ToString() + ")";
      r += "(" + (*offset_a)->ToString() + ")";
      next_offset_a = (*offset_a) + 1;
    }

    v << " => ";
    r << " => ";

    v << p.flat_type_b(ib).name(rh_prefix) + "_valid";
    r << p.flat_type_b(ib).name(rh_prefix) + "_ready";

    if (p.num_a() > 1) {
      v += "(" + (*offset_b)->ToString() + ")";
      r += "(" + (*offset_b)->ToString() + ")";
      next_offset_b = (*offset_b) + 1;
    }

    ret << v << r;
  } else if (p.flat_type_a(0).type_->Is(Type::RECORD)) {
    // don't output anything
  }  else {
    Line l;
    l << p.flat_type_a(ia).name(lh_prefix);
    if (p.num_b() > 1) {
      if (p.flat_type_a(ia).type_->Is(Type::BIT)) {
        l += "(" + (*offset_a)->ToString() + ")";
      } else {
        l += "(" + (next_offset_a - 1)->ToString() + " downto " + (*offset_a)->ToString() + ")";
      }
    }

    l << " => ";
    l << p.flat_type_b(ib).name(rh_prefix);
    if (p.num_a() > 1) {
      if (p.flat_type_a(ia).type_->Is(Type::BIT)) {
        l += "(" + (*offset_b)->ToString() + ")";
      } else {
        l += "(" + (next_offset_b - 1)->ToString() + " downto " + (*offset_b)->ToString() + ")";
      }
    }
    ret << l;
  }

  *offset_a = next_offset_a;
  *offset_b = next_offset_b;

  return ret;
}

Block Inst::GeneratePortNodeMapping(std::deque<MappingPair> pairs,
                                    const std::shared_ptr<Port> &port,
                                    const std::shared_ptr<Node> &other) {
  Block ret;
  // Sort the pair in order of appearance on the flatmap
  std::sort(pairs.begin(), pairs.end(), [](const MappingPair &x, const MappingPair &y) -> bool {
    return x.index_a(0) < y.index_a(0);
  });

  // Loop over all pairs
  for (const auto &p: pairs) {
    std::shared_ptr<Node> offset_b = intl<0>();
    for (size_t ia = 0; ia < p.num_a(); ia++) {
      std::shared_ptr<Node> offset_a = intl<0>();
      for (size_t ib = 0; ib < p.num_b(); ib++) {
        ret << GenerateMappingPair(p, ia, &offset_a, ib, &offset_b, port->name(), other->name());
      }
    }
  }
  return ret;
}

Block Inst::GeneratePortMap(const std::shared_ptr<Port> &port) {
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

      auto pairs = tm->GetUniqueMappingPairs();
      ret << GeneratePortNodeMapping(pairs, port, other);
    }

      /*
      Line l;
      l << tm->flat_a()[ia].name(port->name()) + "(" + std::to_string(a_off_idx) + ")";
      l << " => ";
      l << b_types[a_off_idx].name(other->name());
      ret << l;
       */

    else {
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
      gm << GenerateGenericMap(g);
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
      pm << GeneratePortMap(p);
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
