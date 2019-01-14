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

#pragma once

#include <string>
#include <sstream>

#include "./stream.h"
#include "./nodes.h"
#include "./types.h"
#include "./components.h"

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
using fletchgen::stream::Edge;
using fletchgen::stream::Node;

std::string ToString(Port::Dir dir);
Port::Dir Reverse(Port::Dir dir);

class Declarator {
 public:
  static std::string Generate(const std::shared_ptr<Type> &type);
  static std::string Generate(const std::shared_ptr<Parameter> &par);
  static std::string Generate(const std::shared_ptr<Port> &port);
  static std::string Generate(const std::shared_ptr<ComponentType> &comp, bool entity = false);
};

class Instantiator {
 public:
  static std::string Generate(const std::shared_ptr<Component> &comp);
  static std::string Generate(const std::shared_ptr<Edge> &edge);
  static std::string Generate(const std::shared_ptr<Node> &node);
  static std::string Generate(std::shared_ptr<Node> left,
                              std::shared_ptr<Node> right,
                              std::shared_ptr<Edge> edge);
};

}  // namespace vhdl
}  // namespace fletchgen
