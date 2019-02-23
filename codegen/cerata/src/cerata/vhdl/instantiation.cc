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

#include "cerata/vhdl/instantiation.h"

#include "cerata/edges.h"
#include "cerata/nodes.h"
#include "cerata/arrays.h"
#include "cerata/types.h"
#include "cerata/graphs.h"

#include "cerata/vhdl/flatnode.h"
#include "cerata/vhdl/vhdl_types.h"

namespace cerata {
namespace vhdl {

static bool IsInput(const std::shared_ptr<Node> port) {
  auto t = Cast<Term>(port);
  if (t) {
    return (*t)->IsInput();
  } else {
    throw std::runtime_error("Node is not a terminator.");
  }
}

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
                                const std::shared_ptr<Node> &offset_a,
                                size_t ib,
                                const std::shared_ptr<Node> &offset_b,
                                const std::string &lh_prefix,
                                const std::string &rh_prefix,
                                bool a_is_array,
                                bool b_is_array) {
  Block ret;

  std::shared_ptr<Node> next_offset_a;
  std::shared_ptr<Node> next_offset_b;

  auto a_width = p.flat_type_a(ia).type_->width();
  auto b_width = p.flat_type_b(ib).type_->width();

  next_offset_a = offset_a + (b_width ? *b_width : 0);
  next_offset_b = offset_b + (a_width ? *a_width : 0);

  if (p.flat_type_a(0).type_->Is(Type::STREAM)) {
    // Output valid and ready signals for this abstract type.
    Line v;
    Line r;
    v << p.flat_type_a(ia).name(lh_prefix) + "_valid";
    r << p.flat_type_a(ia).name(lh_prefix) + "_ready";
    if ((p.num_b() > 1) || a_is_array) {
      v += "(" + offset_a->ToString() + ")";
      r += "(" + offset_a->ToString() + ")";
    }
    v << " => ";
    r << " => ";
    v << p.flat_type_b(ib).name(rh_prefix) + "_valid";
    r << p.flat_type_b(ib).name(rh_prefix) + "_ready";
    if ((p.num_a() > 1) || b_is_array) {
      v += "(" + offset_b->ToString() + ")";
      r += "(" + offset_b->ToString() + ")";
    }
    ret << v << r;
  } else if (p.flat_type_a(0).type_->Is(Type::RECORD)) {
    // Don't output anything for the abstract record type.
  } else {
    Line l;
    l << p.flat_type_a(ia).name(lh_prefix);
    if ((p.num_b() > 1) || a_is_array) {
      if (p.flat_type_a(ia).type_->Is(Type::BIT)) {
        l += "(" + offset_a->ToString() + ")";
      } else {
        l += "(" + (next_offset_a - 1)->ToString() + " downto " + offset_a->ToString() + ")";
      }
    }
    l << " => ";
    l << p.flat_type_b(ib).name(rh_prefix);
    if ((p.num_a() > 1) || b_is_array) {
      if (p.flat_type_a(ia).type_->Is(Type::BIT)) {
        l += "(" + offset_b->ToString() + ")";
      } else {
        l += "(" + (next_offset_b - 1)->ToString() + " downto " + offset_b->ToString() + ")";
      }
    }
    ret << l;
  }

  return ret;
}

Block Inst::GeneratePortMappingPair(std::deque<MappingPair> pairs,
                                    const std::shared_ptr<Node> &port,
                                    const std::shared_ptr<Node> &other,
                                    size_t array_index) {
  Block ret;
  // Sort the pair in order of appearance on the flatmap
  std::sort(pairs.begin(), pairs.end(), [](const MappingPair &x, const MappingPair &y) -> bool {
    return x.index_a(0) < y.index_a(0);
  });
  // Loop over all pairs
  for (const auto &p: pairs) {
    // Offset on the right side
    std::shared_ptr<Node> offset_b = p.width_a(intl<1>()) * Literal::Make(static_cast<int>(array_index));
    // Loop over everything on the left side
    for (size_t ia = 0; ia < p.num_a(); ia++) {
      // Get the width of the left side.
      auto a_width = p.flat_type_a(ia).type_->width();
      // Offset on the left side.
      std::shared_ptr<Node> offset_a = p.width_b(intl<1>()) * Literal::Make(static_cast<int>(array_index));
      for (size_t ib = 0; ib < p.num_b(); ib++) {
        // Get the width of the right side.
        auto b_width = p.flat_type_b(ib).type_->width();
        // Generate the mapping pair with given offsets
        auto mpblock = GenerateMappingPair(p,
                                           ia,
                                           offset_a,
                                           ib,
                                           offset_b,
                                           port->name(),
                                           other->name(),
                                           false,
                                           false);
        ret << mpblock;
        // Increase the offset on the left side.
        offset_a = offset_a + (b_width ? *b_width : intl<0>());
      }
      // Increase the offset on the right side.
      offset_b = offset_b + (a_width ? *a_width : intl<0>());
    }
  }
  return ret;
}

Block Inst::GeneratePortMaps(const std::shared_ptr<Node> &port) {
  Block ret;
  std::deque<std::shared_ptr<Edge>> connections;
  // Check if this is an input or output port
  if (IsInput(port)) {
    connections = port->sources();
  } else {
    connections = port->sinks();
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
      // Obtain the unique mapping pairs for this mapping
      auto pairs = tm->GetUniqueMappingPairs();
      // Generate the mapping for this port-node pair.
      ret << GeneratePortMappingPair(pairs, port, other, 0);
    } else {
      throw std::runtime_error(
          "No type mapping available for: Port[" + port->name() + ": " + port->type()->name()
              + "] to Other[" + other->name() + " : " + other->type()->name() + "]");
    }
  }
  return ret;
}

MultiBlock Inst::Generate(const Graph *graph) {
  MultiBlock ret(1);

  auto pinst = Cast<Instance>(graph);
  if (!pinst) {
    throw std::runtime_error("Graph is not an instance.");
  }
  auto inst = *pinst;

  Block ih(ret.indent);       // Instantiation header
  Block gmh(ret.indent + 1);  // generic map header
  Block gmb(ret.indent + 2);  // generic map body
  Block gmf(ret.indent + 1);  // generic map footer
  Block pmh(ret.indent + 1);  // port map header
  Block pmb(ret.indent + 2);  // port map body
  Block pmf(ret.indent + 1);  // port map footer

  ih << inst->name() + " : " + inst->component->name();

  // Generic map
  if (inst->CountNodes(Node::PARAMETER) > 0) {
    Line gh, gf;
    gh << "generic map (";
    gmh << gh;
    for (const auto &g : inst->GetAll<Parameter>()) {
      gmb << GenerateGenericMap(g);
    }
    gmb <<= ",";
    gf << ")";
    gmf << gf;
  }

  auto num_ports = inst->CountNodes(Node::PORT);// + inst->CountNodes(Node::ARRAY_PORT);
  if (num_ports > 0) {
    // Port map
    Line ph, pf;
    ph << "port map (";
    pmh << ph;
    for (const auto &n : inst->GetAll<Port>()) {
      Block pm;
      pm << GeneratePortMaps(n);
      pmb << pm;
    }
    pmb <<= ",";
    pf << ");";
    pmf << pf;
  }

  ret << ih;
  ret << gmh << gmb << gmf;
  ret << pmh << pmb << pmf;

  return ret;
}

}  // namespace vhdl
}  // namespace cerata
