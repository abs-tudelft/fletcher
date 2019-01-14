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

#include "./stream.h"
#include "./nodes.h"
#include "./types.h"
#include "./vhdl.h"
#include "./components.h"
#include "vhdl.h"

namespace fletchgen {
namespace vhdl {

using fletchgen::stream::Port;
using fletchgen::stream::Type;
using fletchgen::stream::Vector;
using fletchgen::stream::Signed;
using fletchgen::stream::Unsigned;
using fletchgen::stream::Record;
using fletchgen::stream::Parameter;
using fletchgen::stream::ComponentType;
using fletchgen::stream::Component;
using fletchgen::stream::NodeType;
using fletchgen::stream::Literal;

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

std::string Declarator::Generate(const std::shared_ptr<Type> &type) {
  if (type->id == Type::CLOCK) {
    return "std_logic";
  } else if (type->id == Type::RESET) {
    return "std_logic";
  } else if (type->id == Type::BIT) {
    return "std_logic";
  } else if (type->id == Type::VECTOR) {
    auto vec = std::dynamic_pointer_cast<Vector>(type);
    return "std_logic_vector(" + std::to_string(vec->high()) + " downto " + std::to_string(vec->low()) + ")";
  } else if (type->id == Type::SIGNED) {
    auto s = std::dynamic_pointer_cast<Signed>(type);
    return "signed(" + std::to_string(s->high()) + " downto " + std::to_string(s->low()) + ")";
  } else if (type->id == Type::UNSIGNED) {
    auto u = std::dynamic_pointer_cast<Unsigned>(type);
    return "unsigned(" + std::to_string(u->high()) + " downto " + std::to_string(u->low()) + ")";
  } else if (type->id == Type::RECORD) {
    auto r = std::dynamic_pointer_cast<Record>(type);
    return r->name();
  } else if (type->id == Type::NATURAL) {
    return "natural";
  } else {
    return "FLETCHGEN_INVALID_TYPE";
  }
}

std::string Declarator::Generate(const std::shared_ptr<Parameter> &par) {
  std::stringstream str;

  str << par->name() << " : " << " " << Generate(par->type);
  /*
  if (par->default_value != nullptr) {
    str << " := " << par->default_value;
  }
   */
  return str.str();
}

std::string Declarator::Generate(const std::shared_ptr<Port> &port) {
  std::stringstream str;
  if (port->type->id == Type::STREAM) {
    str << port->name() << "_data : " << ToString(port->dir) << " " << Generate(port->type) << ";\n";
    str << port->name() << "_valid : " << ToString(port->dir) << " " << Generate(port->type) << ";\n";
    str << port->name() << "_ready : " << ToString(Reverse(port->dir)) << " " << Generate(port->type);
  } else {
    str << port->name() << " : " << ToString(port->dir) << " " << Generate(port->type);
  }
  return str.str();
}

std::string Declarator::Generate(const std::shared_ptr<ComponentType> &comp,
                                 bool entity) {
  std::stringstream str;
  if (entity) {
    str << "entity " << comp->name() << "\n";
  } else {
    str << "component " << comp->name() << "\n";
  }
  if (!comp->parameters().empty()) {
    str << "generic (\n";
    for (const auto &gen : comp->parameters()) {
      str << Declarator::Generate(gen);
      if (gen != comp->parameters().back()) {
        str << ";\n";
      } else {
        str << "\n";
      }
    }
    str << ");\n";
  }
  if (!comp->ports().empty()) {
    str << "port (\n";
    for (const auto &port : comp->ports()) {
      str << Declarator::Generate(port);
      if (port != comp->ports().back()) {
        str << ";\n";
      } else {
        str << "\n";
      }
    }
    str << ");\n";
  }
  str << "end component;\n";
  return str.str();
}

std::string Instantiator::Generate(std::shared_ptr<Node> left,
                                   std::shared_ptr<Node> right,
                                   std::shared_ptr<Edge> edge) {
  std::stringstream str;

  auto leftidx = Edge::IndexOf(edge, left);
  auto rightidx = Edge::IndexOf(edge, right);

  if (left->type->type->id == Type::STREAM) {
    str << left->name() << "      (" << leftidx << ")" << " => " << right->name() << "      (" << rightidx << "),\n";
    str << left->name() << "_valid(" << leftidx << ")" << " => " << right->name() << "_valid(" << rightidx << "),\n";
    str << left->name() << "_ready(" << leftidx << ")" << " => " << right->name() << "_ready(" << rightidx << ")";
  } else {
    str << left->name() << "      (" << leftidx << ")" << " => " << right->name() << "      (" << rightidx << ")";
  }
  return str.str();
}

std::string Instantiator::Generate(const std::shared_ptr<Component> &comp) {
  std::stringstream str;

  str << comp->name() << " : " << comp->type->name() << "\n";

  // Generics from parameters
  if (comp->CountNodes(NodeType::PARAMETER) > 0) {
    str << "generic map ( \n";
    for (const auto &n : comp->nodes) {
      if (n->type->id == NodeType::PARAMETER) {
        str << Generate(n);
      }
    }
    str << ")\n";
  }

  // Connect port nodes
  if (comp->CountNodes(NodeType::PORT) > 0) {
    str << "port map ( \n";
    for (const auto &n : comp->nodes) {
      if (n->type->id == NodeType::PORT) {
        str << Generate(n);
      }
    }
    str << ")\n";
  }

  return str.str();
}

std::string Instantiator::Generate(const std::shared_ptr<Edge> &edge) {
  std::stringstream str;

  return str.str();
}

std::string Instantiator::Generate(const std::shared_ptr<Node> &node) {
  std::stringstream str;

  if (node->type->id == NodeType::ID::PARAMETER) {
    // Parameter nodes must be connected to a literal
    str << node->name();
    if (!node->edges().empty()) {
      for (const auto &e : node->edges()) {
        auto other = e->other(node);
        if (other->type->id == NodeType::LITERAL) {
          str << " <= " << std::dynamic_pointer_cast<Literal>(other->type)->value << ",";
        } else {
          throw std::runtime_error("Parameter node should be attached to literal node.");
        }
      }
    }
    str << "\n";
  } else if (node->type->id == NodeType::PORT) {
    // Port nodes must be connected to signals or other port nodes
    if (!node->edges().empty()) {
      for (const auto &e : node->edges()) {
        auto other = e->other(node);
        str << Generate(node, other, e) << "\n";
      }
    }
  }

  return str.str();
}

}
}
