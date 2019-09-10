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
#include <utility>
#include <optional>

#include "cerata/logging.h"
#include "cerata/node.h"

namespace cerata {

// Forward decl.
class Type;
class Component;

/**
 * @brief A pool to share ownership of objects.
 *
 * Useful if these objects that are often used (e.g. integer literals), to be able to prevent unnecessary duplicates.
 */
template<typename T>
class Pool {
 public:
  /// @brief Add an object to the pool, taking shared ownership. Object may not already exist in the pool.
  void Add(const std::shared_ptr<T> &object) {
    for (const auto &existing_object : objects_) {
      if (existing_object->name() == object->name()) {
        CERATA_LOG(FATAL, "Object " + PoolTypeToString(*existing_object) + " already exists in pool.");
      }
    }
    objects_.push_back(object);
  }

  /// @brief Retrieve a component from the pool by name, if it exists. Returns empty option otherwise.
  std::optional<T *> Get(const std::string &name) {
    // Check for potential duplicate
    for (const auto &existing_object : objects_) {
      if (existing_object->name() == name) {
        return existing_object.get();
      }
    }
    return std::nullopt;
  }

  /// @brief Release ownership of all components.
  void Clear() {
    objects_.clear();
  }

 protected:
  /// A list of objects that this pool owns.
  std::vector<std::shared_ptr<T>> objects_;

 private:
  /**
   * @brief Returns a human-readable representation of an object stored in a pool.
   * @param object  The object itself.
   * @return        A human-readable string.
   */
  std::string PoolTypeToString(const T &object) {
    return object.ToString();
  }
};

/// A pool of Types.
class TypePool : public Pool<Type> {};

/// A pool of Components.
class ComponentPool : public Pool<Component> {};

/// @brief Return a global default TypePool.
inline TypePool *default_type_pool() {
  static TypePool pool;
  return &pool;
}

/// @brief Return a global default component pool.
inline ComponentPool *default_component_pool() {
  static ComponentPool pool;
  return &pool;
}

/**
 * @brief A pool of nodes.
 *
 * Useful to prevent duplicates of literal nodes.
 */
class NodePool : public Pool<Node> {
 public:
  /// @brief Obtain a literal node of raw storage type LitType with some value.
  template<typename LitType>
  std::shared_ptr<Literal> GetLiteral(LitType value) {
    // Attempt to find and return an already existing literal
    for (const auto &node : objects_) {
      if (node->IsLiteral()) {
        auto lit_node = std::dynamic_pointer_cast<Literal>(node);
        if (lit_node->storage_type() == StorageTypeOf<LitType>()) {
          auto raw_value = RawValueOf<LitType>(*lit_node);
          if (raw_value == value) {
            return lit_node;
          }
        }
      }
    }
    // No literal found, make a new one.
    std::shared_ptr<Literal> ret = Literal::Make(value);
    Add(ret);
    return ret;
  }
};

/**
 * @brief Return a global default node pool that can store nodes without being owned by a graph.
 */
inline NodePool *default_node_pool() {
  static NodePool pool;
  return &pool;
}

// Convenience functions for fast access to literals in the default node pool.

/// @brief Obtain a raw pointer to an integer literal from the default node pool.
inline Literal *rintl(int i) {
  return default_node_pool()->GetLiteral(i).get();
}
/// @brief Obtain a shared pointer to an integer literal from the default node pool.
inline std::shared_ptr<Literal> intl(int i) {
  return default_node_pool()->GetLiteral(i);
}
/// @brief Obtain a raw pointer to a string literal from the default node pool.
inline Literal *rstrl(std::string str) { return default_node_pool()->GetLiteral<std::string>(std::move(str)).get(); }
/// @brief Obtain a shared pointer to a string literal from the default node pool.
inline std::shared_ptr<Literal> strl(std::string str) {
  return default_node_pool()->GetLiteral<std::string>(std::move(str));
}
/// @brief Return a literal node representing a Boolean.
inline std::shared_ptr<Literal> booll(bool value) {
  return default_node_pool()->GetLiteral<bool>(value);
}

}  // namespace cerata
