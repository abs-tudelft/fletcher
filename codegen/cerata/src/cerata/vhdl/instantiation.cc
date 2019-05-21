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

#include "cerata/logging.h"
#include "cerata/edges.h"
#include "cerata/nodes.h"
#include "cerata/arrays.h"
#include "cerata/types.h"
#include "cerata/graphs.h"
#include "cerata/vhdl/identifier.h"
#include "cerata/vhdl/vhdl_types.h"

namespace cerata::vhdl {

static std::string lit2vhdl(std::shared_ptr<Literal> lit) {
  switch (lit->type()->id()) {
    default:return lit->ToString();
    case Type::STRING:
      // If it is a string enclose it within quotes
      return "\"" + lit->ToString() + "\"";
    case Type::BOOLEAN:
      // Convert to VHDL boolean
      if (lit->bool_val_) return "true";
      else return "false";
  }
}

static bool IsInputTerminator(const std::shared_ptr<Object> &obj) {
  auto t = Cast<Term>(obj);
  if (t) {
    return (*t)->IsInput();
  } else {
    throw std::runtime_error("Object is not a terminator.");
  }
}

Block Inst::GenerateGenericMap(const std::shared_ptr<Parameter> &par) {
  Block ret;
  Line l;
  l << to_upper(par->name()) << " => ";
  std::shared_ptr<Node> val;
  // Check what value to apply, either an assigned value or a default value
  if (par->value()) {
    val = *par->value();
  } else if (par->default_value) {
    val = (*par->default_value);
  }
  // Check if some value existed at all
  if (val != nullptr) {
    // If it is a literal, make it VHDL compatible
    if (val->IsLiteral()) {
      l << lit2vhdl(*Cast<Literal>(val));
    } else {
      l << val->ToString();
    }
  }
  ret << l;
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

  next_offset_a = offset_a + (b_width ? *b_width : intl<0>());
  next_offset_b = offset_b + (a_width ? *a_width : intl<0>());

  if (p.flat_type_a(0).type_->Is(Type::STREAM)) {
    // Don't output anything for the abstract stream type.
  } else if (p.flat_type_a(0).type_->Is(Type::RECORD)) {
    // Don't output anything for the abstract record type.
  } else {
    Line l;
    l << p.flat_type_a(ia).name(NamePart(lh_prefix, true));

    // if right side is concatenated onto the left side
    // or the left side is an array (right is also concatenated onto the left side)
    if ((p.num_b() > 1) || a_is_array) {
      if (p.flat_type_a(ia).type_->Is(Type::BIT)) {
        l += "(" + offset_a->ToString() + ")";
      } else {
        l += "(" + (next_offset_a - 1)->ToString() + " downto " + offset_a->ToString() + ")";
      }
    }
    l << " => ";
    l << p.flat_type_b(ib).name(NamePart(rh_prefix, true));
    if ((p.num_a() > 1) || b_is_array) {
      if (p.flat_type_b(ib).type_->Is(Type::BIT)) {
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
                                    const std::shared_ptr<Node> &a,
                                    const std::shared_ptr<Node> &b) {
  Block ret;
  // Sort the pair in order of appearance on the flatmap
  std::sort(pairs.begin(), pairs.end(), [](const MappingPair &x, const MappingPair &y) -> bool {
    return x.index_a(0) < y.index_a(0);
  });
  bool a_array = false;
  bool b_array = false;
  size_t a_idx = 0;
  size_t b_idx = 0;
  // Figure out if these nodes are on NodeArrays and what their index is
  if (a->array()) {
    a_array = true;
    a_idx = (*a->array())->IndexOf(a);
  }
  if (b->array()) {
    b_array = true;
    b_idx = (*b->array())->IndexOf(b);
  }
  if (a->type()->meta.count("VHDL:ForceStreamVector") > 0) {
    a_array = true;
  }
  if (b->type()->meta.count("VHDL:ForceStreamVector") > 0) {
    b_array = true;
  }
  // Loop over all pairs
  for (const auto &pair: pairs) {
    // Offset on the right side
    std::shared_ptr<Node> b_offset = pair.width_a(intl<1>()) * Literal::Make(static_cast<int>(b_idx));
    // Loop over everything on the left side
    for (size_t ia = 0; ia < pair.num_a(); ia++) {
      // Get the width of the left side.
      auto a_width = pair.flat_type_a(ia).type_->width();
      // Offset on the left side.
      std::shared_ptr<Node> a_offset = pair.width_b(intl<1>()) * Literal::Make(static_cast<int>(a_idx));
      for (size_t ib = 0; ib < pair.num_b(); ib++) {
        // Get the width of the right side.
        auto b_width = pair.flat_type_b(ib).type_->width();
        // Generate the mapping pair with given offsets
        auto mpblock = GenerateMappingPair(pair, ia, a_offset, ib, b_offset, a->name(), b->name(), a_array, b_array);
        ret << mpblock;
        // Increase the offset on the left side.
        a_offset = a_offset + (b_width ? *b_width : intl<1>());
      }
      // Increase the offset on the right side.
      b_offset = b_offset + (a_width ? *a_width : intl<1>());
    }
  }
  return ret;
}

Block Inst::GeneratePortMaps(const std::shared_ptr<Port> &port) {
  Block ret;
  std::deque<std::shared_ptr<Edge>> connections;
  // Check if this is an input or output port
  if (IsInputTerminator(port)) {
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
      ret << GeneratePortMappingPair(pairs, port, other);
    } else {
      throw std::runtime_error(
          "No type mapping available for: Port[" + port->name() + ": " + port->type()->name()
              + "] to Other[" + other->name() + " : " + other->type()->name() + "]");
    }
  }
  return ret;
}

Block Inst::GeneratePortArrayMaps(const std::shared_ptr<PortArray> &array) {
  Block ret;
  // Go over each node in the array
  for (const auto &n : array->nodes()) {
    auto p = *Cast<Port>(n);
    ret << GeneratePortMaps(p);
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

  auto num_ports = inst->CountNodes(Node::PORT) + inst->CountArrays(Node::PORT);
  if (num_ports > 0) {
    // Port map
    Line ph, pf;
    ph << "port map (";
    pmh << ph;
    for (const auto &p : inst->GetAll<Port>()) {
      Block pm;
      pm << GeneratePortMaps(p);
      pmb << pm;
    }
    for (const auto &a : inst->GetAll<PortArray>()) {
      Block pm;
      pm << GeneratePortArrayMaps(a);
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

}  // namespace cerata::vhdl
