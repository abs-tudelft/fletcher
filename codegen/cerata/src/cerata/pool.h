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
#include <vector>
#include <memory>

#include "cerata/node.h"

namespace cerata {

// Forward decl.
class Component;
class Node;
struct Literal;

/**
 * @brief A component pool to keep a collection of components.
 */
class ComponentPool {
 public:
  void Add(const std::shared_ptr<Component> &comp);
  std::optional<Component*> Get(const std::string& name);
  void Clear();
 protected:
  std::vector<std::shared_ptr<Component>> components_;
};

/// @brief Return a global default component pool.
inline ComponentPool *default_component_pool() {
  static ComponentPool pool;
  return &pool;
}

class NodePool {
 public:
  void Add(const std::shared_ptr<Node> &node);

  template<typename T>
  std::shared_ptr<Literal> GetLiteral(T value) {
    // Attempt to find and return an already existing literal
    for (const auto &node : nodes_) {
      if (node->IsLiteral()) {
        auto lit_node = std::dynamic_pointer_cast<Literal>(node);
        if (lit_node->raw_value<T>() == value) {
          return lit_node;
        }
      }
    }
    // No literal found, make a new one.
    std::shared_ptr<Literal> ret = Literal::Make(value);
    Add(ret);
    return ret;
  }

 protected:
  std::vector<std::shared_ptr<Node>> nodes_;
};

/**
 * @brief Return a global default node pool that can store nodes without being owned by a graph.
 */
inline NodePool *default_node_pool() {
  static NodePool pool;
  return &pool;
}

/// @brief Shorthand for default_node_pool->intl(i).get()
inline Literal *rintl(int i) { return default_node_pool()->GetLiteral(i).get(); }
/// @brief Shorthand for default_node_pool->intl(i)
inline std::shared_ptr<Literal> intl(int i) { return default_node_pool()->GetLiteral(i); }

/// @brief Shorthand for default_node_pool->intl(i).get()
inline Literal *rstrl(std::string str) { return default_node_pool()->GetLiteral(str).get(); }
/// @brief Shorthand for default_node_pool->intl(i)
inline std::shared_ptr<Literal> strl(std::string str) { return default_node_pool()->GetLiteral(str); }

}  // namespace cerata
