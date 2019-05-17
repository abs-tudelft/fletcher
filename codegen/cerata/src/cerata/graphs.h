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
#include <optional>
#include <utility>
#include <deque>
#include <unordered_map>

#include "cerata/nodes.h"
#include "cerata/arrays.h"

namespace cerata {

/**
 * @brief A graph representing a hardware structure.
 */
struct Graph : public Named, public std::enable_shared_from_this<Graph> {
  enum ID {
    COMPONENT,  ///< A component graph
    INSTANCE    ///< An instance graph
  };
  /// @brief Graph type id for convenience
  ID id_;
  /// @brief Graph objects.
  std::deque<std::shared_ptr<Object>> objects_;
  /// @brief Graph children / subgraphs.
  std::deque<std::unique_ptr<Graph>> children;
  /// @brief Optional Graph parents
  std::deque<Graph *> parents;
  /// @brief KV storage for metadata of tools or specific backend implementations
  std::unordered_map<std::string, std::string> meta;

  /// @brief Return true if this graph is a component, false otherwise.
  bool IsComponent() const { return id_ == COMPONENT; }
  /// @brief Return true if this graph is an instance, false otherwise.
  bool IsInstance() const { return id_ == INSTANCE; }

  /**
   * @brief Construct a new graph
   * @param name    The name of the graph
   */
  explicit Graph(std::string name, ID id) : Named(std::move(name)), id_(id) {}
  virtual ~Graph() = default;

  /// @brief Add a child graph
  virtual Graph &AddChild(std::unique_ptr<Graph> child);
  /// @brief Add an object to the component
  virtual Graph &AddObject(const std::shared_ptr<Object> &obj);
  /// @brief Get all objects of a specific type.
  template<typename T>
  std::deque<std::shared_ptr<T>> GetAll() const {
    std::deque<std::shared_ptr<T>> ret;
    for (const auto &o : objects_) {
      auto co = std::dynamic_pointer_cast<T>(o);
      if (co != nullptr)
        ret.push_back(co);
    }
    return ret;
  }

  /// @brief Get all objects
  std::deque<std::shared_ptr<Object>> objects() { return objects_; }
  /// @brief Get a NodeArray object of a specific type with a specific name
  std::shared_ptr<NodeArray> GetArray(Node::NodeID node_id, const std::string &array_name) const;
  /// @brief Get a Node of a specific type with a specific name
  std::shared_ptr<Node> GetNode(Node::NodeID node_id, const std::string &node_name) const;
  /// @brief Obtain all nodes which ids are in a list of Node::IDs
  std::deque<std::shared_ptr<Node>>
  GetNodesOfTypes(std::initializer_list<Node::NodeID>
                  ids) const;
  /// @brief Count nodes of a specific node type
  size_t CountNodes(Node::NodeID id) const;
  /// @brief Count nodes of a specific array type
  size_t CountArrays(Node::NodeID id) const;
  /// @brief Get all nodes.
  std::deque<std::shared_ptr<Node>> GetNodes() const { return GetAll<Node>(); }
  /// @brief Get all nodes of a specific type.
  std::deque<std::shared_ptr<Node>> GetNodesOfType(Node::NodeID id) const;
  /// @brief Get all arrays of a specific type.
  std::deque<std::shared_ptr<NodeArray>> GetArraysOfType(Node::NodeID id) const;
  /// @brief Return all graph nodes that do not explicitly belong to the graph.
  std::deque<std::shared_ptr<Node>> GetImplicitNodes() const;

  /// @brief Shorthand to Get(, ..)
  std::shared_ptr<PortArray> porta(const std::string &port_name) const;
  /// @brief Shorthand to Get(Node::PORT, ..)
  std::shared_ptr<Port> port(const std::string &port_name) const;
  /// @brief Shorthand to Get(Node::SIGNAL, ..)
  std::shared_ptr<Signal> sig(const std::string &signal_name) const;
  /// @brief Shorthand to Get(Node::PARAMETER, ..)
  std::shared_ptr<Parameter> par(const std::string &signal_name) const;
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

  /// @brief Construct a Component with initial nodes
  static std::shared_ptr<Component> Make(std::string name, std::deque<std::shared_ptr<Object>> nodes);

  /// @brief Construct an empty Component with only a name.
  static std::shared_ptr<Component> Make(std::string name) { return Make(std::move(name), {}); }

  /**
   * @brief Add a child graph. Only allowed if the child graph is an instance. Throws an error otherwise.
   * @param child   The child graph to add.
   * @return        This component if successful.
   */
  Graph &AddChild(std::unique_ptr<Graph> child) override;


  /**
   * @brief Add a child instance from a component.
   * @param comp  The component to instantiate and add.
   * @param inst  Optional pointer to the instance to store.
   * @return      A reference to this Component if successful.
   */
  Instance* AddInstanceOf(std::shared_ptr<Component> comp, std::string name="");

  /**
  * @brief Gather all Instance graphs from this Component
  * @param graph The graph to gather from.
  * @return      A deque holding pointers to all instances.
  */
  std::deque<Instance *> GetAllInstances() const;
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
  static std::unique_ptr<Instance> Make(std::string name, std::shared_ptr<Component> component);

  /// @brief Construct a new Component, turn it into a smart pointer, and use the Component name with _inst as suffix.
  static std::unique_ptr<Instance> Make(std::shared_ptr<Component> component);

  /// @brief Add a node to the component, throwing an exception if the node is a signal.
  Graph &AddObject(const std::shared_ptr<Object> &obj) override;
};

/**
 * @brief Gather all unique Components that are children of (or are referred to by instances of) a graph.
 * @param graph The graph to gather the children from.
 * @return      A deque holding smart pointers to all unique components.
 */
std::deque<const Component *> GetAllUniqueComponents(const Graph *graph);

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
    return std::nullopt;
  }
}

/**
 * @brief Cast a generic graph type object to a specific graph type object
 * @tparam T    The specific Graph type
 * @param obj   The generic Graph
 * @return      Optionally, a Graph of type T if the cast was valid.
 */
template<typename T>
std::optional<std::unique_ptr<T>> Cast(const std::unique_ptr<Graph> &obj) {
  auto result = std::dynamic_pointer_cast<T>(obj);
  if (result != nullptr) {
    return result;
  } else {
    return std::nullopt;
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
    return std::nullopt;
  }
}

/**
 * @brief Cast a generic graph type object to a specific graph type object
 * @tparam T    The specific Graph type
 * @param obj   The generic Graph
 * @return      Optionally, a Graph of type T if the cast was valid.
 */
template<typename T>
std::optional<const T *> Cast(const Graph *obj) {
  auto result = dynamic_cast<const T *>(obj);
  if (result != nullptr) {
    return result;
  } else {
    return std::nullopt;
  }
}

}  // namespace cerata
