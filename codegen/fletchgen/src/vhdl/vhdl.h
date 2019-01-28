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

#include <utility>
#include <memory>
#include <string>
#include <sstream>
#include <vector>
#include <iomanip>
#include <deque>
#include <tuple>

#include "../nodes.h"
#include "../types.h"
#include "../graphs.h"
#include "../edges.h"

#include "./block.h"

namespace fletchgen {
namespace vhdl {

class Identifier {
 private:
  char separator_ = '_';
  std::vector<std::string> parts_;
 public:
  Identifier() = default;
  Identifier(std::initializer_list<std::string> parts, char sep = '_');
  std::string ToString() const;
  Identifier &append(const std::string &part);
  Identifier &operator+=(const std::string &rhs);
};
Identifier operator+(const Identifier &lhs, const std::string &rhs);

std::shared_ptr<Type> valid();
std::shared_ptr<Type> ready();

std::string ToString(std::vector<Block> blocks);
std::string ToString(const std::shared_ptr<Node> &node);
std::string ToString(Port::Dir dir);
Port::Dir Reverse(Port::Dir dir);

/// @brief Structure to get flattened list of VHDL identifiers out of a Node with potentially nested type
struct FlatNode {
  std::shared_ptr<Node> node_;
  std::deque<std::tuple<Identifier, std::shared_ptr<Type>>> tuples_;
  explicit FlatNode(std::shared_ptr<Node> node);
  void FlattenNode(FlatNode *fn, const Identifier &prefix, const std::shared_ptr<Record> &record);
  void FlattenNode(FlatNode *fn, const Identifier &prefix, const std::shared_ptr<Stream> &stream);
  void FlattenNode(FlatNode *fn, const Identifier &prefix, const std::shared_ptr<Type> &type);
  std::string ToString() const;
  std::deque<std::tuple<Identifier, std::shared_ptr<Type>>> GetAll();
  std::tuple<Identifier, std::shared_ptr<Type>> Get(size_t i);
  size_t size();
};

struct Transformation {
  /**
   * @brief Transforms the component, inserting signals between port-to-port connections of instances.
   * @param comp    The component to transform
   * @return        The transformed component
   */
  static std::shared_ptr<Component> ResolvePortToPort(std::shared_ptr<Component> comp);
};

struct Decl {
  static std::string Generate(const std::shared_ptr<Type> &type);
  static Block Generate(const std::shared_ptr<Parameter> &par, int depth = 0);
  static Block Generate(const std::shared_ptr<Port> &port, int depth = 0);
  static Block Generate(const std::shared_ptr<Signal> &sig, int depth = 0);
  static MultiBlock Generate(const std::shared_ptr<Component> &comp, bool entity = false);
};

struct Inst {
  static MultiBlock Generate(const std::shared_ptr<Graph> &graph);
  static Block Generate(const std::shared_ptr<Port> &lhs);
  static Block Generate(const std::shared_ptr<Parameter> &port);
};

struct Arch {
  static MultiBlock Generate(const std::shared_ptr<Component> &comp);
};

struct Design {
  static MultiBlock Generate(const std::shared_ptr<Component> &comp);
};

}  // namespace vhdl
}  // namespace fletchgen
