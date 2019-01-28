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

#include "./vhdl.h"

#include <algorithm>
#include <vector>
#include <string>
#include <memory>

#include "../edges.h"
#include "../nodes.h"
#include "../types.h"
#include "../graphs.h"

namespace fletchgen {
namespace vhdl {

using fletchgen::Port;
using fletchgen::Type;
using fletchgen::Vector;
using fletchgen::Record;
using fletchgen::Parameter;
using fletchgen::Component;
using fletchgen::Literal;
using fletchgen::Stream;

using std::to_string;

std::shared_ptr<Type> valid() {
  static std::shared_ptr<Type> result = std::make_shared<Bit>("valid");
  return result;
}

std::shared_ptr<Type> ready() {
  static std::shared_ptr<Type> result = std::make_shared<Bit>("ready");
  return result;
}

std::string ToString(Port::Dir dir) {
  if (dir == Port::Dir::IN) {
    return "in";
  } else {
    return "out";
  }
}

Port::Dir Reverse(Port::Dir dir) {
  if (dir == Port::Dir::IN) {
    return Port::Dir::OUT;
  } else {
    return Port::Dir::IN;
  }
}

std::string ToString(std::vector<Block> blocks) {
  std::stringstream ret;
  for (const auto &b : blocks) {
    ret << b.str();
  }
  return ret.str();
}

std::string ToString(const std::shared_ptr<Node> &node) {
  if (node->IsLiteral()) {
    auto x = *Cast<Literal>(node);
    return x->ToValueString();
  } else if (node->IsParameter()) {
    auto x = *Cast<Parameter>(node);
    return x->name();
  } else {
    return node->name();
  }
}

Identifier operator+(const Identifier &lhs, const std::string &rhs) {
  Identifier ret = lhs;
  ret.append(rhs);
  return ret;
}

std::string Decl::Generate(const std::shared_ptr<Type> &type) {
  if (type->Is(Type::CLOCK)) {
    return "std_logic";
  } else if (type->Is(Type::RESET)) {
    return "std_logic";
  } else if (type->Is(Type::BIT)) {
    return "std_logic";
  } else if (type->Is(Type::VECTOR)) {
    auto vec = Cast<Vector>(type);
    return "std_logic_vector(" + ToString(vec->width()) + "-1 downto 0)";
  } else if (type->Is(Type::RECORD)) {
    auto r = Cast<Record>(type);
    return r->name();
  } else if (type->Is(Type::NATURAL)) {
    return "natural";
  } else if (type->Is(Type::STREAM)) {
    return Generate(Cast<Stream>(type)->element_type());
  } else if (type->Is(Type::STRING)) {
    return "string";
  } else if (type->Is(Type::BOOLEAN)) {
    return "boolean";
  } else {
    return "FLETCHGEN_INVALID_TYPE";
  }
}

Block Decl::Generate(const std::shared_ptr<Parameter> &par, int depth) {
  Block ret(depth);
  Line l;
  l << par->name() << " : " << Generate(par->type_);
  if (par->default_value) {
    l << ":= " << par->default_value.value()->ToValueString();
  }
  ret << l;
  return ret;
}

Block Decl::Generate(const std::shared_ptr<Port> &port, int depth) {
  Block ret(depth);
  auto fn = FlatNode(port);
  for (const auto &tup : fn.GetAll()) {
    Line l;
    l << std::get<0>(tup).ToString() << " : " << ToString(port->dir) + " " << Generate(std::get<1>(tup));
    ret << l;
  }
  return ret;
}

Block Decl::Generate(const std::shared_ptr<Signal> &sig, int depth) {
  Block ret(depth);
  auto fn = FlatNode(sig);
  for (const auto &tup : fn.GetAll()) {
    Line l;
    l << "signal " + std::get<0>(tup).ToString() << " : " << Generate(std::get<1>(tup));
    ret << l;
  }
  return ret;
}

MultiBlock Decl::Generate(const std::shared_ptr<Component> &comp, bool entity) {
  MultiBlock ret;

  // Header
  Block h(ret.indent), f(ret.indent);
  Line hl, fl;
  if (entity) {
    hl << "entity " + comp->name();
  } else {
    hl << "component " + comp->name();
  }
  h << hl;
  ret << h;

  // Generics
  auto generics = comp->GetAllNodesOfType<Parameter>();
  if (!generics.empty()) {
    Block gdh(ret.indent + 1);
    Block gd(ret.indent + 2);
    Block gdf(ret.indent + 1);
    Line gh, gf;
    gh << "generic (";
    gdh << gh;
    for (const auto &gen : generics) {
      auto g = Decl::Generate(gen, ret.indent + 2);
      if (gen != generics.back()) {
        g << ";";
      } else {
        g <<= ";";
      }
      gd << g;
    }
    gf << ");";
    gdf << gf;
    ret << gdh << gd << gdf;
  }
  auto ports = comp->GetAllNodesOfType<Port>();
  if (!ports.empty()) {
    Block pdh(ret.indent + 1);
    Block pd(ret.indent + 2);
    Block pdf(ret.indent + 1);
    Line ph, pf;
    ph << "port (";
    pdh << ph;
    for (const auto &port : ports) {
      auto g = Decl::Generate(port, ret.indent + 2);
      if (port != ports.back()) {
        g << ";";
      } else {
        g <<= ";";
      }
      pd << g;
    }
    pf << ");";
    pdf << pf;
    ret << pdh << pd << pdf;
  }

  fl << "end component;";
  f << fl;

  ret << f;

  return ret;
}

bool IsCompatible(const std::shared_ptr<Node> &a, const std::shared_ptr<Node> &b) {
  auto fa = FlatNode(a);
  auto fb = FlatNode(b);

  // Not compatible if the top level type flattens to something with another number of tuples
  if (fa.size() != fb.size()) {
    return false;
  }

  // Not compatible if the type ids of flat view is different
  for (size_t i = 0; i < fa.size(); i++) {
    if (std::get<1>(fa.Get(i))->id != std::get<1>(fb.Get(i))->id) {
      std::cerr << std::get<1>(fa.Get(i))->name() << " != " << std::get<1>(fb.Get(i))->name() << std::endl;
      return false;
    }
  }

  // Otherwise, it is compatible
  return true;
}

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
        line << std::get<0>(fl.Get(i)).ToString();

