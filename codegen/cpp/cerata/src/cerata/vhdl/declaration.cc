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

#include "cerata/vhdl/declaration.h"

#include <memory>
#include <string>
#include <vector>

#include "cerata/node.h"
#include "cerata/expression.h"
#include "cerata/parameter.h"
#include "cerata/type.h"
#include "cerata/graph.h"
#include "cerata/vhdl/identifier.h"
#include "cerata/vhdl/vhdl_types.h"
#include "cerata/vhdl/vhdl.h"

namespace cerata::vhdl {

static std::string GenerateTypeDecl(const Type &type, std::optional<Node *> multiplier = std::nullopt) {
  std::shared_ptr<Node> mult;
  if (multiplier) {
    mult = multiplier.value()->shared_from_this();
  }
  switch (type.id()) {
    default: {
      if (!multiplier) {
        return "std_logic";
      } else {
        return "std_logic_vector(" + ToUpper((mult - 1)->ToString()) + " downto 0)";
      }
    }
    case Type::VECTOR: {
      auto &vec = dynamic_cast<const Vector &>(type);
      auto width = vec.width().value()->shared_from_this();
      if (!multiplier) {
        auto expr = width->shared_from_this() - 1;
        return "std_logic_vector(" + ToUpper(expr->ToString()) + " downto 0)";
      } else {
        auto expr = mult * width - 1;
        return "std_logic_vector(" + ToUpper(expr->ToString()) + " downto 0)";
      }
    }
    case Type::RECORD: {
      auto record = dynamic_cast<const Record &>(type);
      return record.name();
    }
    case Type::INTEGER: {
      return "integer";
    }
    case Type::STRING: {
      return "string";
    }
    case Type::BOOLEAN: {
      return "boolean";
    }
  }
}

Block Decl::Generate(const Parameter &par, int depth) {
  Block ret(depth);
  Line l;
  l << ToUpper(par.name()) << " : " << GenerateTypeDecl(*par.type());
  Node *val = par.value();
  auto val_str = val->ToString();
  if (par.type()->Is(Type::STRING)) {
    val_str = "\"" + val_str + "\"";
  }
  l << " := " << val_str;
  ret << l;
  return ret;
}

Block Decl::Generate(const Port &port, int depth) {
  Block ret(depth);
  // Filter out abstract types and flatten
  auto flat_types = FilterForVHDL(Flatten(port.type()));
  for (const auto &ft : flat_types) {
    Line l;
    auto port_name_prefix = port.name();
    l << ft.name(NamePart(port_name_prefix, true)) << " : ";
    if (ft.reverse_) {
      l << ToString(Term::Reverse(port.dir())) + " ";
    } else {
      l << ToString(port.dir()) + " ";
    }
    l << GenerateTypeDecl(*ft.type_);
    ret << l;
  }
  return ret;
}

Block Decl::Generate(const Signal &sig, int depth) {
  Block ret(depth);
  // Flatten the type of this port
  auto flat_types = FilterForVHDL(Flatten(sig.type()));

  // Generate signal decl for every flat type
  for (const auto &ft : flat_types) {
    Line l;
    auto sig_name_prefix = sig.name();
    l << "signal " + ft.name(NamePart(sig_name_prefix, true)) << " : ";
    if (ft.type_->meta.count(meta::FORCE_VECTOR)) {
      l << GenerateTypeDecl(*ft.type_, intl(1).get()) + ";";
    } else {
      l << GenerateTypeDecl(*ft.type_) + ";";
    }
    ret << l;
  }
  return ret;
}

Block Decl::Generate(const PortArray &port_array, int depth) {
  Block ret(depth);
  // Flatten the type of this port
  auto flat_types = FilterForVHDL(Flatten(port_array.type()));

  for (const auto &ft : flat_types) {
    Line l;
    auto port_name_prefix = port_array.name();
    l << ft.name(NamePart(port_name_prefix, true)) << " : ";
    if (ft.reverse_) {
      l << ToString(Term::Reverse(port_array.dir())) + " ";
    } else {
      l << ToString(port_array.dir()) + " ";
    }
    l << GenerateTypeDecl(*ft.type_, port_array.size());
    ret << l;
  }
  return ret;
}

Block Decl::Generate(const SignalArray &sig_array, int depth) {
  Block ret(depth);
  // Flatten the type of this port
  auto flat_types = FilterForVHDL(Flatten(sig_array.type()));

  for (const auto &ft : flat_types) {
    Line l;
    auto port_name_prefix = sig_array.name();
    l << "signal " + ft.name(NamePart(port_name_prefix, true)) << " : ";
    l << GenerateTypeDecl(*ft.type_, sig_array.size()) + ";";
    ret << l;
  }
  return ret;
}

MultiBlock Decl::Generate(const Component &comp, bool entity, int indent) {
  MultiBlock ret(indent);

  if (entity) {
    ret.indent = 0;
  }

  // Header
  Block h(ret.indent), f(ret.indent);
  Line hl, fl;
  if (entity) {
    hl << "entity " + comp.name() + " is";
  } else {
    hl << "component " + comp.name() + " is";
  }
  h << hl;
  ret << h;

  // Generics
  std::vector<Parameter *> parameters = comp.GetAll<Parameter>();
  if (!parameters.empty()) {
    Block gdh(ret.indent + 1);
    Block gd(ret.indent + 2);
    Block gdf(ret.indent + 1);
    Line gh, gf;
    gh << "generic (";
    gdh << gh;
    for (Parameter *gen : parameters) {
      auto g = Decl::Generate(*gen, ret.indent + 2);
      if (gen != parameters.back()) {
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

  auto ports = comp.GetAll<Port>();
  auto array_ports = comp.GetAll<PortArray>();
  if (!ports.empty() || !array_ports.empty()) {
    Block pdh(ret.indent + 1);
    Block pd(ret.indent + 2);
    Block pdf(ret.indent + 1);
    Line ph, pf;
    ph << "port (";
    pdh << ph;
    // Process ports
    for (const auto &port : ports) {
      auto g = Decl::Generate(*port, ret.indent + 2);
      if (port != ports.back() || !array_ports.empty()) {
        g << ";";
      } else {
        g <<= ";";
      }
      pd << g;
    }
    // Process array ports
    for (const auto &array_port : array_ports) {
      auto g = Decl::Generate(*array_port, ret.indent + 2);
      if (array_port != array_ports.back()) {
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

  if (entity) {
    fl << "end entity;";
  } else {
    fl << "end component;";
  }

  f << fl;

  ret << f;

  return ret;
}

}  // namespace cerata::vhdl
