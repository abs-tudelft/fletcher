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
#include <vector>

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
  static Block Generate(const std::shared_ptr<Type> &type, const std::shared_ptr<Node> &parent, int depth = 0);
  static Block Generate(const std::shared_ptr<Stream> &stream, const std::shared_ptr<Node> &parent, int depth = 0);
  static Block Generate(const std::shared_ptr<Record> &rec, const std::shared_ptr<Node> &parent, int depth = 0);
  static Block Generate(const std::shared_ptr<Parameter> &par, int depth = 0);
  static Block Generate(const std::shared_ptr<Node> &port, int depth = 0);
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

class Architecture {
 public:
  static MultiBlock Generate(const std::shared_ptr<Component> &comp) {
    MultiBlock ret;
    Line header_line;
    header_line << "architecture Implementation of " + comp->name() + " is";
    ret << header_line;

    // Component declarations
    auto components_used = GetAllUniqueComponents(comp);
    for (const auto &c : components_used) {
      auto comp_decl = Declarator::Generate(c);
      ret << comp_decl;
    }

    // Signal declarations
    auto signals = comp->GetAllNodesOfType<Signal>();
    for (const auto &s : signals) {
      auto signal_decl = Declarator::Generate(s);
      ret << Prepend("signal", &signal_decl, " ");
    }

    Line header_end;
    header_end << "is begin";
    ret << header_end;

    // Component instantiations
    auto instances = comp->GetAllInstances();
    for (const auto &i : instances) {
      auto inst_decl = Instantiator::Generate(i);
      ret << inst_decl;
    }

    // Signal connections

    return ret;
  }
};

}  // namespace vhdl
}  // namespace fletchgen