        // Check if LHS indexing is applicable
        if (e->num_siblings(lhs) > 1) {
          line += "(" + std::to_string(Edge::GetIndexOf(e, lhs)) + ")";
        }

        line << " => ";

        // RHS name
        line << std::get<0>(fr.Get(i)).ToString();

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

MultiBlock Arch::Generate(const std::shared_ptr<Component> &comp) {
  MultiBlock ret;
  Line header_line;
  header_line << "architecture Implementation of " + comp->name() + " is";
  ret << header_line;

  // Component declarations
  auto components_used = GetAllUniqueComponents(comp);
  for (const auto &c : components_used) {
    auto comp_decl = Decl::Generate(c);
    ret << comp_decl;
  }

  // Signal declarations
  auto signals = comp->GetAllNodesOfType<Signal>();
  for (const auto &s : signals) {
    auto signal_decl = Decl::Generate(s);
    ret << signal_decl;
  }

  Line header_end;
  header_end << "is begin";
  ret << header_end;

  // Component instantiations
  auto instances = comp->GetAllInstances();
  for (const auto &i : instances) {
    auto inst_decl = Inst::Generate(i);
    ret << inst_decl;
  }

  // Signal connections

  return ret;
}

std::string Identifier::ToString() const {
  std::string ret;
  for (const auto &p : parts_) {
    ret += p;
    if (p != parts_.back()) {
      ret += separator_;
    }
  }
  return ret;
}

Identifier::Identifier(std::initializer_list<std::string> parts, char sep) : separator_(sep) {
  for (const auto &p : parts) {
    parts_.push_back(p);
  }
}

Identifier &Identifier::append(const std::string &part) {
  if (part.empty()) {
    std::cerr << "Part is empty... : " + this->ToString() << std::endl;
  } else {
    parts_.push_back(part);
  }
  return *this;
}

Identifier &Identifier::operator+=(const std::string &rhs) {
  return append(rhs);
}

FlatNode::FlatNode(std::shared_ptr<Node> node) : node_(std::move(node)) {
  Identifier top;
  top.append(node_->name());
  FlattenNode(this, top, node_->type_);
}

void FlatNode::FlattenNode(FlatNode *fn, const Identifier &prefix, const std::shared_ptr<Record> &record) {
  for (const auto &f : record->fields()) {
    FlattenNode(fn, prefix + f->name(), f->type());
  }
}

void FlatNode::FlattenNode(FlatNode *fn, const Identifier &prefix, const std::shared_ptr<Stream> &stream) {
  // Put valid and ready signal
  fn->tuples_.emplace_back(prefix + "valid", valid());
  fn->tuples_.emplace_back(prefix + "ready", ready());

  // Insert element type
  FlattenNode(fn, prefix + stream->element_name(), stream->element_type());
}

void FlatNode::FlattenNode(FlatNode *fn, const Identifier &prefix, const std::shared_ptr<Type> &type) {
  if (type->Is(Type::RECORD)) {
    FlattenNode(fn, prefix, Cast<Record>(type));
  } else if (type->Is(Type::STREAM)) {
    FlattenNode(fn, prefix, Cast<Stream>(type));
  } else {
    // Not nested types
    fn->tuples_.emplace_back(prefix, type);
  }
}

std::string FlatNode::ToString() const {
  std::stringstream ret;
  ret << "FlatNode: " << node_->name() << std::endl;
  for (const auto &t : tuples_) {
    ret << "  " << std::setw(16) << std::get<0>(t).ToString()
        << " : " << std::get<1>(t)->name() << std::endl;
  }
  return ret.str();
}

std::deque<std::tuple<Identifier, std::shared_ptr<Type>>> FlatNode::GetAll() {
  return tuples_;
}

size_t FlatNode::size() {
  return tuples_.size();
}

std::tuple<Identifier, std::shared_ptr<Type>> FlatNode::Get(size_t i) {
  return tuples_[i];
}

std::shared_ptr<Component> Transformation::ResolvePortToPort(std::shared_ptr<Component> comp) {
  for (const auto &inst : comp->GetAllInstances()) {
    for (const auto &port : inst->GetAllNodesOfType<Port>()) {
      for (const auto &edge : port->edges()) {
        if (edge->src->IsPort() && edge->dst->IsPort()) {
          auto sig = insert(edge, "int_");
          comp->AddNode(sig);
        }
      }
    }
  }
  return comp;
}

MultiBlock Design::Generate(const std::shared_ptr<Component> &comp) {
  MultiBlock ret;

  // Sanitize component
  auto vhdl_comp_copy = comp->Copy();
  auto vhdl_comp = *Cast<Component>(vhdl_comp_copy);
  Transformation::ResolvePortToPort(vhdl_comp);

  auto decl_code = Decl::Generate(vhdl_comp);
  auto arch_code = Arch::Generate(vhdl_comp);

  ret << decl_code;
  ret << arch_code;

  return ret;
}

}  // namespace vhdl
}  // namespace fletchgen
