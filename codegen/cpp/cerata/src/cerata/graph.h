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

#include "cerata/node.h"
#include "cerata/node_array.h"
#include "cerata/pool.h"

namespace cerata {

// Forward Decl.
class Component;
class Instance;

/**
 * @brief A graph representing a hardware structure.
 */
class Graph : public Named {
 public:
  /// Graph type ID for convenient run-time type checking.
  enum ID {
    COMPONENT,  ///< A component graph
    INSTANCE    ///< An instance graph
  };

  /// @brief Construct a new graph
  Graph(std::string name, ID id) : Named(std::move(name)), id_(id) {}

  /// @brief Return the graph type ID.
  ID id() const { return id_; }
  /// @brief Return true if this graph is a component, false otherwise.
  bool IsComponent() const { return id_ == COMPONENT; }
  /// @brief Return true if this graph is an instance, false otherwise.
  bool IsInstance() const { return id_ == INSTANCE; }
  /// @brief Add an object to the component.
  virtual Graph &Add(const std::shared_ptr<Object> &obj);
  /// @brief Add a list of objects to the component.
  virtual Graph &Add(const std::initializer_list<std::shared_ptr<Object>> &objs);
  /// @brief Remove an object from the component
  virtual Graph &Remove(Object *obj);

  /// @brief Get all objects of a specific type.
  template<typename T>
  std::deque<T *> GetAll() const {
    std::deque<T *> ret;
    for (const auto &o : objects_) {
      auto co = std::dynamic_pointer_cast<T>(o);
      if (co != nullptr)
        ret.push_back(co.get());
    }
    return ret;
  }

  /// @brief Get a NodeArray object of a specific type with a specific name
  std::optional<NodeArray *> GetArray(Node::NodeID node_id, const std::string &array_name) const;
  /// @brief Get a Node of a specific type with a specific name
  std::optional<Node *> GetNode(const std::string &node_name) const;
  /// @brief Get a Node of a specific type with a specific name
  Node *GetNode(Node::NodeID node_id, const std::string &node_name) const;
  /// @brief Obtain all nodes which ids are in a list of Node::IDs
  std::deque<Node *> GetNodesOfTypes(std::initializer_list<Node::NodeID> ids) const;
  /// @brief Count nodes of a specific node type
  size_t CountNodes(Node::NodeID id) const;
  /// @brief Count nodes of a specific array type
  size_t CountArrays(Node::NodeID id) const;
  /// @brief Get all nodes.
  std::deque<Node *> GetNodes() const { return GetAll<Node>(); }
  /// @brief Get all nodes of a specific type.
  std::deque<Node *> GetNodesOfType(Node::NodeID id) const;
  /// @brief Get all arrays of a specific type.
  std::deque<NodeArray *> GetArraysOfType(Node::NodeID id) const;
  /// @brief Return all graph nodes that do not explicitly belong to the graph.
  std::deque<Node *> GetImplicitNodes() const;

  /// @brief Shorthand to Get(, ..)
  PortArray *porta(const std::string &port_name) const;
  /// @brief Shorthand to Get(Node::PORT, ..)
  Port *port(const std::string &port_name) const;
  /// @brief Shorthand to Get(Node::SIGNAL, ..)
  Signal *sig(const std::string &signal_name) const;
  /// @brief Shorthand to Get(Node::PARAMETER, ..)
  Parameter *par(const std::string &signal_name) const;

  /// @brief Return a copy of the metadata.
  std::unordered_map<std::string, std::string> meta() const { return meta_; }
  /// @brief Get all objects.
  std::deque<Object *> objects() const { return ToRawPointers(objects_); }

  /// @brief Set metadata
  Graph &SetMeta(const std::string &key, std::string value);

  /// @brief Return a human-readable representation.
  std::string ToString() const { return name(); }

 protected:
  /// Graph type id for convenience
  ID id_;
  /// Graph objects.
  std::deque<std::shared_ptr<Object>> objects_;
  /// KV storage for metadata of tools or specific backend implementations
  std::unordered_map<std::string, std::string> meta_;
};

/**
 * @brief A Component graph.
 *
 * A component graph may contain all node types.
 */
class Component : public Graph {
 public:
  /// @brief Construct a Component with initial nodes
  static std::shared_ptr<Component> Make(std::string name,
                                         const std::deque<std::shared_ptr<Object>> &nodes,
                                         ComponentPool *component_pool = default_component_pool());

  /// @brief Construct an empty Component with only a name.
  static std::shared_ptr<Component> Make(std::string name,
                                         ComponentPool *component_pool = default_component_pool()) {
    return Make(std::move(name), {}, component_pool);
  }

  /**
   * @brief Add and take ownership of an Instance graph.
   * @param child   The child graph to add.
   * @return        This component if successful.
   */
  Component &AddChild(std::unique_ptr<Instance> child);

  /**
   * @brief Add a child Instance from a component.
   * @param comp    The component to instantiate and add.
   * @param name    The name of the new instance. If left blank, it will use the Component name + "_inst".
   * @return        A pointer to the instantiated component.
   */
  Instance *AddInstanceOf(Component *comp, const std::string &name = "");

  /// @brief Returns all Instance graphs from this Component.
  std::deque<Instance *> children() const { return ToRawPointers(children_); }

  /// @brief Returns all unique Components that are referred to by child Instances of this graph.
  virtual std::deque<const Component *> GetAllUniqueComponents() const;

 protected:
  /// @brief Construct an empty Component.
  explicit Component(std::string name) : Graph(std::move(name), COMPONENT) {}

  /// Graph children / subgraphs.
  std::deque<std::unique_ptr<Instance>> children_;
};

/**
 * @brief An instance.
 *
 * An instance graph may not contain any signals.
 */
class Instance : public Graph {
 public:
  /// @brief Construct a shared pointer to a Component
  static std::unique_ptr<Instance> Make(Component *component, const std::string &name);

  /// @brief Construct a shared pointer to a Component
  static std::unique_ptr<Instance> Make(Component *component);

  /// @brief Add a node to the component, throwing an exception if the node is a signal.
  Graph &Add(const std::shared_ptr<Object> &obj) override;

  /// @brief Return the component this is an instance of.
  Component *component() const { return component_; }

  /// @brief Return the parent graph.
  Graph *parent() const { return parent_; }

  /// @brief Set the parent.
  Graph &SetParent(Graph *parent);

 protected:
  /// @brief Construct an Instance of a Component, copying over all its ports and parameters
  explicit Instance(Component *comp, std::string name);
  /// The component that this instance instantiates.
  Component *component_{};
  /// The parent of this instance.
  Graph *parent_{};
};

}  // namespace cerata
