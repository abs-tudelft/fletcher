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

#include <vector>
#include <string>

#include "cerata/logging.h"
#include "cerata/edge.h"
#include "cerata/node.h"
#include "cerata/expression.h"
#include "cerata/array.h"
#include "cerata/type.h"
#include "cerata/graph.h"
#include "cerata/pool.h"
#include "cerata/parameter.h"

#include "cerata/vhdl/instantiation.h"
#include "cerata/vhdl/identifier.h"
#include "cerata/vhdl/vhdl.h"

namespace cerata::vhdl {

static std::string lit2vhdl(const Literal &lit) {
  switch (lit.type()->id()) {
    default:return lit.ToString();
    case Type::STRING:
      // If it is a string enclose it within quotes
      return "\"" + lit.ToString() + "\"";
    case Type::BOOLEAN:
      // Convert to VHDL boolean
      if (lit.BoolValue()) {
        return "true";
      } else {
        return "false";
      }
  }
}

static bool IsInputTerminator(const Object &obj) {
  try {
    auto term = dynamic_cast<const Term &>(obj);
    return term.IsInput();
  }
  catch (const std::bad_cast &e) {
    return false;
  }
}

Block Inst::GenerateGenericMap(const Parameter &par) {
  Block ret;
  Line l;
  l << ToUpper(par.name()) << " => ";
  // Get the value to apply
  auto val = par.value();
  // If it is a literal, make it VHDL compatible
  if (val->IsLiteral()) {
    auto *lit = dynamic_cast<const Literal *>(val);
    l << lit2vhdl(*lit);
  } else {
    l << ToUpper(val->ToString());
  }
  ret << l;
  return ret;
}

static Block GenerateMappingPair(const MappingPair &p,
                                 size_t ia,
                                 const std::shared_ptr<Node> &offset_a,
                                 size_t ib,
                                 const std::shared_ptr<Node> &offset_b,
                                 const std::string &lh_prefix,
                                 const std::string &rh_prefix,
                                 bool a_is_array,
                                 bool b_is_array,
                                 bool full_array) {
  Block ret;

  std::shared_ptr<Node> next_offset_a;
  std::shared_ptr<Node> next_offset_b;

  auto a_width = p.flat_type_a(ia).type_->width();
  auto b_width = p.flat_type_b(ib).type_->width();

  next_offset_a = (offset_a + (b_width ? b_width.value() : rintl(0)));
  next_offset_b = (offset_b + (a_width ? a_width.value() : rintl(0)));

  if (p.flat_type_a(0).type_->Is(Type::RECORD)) {
    // Don't output anything for the abstract record type.
  } else {
    Line l;
    l << p.flat_type_a(ia).name(NamePart(lh_prefix, true));
    // if right side is concatenated onto the left side
    // or the left side is an array (right is also concatenated onto the left side)
    if ((p.num_b() > 1) || (a_is_array && !full_array)) {
      if (p.flat_type_a(ia).type_->Is(Type::BIT)) {
        l += "(" + offset_a->ToString() + ")";
      } else {
        l += "(" + (next_offset_a - 1)->ToString();
        l += " downto " + offset_a->ToString() + ")";
      }
    }
    l << " => ";
    l << p.flat_type_b(ib).name(NamePart(rh_prefix, true));
    if ((p.num_a() > 1) || (b_is_array && !full_array)) {
      if (p.flat_type_b(ib).type_->Is(Type::BIT)) {
        l += "(" + offset_b->ToString() + ")";
      } else {
        l += "(" + (next_offset_b - 1)->ToString();
        l += " downto " + offset_b->ToString() + ")";
      }
    }
    ret << l;
  }

  return ret;
}

static Block GeneratePortMappingPair(std::vector<MappingPair> pairs, const Node &a, const Node &b, bool full_array) {
  Block ret;
  // Sort the pair in order of appearance on the flat map
  std::sort(pairs.begin(), pairs.end(), [](const MappingPair &x, const MappingPair &y) -> bool {
    return x.index_a(0) < y.index_a(0);
  });
  bool a_array = false;
  bool b_array = false;
  size_t a_idx = 0;
  size_t b_idx = 0;
  // Figure out if these nodes are on NodeArrays and what their index is
  if (a.array()) {
    a_array = true;
    a_idx = a.array().value()->IndexOf(a);
  }
  if (b.array()) {
    b_array = true;
    b_idx = b.array().value()->IndexOf(b);
  }
  if (a.type()->meta.count(meta::FORCE_VECTOR) > 0) {
    a_array = true;
  }
  if (b.type()->meta.count(meta::FORCE_VECTOR) > 0) {
    b_array = true;
  }
  // Loop over all pairs
  for (const auto &pair : pairs) {
    // Offset on the right side
    std::shared_ptr<Node> b_offset = pair.width_a(intl(1)) * intl(b_idx);
    // Loop over everything on the left side
    for (int64_t ia = 0; ia < pair.num_a(); ia++) {
      // Get the width of the left side.
      auto a_width = pair.flat_type_a(ia).type_->width();
      // Offset on the left side.
      std::shared_ptr<Node> a_offset = pair.width_b(intl(1)) * intl(a_idx);
      for (int64_t ib = 0; ib < pair.num_b(); ib++) {
        // Get the width of the right side.
        auto b_width = pair.flat_type_b(ib).type_->width();
        // Generate the mapping pair with given offsets
        auto mpblock =
            GenerateMappingPair(pair, ia, a_offset, ib, b_offset, a.name(), b.name(), a_array, b_array, full_array);
        ret << mpblock;
        // Increase the offset on the left side.
        a_offset = a_offset + (b_width ? b_width.value() : rintl(1));
      }
      // Increase the offset on the right side.
      b_offset = b_offset + (a_width ? a_width.value() : rintl(1));
    }
  }
  return ret;
}

Block Inst::GeneratePortMaps(const Port &port, bool full_array) {
  Block result;
  std::vector<Edge *> connections;
  // Check if this is an input or output port
  if (IsInputTerminator(port)) {
    connections = port.sources();
  } else {
    connections = port.sinks();
  }
  // Get the port type.
  auto port_type = port.type();
  // Iterate over all connected edges
  for (const auto &edge : connections) {
    // Get the node on the other side of the connection
    auto other = *edge->GetOtherNode(port);
    // Get the other type.
    auto other_type = other->type();
    // Check if a type mapping exists
    auto optional_type_mapper = port_type->GetMapper(other_type);
    if (optional_type_mapper) {
      auto type_mapper = optional_type_mapper.value();
      // Obtain the unique mapping pairs for this mapping
      auto pairs = type_mapper->GetUniqueMappingPairs();
      // Generate the mapping for this port-node pair.
      result << GeneratePortMappingPair(pairs, port, *other, full_array);
    } else {
      CERATA_LOG(FATAL, "No type mapping available for: Port[" + port.name() + ": " + port.type()->name()
          + "] to Other[" + other->name() + " : " + other->type()->name() + "]");
    }
  }
  return result;
}

Block Inst::GeneratePortArrayMaps(const PortArray &port_array) {
  Block ret;
  // Figure out if this whole array is connected to a single other array.
  std::vector<NodeArray *> others;
  for (const auto &node : port_array.nodes()) {
    for (const auto &e : node->edges()) {
      auto other = e->GetOtherNode(*node);
      if (other) {
        if (other.value()->array()) {
          if (other.value()->array().value()->IsArray()) {
            auto na = dynamic_cast<NodeArray *>(other.value()->array().value());
            others.push_back(na);
          }
        }
      }
    }
  }
  // Remove duplicates.
  others.erase(std::unique(others.begin(), others.end()), others.end());
  bool full_array = others.size() == 1;

  // Go over each node in the array
  for (const auto &node : port_array.nodes()) {
    const auto &port = dynamic_cast<const Port &>(*node);
    ret << GeneratePortMaps(port, full_array);
    if (full_array) {
      break;
    }
  }
  return ret.Sort('(');
}

MultiBlock Inst::Generate(const Graph &graph) {
  MultiBlock ret(1);

  if (!graph.IsInstance()) {
    return ret;
  }
  auto &inst = dynamic_cast<const Instance &>(graph);

  Block ih(ret.indent);       // Instantiation header
  Block gmh(ret.indent + 1);  // generic map header
  Block gmb(ret.indent + 2);  // generic map body
  Block gmf(ret.indent + 1);  // generic map footer
  Block pmh(ret.indent + 1);  // port map header
  Block pmb(ret.indent + 2);  // port map body
  Block pmf(ret.indent + 1);  // port map footer

  ih << inst.name() + " : " + inst.component()->name();

  // Generic map
  if (inst.CountNodes(Node::NodeID::PARAMETER) > 0) {
    Line gh, gf;
    gh << "generic map (";
    gmh << gh;
    for (Parameter *g : inst.GetAll<Parameter>()) {
      gmb << GenerateGenericMap(*g);
    }
    gmb <<= ",";
    gf << ")";
    gmf << gf;
  }

  auto num_ports = inst.CountNodes(Node::NodeID::PORT) + inst.CountArrays(Node::NodeID::PORT);
  if (num_ports > 0) {
    // Port map
    Line ph, pf;
    ph << "port map (";
    pmh << ph;
    for (const auto &p : inst.GetAll<Port>()) {
      Block pm;
      pm << GeneratePortMaps(*p);
      pmb << pm;
    }
    for (const auto &a : inst.GetAll<PortArray>()) {
      Block pm;
      pm << GeneratePortArrayMaps(*a);
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
