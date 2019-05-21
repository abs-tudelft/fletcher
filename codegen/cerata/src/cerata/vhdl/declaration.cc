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

#include "cerata/vhdl/declaration.h"

#include <memory>
#include <string>
#include <vector>
#include <deque>
#include <iostream>
#include <algorithm>

#include "cerata/edges.h"
#include "cerata/nodes.h"
#include "cerata/types.h"
#include "cerata/graphs.h"
#include "cerata/vhdl/identifier.h"
#include "cerata/vhdl/vhdl_types.h"

namespace cerata::vhdl {

std::string Decl::Generate(const Type *type, const std::optional<std::shared_ptr<Node>> &multiplier) {
  switch (type->id()) {
    default: {
      if (!multiplier) {
        return "std_logic";
      } else {
        return "std_logic_vector(" + ((*multiplier) - 1)->ToString() + " downto 0)";
      }
    }
    case Type::VECTOR: {
      auto vec = *Cast<Vector>(type);
      auto width = vec->width();
      if (width) {
        auto wnode = (*width);
        if (!multiplier) {
          return "std_logic_vector(" + (wnode - 1)->ToString() + " downto 0)";
        } else {
          return "std_logic_vector(" + (*multiplier * wnode - 1)->ToString() + " downto 0)";
        }
      } else {
        return "<incomplete type>";
      }
    }
    case Type::RECORD: {
      auto r = Cast<Record>(type);
      return (*r)->name();
    }
    case Type::INTEGER: {
      return "integer";
    }
    case Type::NATURAL: {
      return "natural";
    }
    case Type::STREAM: {
      auto stream = *Cast<Stream>(type);
      return Generate(stream->element_type().get());
    }
    case Type::STRING: {
      return "string";
    }
    case Type::BOOLEAN: {
      return "boolean";
    }
  }
}

Block Decl::Generate(const std::shared_ptr<Parameter> &par, int depth) {
  Block ret(depth);
  Line l;
  l << to_upper(par->name()) << " : " << Generate(par->type().get());
  if (par->value()) {
    auto val = *par->value();
    l << " := " << val->ToString();
  } else if (par->default_value) {
    l << " := " << (*par->default_value)->ToString();
  }
  ret << l;
  return ret;
}

Block Decl::Generate(const std::shared_ptr<Port> &port, int depth) {
  Block ret(depth);
  // Filter out abstract types and flatten
  auto flat_types = FilterForVHDL(Flatten(port->type().get()));

  for (const auto &ft : flat_types) {
    Line l;
    auto port_name_prefix = port->name();
    l << ft.name(NamePart(port_name_prefix, true)) << " : ";
    if (ft.invert_) {
      l << ToString(Term::Invert(port->dir())) + " ";
    } else {
      l << ToString(port->dir()) + " ";
    }
    l << Generate(ft.type_);
    ret << l;
  }
  return ret;
}

Block Decl::Generate(const std::shared_ptr<PortArray> &port, int depth) {
  Block ret(depth);
  // Flatten the type of this port
  auto flat_types = FilterForVHDL(Flatten(port->type().get()));

  for (const auto &ft : flat_types) {
    Line l;
    auto port_name_prefix = port->name();
    l << ft.name(NamePart(port_name_prefix, true)) << " : ";
    if (ft.invert_) {
      l << ToString(Term::Invert(port->dir())) + " ";
    } else {
      l << ToString(port->dir()) + " ";
    }
    l << Generate(ft.type_, port->size());
    ret << l;
  }
  return ret;
}

Block Decl::Generate(const std::shared_ptr<Signal> &sig, int depth) {
  Block ret(depth);
  // Flatten the type of this port
  auto flat_types = FilterForVHDL(Flatten(sig->type().get()));

  // Generate signal decl for every flat type
  for (const auto &ft : flat_types) {
    Line l;
    auto sig_name_prefix = sig->name();
    l << "signal " + ft.name(NamePart(sig_name_prefix, true)) << " : ";
    l << Generate(ft.type_) + ";";
    ret << l;
  }
  return ret;
}

MultiBlock Decl::Generate(const Component *comp, bool entity) {
  MultiBlock ret(1);

  if (entity) {
    ret.indent = 0;
  }

  // Header
  Block h(ret.indent), f(ret.indent);
  Line hl, fl;
  if (entity) {
    hl << "entity " + comp->name() + " is";
  } else {
    hl << "component " + comp->name() + " is";
  }
  h << hl;
  ret << h;

  // Generics
  auto generics = comp->GetAll<Parameter>();
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

  auto ports = comp->GetAll<Port>();
  auto array_ports = comp->GetAll<PortArray>();
  if (!ports.empty() || !array_ports.empty()) {
    Block pdh(ret.indent + 1);
    Block pd(ret.indent + 2);
    Block pdf(ret.indent + 1);
    Line ph, pf;
    ph << "port (";
    pdh << ph;
    // Process ports
    for (const auto &port : ports) {
      auto g = Decl::Generate(port, ret.indent + 2);
      if (port != ports.back() || !array_ports.empty()) {
        g << ";";
      } else {
        g <<= ";";
      }
      pd << g;
    }
    // Process array ports
    for (const auto &array_port : array_ports) {
      auto g = Decl::Generate(array_port, ret.indent + 2);
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
