// Copyright 2018-2019 Delft University of Technology
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
#include <vector>
#include <unordered_map>

#include "cerata/node.h"
#include "cerata/array.h"
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
  virtual Graph &Add(const std::shared_ptr<Object> &object);
  /// @brief Add a list of objects to the component.
  virtual Graph &Add(const std::vector<std::shared_ptr<Object>> &objects);
  /// @brief Remove an object from the component
  virtual Graph &Remove(Object *obj);

  /// @brief Get all objects of a specific type.
  template<typename T>
  std::vector<T *> GetAll() const {
    std::vector<T *> result;
    for (const auto &o : objects_) {
      auto co = std::dynamic_pointer_cast<T>(o);
      if (co != nullptr) {
        result.push_back(co.get());
      }
    }
    return result;
  }

  /// @brief Get one object of a specific type.
  template<typename T>
  T *Get(const std::string &name) const {
    for (const auto &o : objects_) {
      if (o->name() == name) {
        auto result = dynamic_cast<T *>(o.get());
        if (result == nullptr) {
          CERATA_LOG(FATAL, "Object with name " + name + " is not of type " + ::cerata::ToString<T>());
        }
        return result;
      }
    }
    CERATA_LOG(FATAL, "Object with name " + name + " does not exist on graph " + this->name()
        + "\n Should be one of the following: " + ToStringAllOjects());
  }

  /// @brief Find a node with a specific name.
  std::optional<Node *> FindNode(const std::string &node_name) const;
  /// @brief Get a Node of a specific type with a specific name
  Node *GetNode(const std::string &node_name) const;
  /// @brief Obtain a node by name.
  inline Node *operator()(const std::string &node_name) const { return GetNode(node_name); }

  /// @brief Obtain all nodes which ids are in a list of Node::IDs
  std::vector<Node *> GetNodesOfTypes(std::initializer_list<Node::NodeID> ids) const;
  /// @brief Count nodes of a specific node type
  size_t CountNodes(Node::NodeID id) const;
  /// @brief Count nodes of a specific array type
  size_t CountArrays(Node::NodeID id) const;
  /// @brief Get all nodes.
  std::vector<Node *> GetNodes() const { return GetAll<Node>(); }
  /// @brief Get all nodes of a specific type.
  std::vector<Node *> GetNodesOfType(Node::NodeID id) const;
  /// @brief Get all arrays of a specific type.
  std::vector<NodeArray *> GetArraysOfType(Node::NodeID id) const;
  /// @brief Return all graph nodes that do not explicitly belong to the graph.
  std::vector<Node *> GetImplicitNodes() const;

  /// @brief Shorthand to Get<PortArray>(...)
  PortArray *prt_arr(const std::string &name) const;
  /// @brief Shorthand to Get<SignalArray>(...)
  SignalArray *sig_arr(const std::string &name) const;
  /// @brief Shorthand to Get<Port>(...)
  Port *prt(const std::string &name) const;
  /// @brief Shorthand to Get<Signal>(...)
  Signal *sig(const std::string &name) const;
  /// @brief Shorthand to Get<Parameter>(...)
  Parameter *par(const std::string &name) const;

  /// @brief Get a parameter by supplying another parameter. Lookup is done according to the name of the supplied param.
  Parameter *par(const Parameter &param) const;
  /// @brief Get a parameter by supplying another parameter. Lookup is done according to the name of the supplied param.
  Parameter *par(const std::shared_ptr<Parameter> &param) const;

  /// @brief Return a copy of the metadata.
  std::unordered_map<std::string, std::string> meta() const { return meta_; }
  /// @brief Get all objects.
  std::vector<Object *> objects() const { return ToRawPointers(objects_); }
  /// @brief Return true if object with name already exists on graph.
  bool Has(const std::string &name);

  /// @brief Set metadata
  Graph &SetMeta(const std::string &key, std::string value);

  /// @brief Return a human-readable representation.
  std::string ToString() const { return name(); }

  /// @brief Return a comma separated list of object names.
  std::string ToStringAllOjects() const;

 protected:
  /// Graph type id for convenience
  ID id_;
  /// Graph objects.
  std::vector<std::shared_ptr<Object>> objects_;
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
  /// @brief Construct an empty Component.
  explicit Component(std::string name) : Graph(std::move(name), COMPONENT) {}

  /// @brief Add an object to the component.
  Graph &Add(const std::shared_ptr<Object> &object) override;
  /// @brief Add a list of objects to the component.
  Graph &Add(const std::vector<std::shared_ptr<Object>> &objects) override;
  /// @brief Remove an object from the component
  Graph &Remove(Object *object) override;

  /**
   * @brief Add an Instance of another Component to this component.
   * @param comp  The component to instantiate and add.
   * @param name  The name of the new instance. If left blank, it will use the Component name + "_inst".
   * @return      A pointer to the instantiated component.
   */
  Instance *Instantiate(Component *comp, const std::string &name = "");

  /**
   * @brief Add an Instance of another Component to this component.
   * @param comp  The component to instantiate and add.
   * @param name  The name of the new instance. If left blank, it will use the Component name + "_inst".
   * @return      A pointer to the instantiated component.
   */
  Instance *Instantiate(const std::shared_ptr<Component> &comp, const std::string &name = "");

  /// @brief Returns all Instance graphs from this Component.
  std::vector<Instance *> children() const { return ToRawPointers(children_); }

  /// @brief Returns all unique Components that are referred to by child Instances of this graph.
  virtual std::vector<const Component *> GetAllInstanceComponents() const;

  /// @brief Return true if child graph exists on instance.
  bool HasChild(const std::string &name) const;
  /// @brief Return true if instance is a child of component.
  bool HasChild(const Instance &inst) const;

  /// @brief Return the component node to instance node mapping.
  NodeMap *inst_to_comp_map() { return &inst_to_comp; }

 protected:
  /**
 * @brief Add and take ownership of an Instance graph.
 * @param child   The child graph to add.
 * @return        This component if successful.
 */
  Component &AddChild(std::unique_ptr<Instance> child);

  /// Instances.
  std::vector<std::unique_ptr<Instance>> children_;

  /// Whether this component was instantiated.
  bool was_instantiated = false;

  /// Mapping for instance nodes that have been connected.
  NodeMap inst_to_comp;
};

