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
#include <memory>

#include "./nodes.h"

namespace fletchgen {

struct Component : public Named {
  std::deque<std::shared_ptr<Node>> nodes;
  std::deque<std::shared_ptr<Component>> children;

  /// @brief Construct an empty Component
  explicit Component(std::string name) : Named(std::move(name)) {}

  /// @brief Construct a Component with initial parameters and ports.
  static std::shared_ptr<Component> Make(std::string name,
                                         std::initializer_list<std::shared_ptr<Parameter>> parameters,
                                         std::initializer_list<std::shared_ptr<Port>> ports,
                                         std::initializer_list<std::shared_ptr<Signal>> signals);

  static std::shared_ptr<Component> Make(std::string name) { return Make(name, {}, {}, {}); }

  /// @brief Get a node of a specific type with a specific name
  std::shared_ptr<Node> Get(Node::ID id, std::string name);

  /// @brief Add a node to the component
  Component &Add(const std::shared_ptr<Node> &node);

  /// @brief Count nodes of a specific node type
  size_t CountNodes(Node::ID id);

  /// @brief Add a child component
  Component &Add(const std::shared_ptr<Component> &child);

  template<typename T>
  std::deque<std::shared_ptr<T>> GetAll() {
    std::deque<std::shared_ptr<T>> ret;
    for (const auto &n : nodes) {
      if (Cast<T>(n) != nullptr) {
        ret.push_back(Cast<T>(n));
      }
    }
  }
};

}  // namespace fletchgen
