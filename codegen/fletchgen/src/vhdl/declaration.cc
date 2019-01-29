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

#include "declaration.h"

#include <memory>
#include <string>
#include <vector>
#include <deque>

#include "../nodes.h"
#include "../types.h"
#include "../graphs.h"

#include "./flatnode.h"
#include "./vhdl_types.h"

namespace fletchgen {
namespace vhdl {

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
  for (const auto &tup : fn.tuples()) {
    Line l;
    l << std::get<0>(tup).ToString() << " : " << ToString(port->dir) + " " << Generate(std::get<1>(tup));
    ret << l;
  }
  return ret;
}

Block Decl::Generate(const std::shared_ptr<Signal> &sig, int depth) {
  Block ret(depth);
  auto fn = FlatNode(sig);
  for (const auto &tup : fn.tuples()) {
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

}  // namespace vhdl
}  // namespace fletchgen