/// @brief Construct a Component with initial nodes
std::shared_ptr<Component> component(std::string name,
                                     const std::vector<std::shared_ptr<Object>> &nodes,
                                     ComponentPool *component_pool = default_component_pool());
/// @brief Construct an empty Component with only a name.
std::shared_ptr<Component> component(std::string name,
                                     ComponentPool *component_pool = default_component_pool());

/**
 * @brief An instance.
 *
 * An instance graph may not contain any signals.
 */
class Instance : public Graph {
 public:
  /// @brief Add a node to the component, throwing an exception if the node is a signal.
  Graph &Add(const std::shared_ptr<Object> &obj) override;
  /// @brief Return the component this is an instance of.
  Component *component() const { return component_; }
  /// @brief Return the parent graph.
  Graph *parent() const { return parent_; }
  /// @brief Set the parent.
  Graph &SetParent(Graph *parent);
  /// @brief Return the component node to instance node mapping.
  NodeMap *comp_to_inst_map() { return &comp_to_inst; }

 protected:
  /// Only a Component should be able to make instances.
  friend Component;
  /// @brief Construct an Instance of a Component, copying over all its ports and parameters
  explicit Instance(Component *comp, std::string name, Component* parent);
  /// Create an instance.
  static std::unique_ptr<Instance> Make(Component *component, const std::string &name, Component* parent);
  /// The component that this instance instantiates.
  Component *component_;
  /// The parent of this instance.
  Graph *parent_;
  /// Mapping from component port and parameter nodes to instantiated nodes.
  NodeMap comp_to_inst;
};

}  // namespace cerata
