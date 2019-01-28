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

#include <optional>
#include <string>
#include <memory>
#include <utility>
#include <deque>

#include "./nodes.h"

namespace fletchgen {

struct Graph : public Named {
  enum ID {
    GENERIC,    ///< A generic graph
    COMPONENT,  ///< A component graph
    INSTANCE    ///< An instance graph
  };
  /// @brief Graph type id for convenience
  ID id;

  /// @brief Graph nodes.
  std::deque<std::shared_ptr<Node>> nodes;

  /// @brief Graph children / subgraphs.
  std::deque<std::shared_ptr<Graph>> children;

  /// @brief Optional Graph parents
  std::deque<Graph *> parents;

  /**
   * @brief Construct a new graph
   * @param name    The name of the graph
   */
  explicit Graph(std::string name, ID id) : Named(std::move(name)), id(id) {}
  virtual ~Graph() = default;

  /// @brief Get a node of a specific type with a specific name
  std::shared_ptr<Node> Get(Node::ID id, const std::string &node_name) const;

  /// @brief Add a node to the component
  virtual Graph &AddNode(std::shared_ptr<Node> node);

  /// @brief Count nodes of a specific node type
  size_t CountNodes(Node::ID id) const;

  /// @brief Add a child component
  virtual Graph &AddChild(const std::shared_ptr<Graph> &child);

  /// @brief Create a copy of the graph
  virtual std::shared_ptr<Graph> Copy() const;

  /**
   * @brief Obtain all nodes of type T from the graph
   * @tparam T  The node type to obtain
   * @return    A deque of nodes of type T
   */
  template<typename T>
  std::deque<std::shared_ptr<T>> GetAllNodesOfType() const {
    std::deque<std::shared_ptr<T>> result;
    for (const auto &n : nodes) {
      auto node = Cast<T>(n);
      if (node) {
        result.push_back(*node);
      }
    }
    return result;
  }
};

// Forward decl.
struct Instance;

/**
 * @brief A Component graph.
 *
 * A component graph may contain all node types.
 */
struct Component : public Graph {

  /// @brief Construct an empty Component
  explicit Component(std::string name) : Graph(std::move(name), COMPONENT) {}

  /// @brief Construct a Component with initial parameters and ports.
  static std::shared_ptr<Component> Make(std::string name,
                                         std::initializer_list<std::shared_ptr<Parameter>> parameters,
                                         std::initializer_list<std::shared_ptr<Port>> ports,
                                         std::initializer_list<std::shared_ptr<Signal>> signals);

  /// @brief Construct an empty Component with only a name.
  static std::shared_ptr<Component> Make(std::string name) { return Make(std::move(name), {}, {}, {}); }

  /**
   * @brief Add a child graph. Only allowed if the child graph is an instance. Throws an error otherwise.
   * @param child   The child graph to add.
   * @return        This component if successful.
   */
  Graph &AddChild(const std::shared_ptr<Graph> &child) override;

  /**
  * @brief Gather all Instance graphs from this Component
  * @param graph The graph to gather from.
  * @return      A deque holding smart pointer to all instances.
  */
  // TODO(johanpel): this function should probably be removed as for overridden AddChild all children must be Instance.
  std::deque<std::shared_ptr<Instance>> GetAllInstances();

  /// @brief Create a copy of the component
  std::shared_ptr<Graph> Copy() const override;
};

/**
 * @brief An instance.
 *
 * An instance graph may not contain any signals.
 */
struct Instance : public Graph {
  std::shared_ptr<Component> component;

  /// @brief Construct an Instance of a Component, copying over all its ports and parameters
  explicit Instance(std::string name, std::shared_ptr<Component> comp);

  /// @brief Construct a new Component, and turn it into a smart pointer.
  static std::shared_ptr<Instance> Make(std::string name, std::shared_ptr<Component> component);

  /// @brief Construct a new Component, turn it into a smart pointer, and use the Component name with _inst as suffix.
  static std::shared_ptr<Instance> Make(std::shared_ptr<Component> component);

  /// @brief Add a node to the component, throwing an exception if the node is a signal.
  Graph &AddNode(std::shared_ptr<Node> node) override;
};

/**
 * @brief Gather all unique Components that are children of (or are referred to by instances of) a graph.
 * @param graph The graph to gather the children from.
 * @return      A deque holding smart pointers to all unique components.
 */
std::deque<std::shared_ptr<Component>> GetAllUniqueComponents(const std::shared_ptr<Graph> &graph);

/**
 * @brief Cast a generic graph type object to a specific graph type object
 * @tparam T    The specific Graph type
 * @param obj   The generic Graph
 * @return      Optionally, a Graph of type T if the cast was valid.
 */
template<typename T>
std::optional<std::shared_ptr<T>> Cast(const std::shared_ptr<Graph> &obj) {
  auto result = std::dynamic_pointer_cast<T>(obj);
  if (result != nullptr) {
    return result;
  } else {
    return {};
  }
}

/**
 * @brief Cast a generic graph type object to a specific graph type object
 * @tparam T    The specific Graph type
 * @param obj   The generic Graph
 * @return      Optionally, a Graph of type T if the cast was valid.
 */
template<typename T>
std::optional<T *> Cast(Graph *obj) {
  auto result = dynamic_cast<T *>(obj);
  if (result != nullptr) {
    return result;
  } else {
    return {};
  }
}

}  // namespace fletchgen
