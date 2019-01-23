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

#include <memory>
#include <string>
#include <sstream>

#include "../stream.h"
#include "../nodes.h"
#include "../types.h"
#include "../graphs.h"

#include "./block.h"

namespace fletchgen {
namespace vhdl {

std::shared_ptr<Type> valid();
std::shared_ptr<Type> ready();

std::string ToString(std::vector<Block> blocks);
std::string ToString(Port::Dir dir);
Port::Dir Reverse(Port::Dir dir);

class Declarator {
 public:
  static std::string Generate(const std::shared_ptr<Type> &type);
  static Block Generate(const std::shared_ptr<Type> &type, const std::shared_ptr<Port>& parent, int depth = 0);
  static Block Generate(const std::shared_ptr<Stream> &stream, const std::shared_ptr<Port>& parent, int depth = 0);
  static Block Generate(const std::shared_ptr<Record> &rec, const std::shared_ptr<Port>& parent, int depth = 0);
  static Block Generate(const std::shared_ptr<Parameter> &par, int depth = 0);
  static Block Generate(const std::shared_ptr<Port> &port, int depth = 0);
  static MultiBlock Generate(const std::shared_ptr<Graph> &comp, bool entity = false);
};

class Instantiator {
 public:
  static MultiBlock Generate(const std::shared_ptr<Graph> &graph);
  static Block Generate(const std::shared_ptr<Node> &node);
  static Block Generate(std::shared_ptr<Node> left,
                        std::shared_ptr<Node> right,
                        std::shared_ptr<Edge> edge);
  static Block GenConcatenatedStream(std::shared_ptr<Node> left,
                                     std::shared_ptr<Node> right,
                                     std::shared_ptr<Edge> edge);
};

}  // namespace vhdl
}  // namespace fletchgen
