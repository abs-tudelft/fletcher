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

#include <utility>
#include <optional>
#include <string>
#include <memory>
#include <deque>
#include <unordered_map>

#include "cerata/object.h"
#include "cerata/type.h"

namespace cerata {

// Forward declarations.
class Edge;
class Graph;
struct Port;
class Literal;
class Signal;
class Parameter;
class Expression;

/**
 * @brief A node.
 */
class Node : public Object, public std::enable_shared_from_this<Node> {
 public:
  /// Node type IDs with different properties.
  enum class NodeID {
    PORT,            ///< Single-input AND multi-output node with direction.
    SIGNAL,          ///< Single-input AND multi-output node.
    PARAMETER,       ///< Single-input AND multi-output node with default value.
    LITERAL,         ///< No-input     AND multi-output node with storage type and storage value.
    EXPRESSION,      ///< No-input     AND multi-output node that forms a binary tree with operations and nodes.
  };

  /// @brief Node constructor.
  Node(std::string name, NodeID id, std::shared_ptr<Type> type);

  /// @brief Return the node Type
  inline Type *type() const { return type_.get(); }
  /// @brief Set the node Type
  inline void SetType(const std::shared_ptr<Type> &type) { type_ = type; }

  /// @brief Return the node type ID
  inline NodeID node_id() const { return node_id_; }
  /// @brief Return whether this node is of a specific node type id.
  inline bool Is(NodeID node_id) const { return node_id_ == node_id; }

  /// Casting convenience functions
#ifndef NODE_CAST_DECL_FACTORY
#define NODE_CAST_DECL_FACTORY(NODENAME, IDNAME)                            \
  inline bool Is##NODENAME() const { return node_id_ == NodeID::IDNAME; }   \
  NODENAME& As##NODENAME();                                                 \
  const NODENAME& As##NODENAME() const;
  NODE_CAST_DECL_FACTORY(Port, PORT)
  NODE_CAST_DECL_FACTORY(Signal, SIGNAL)
  NODE_CAST_DECL_FACTORY(Parameter, PARAMETER)
  NODE_CAST_DECL_FACTORY(Literal, LITERAL)
  NODE_CAST_DECL_FACTORY(Expression, EXPRESSION)
#endif

  /// @brief Add an input to this node.
  virtual std::shared_ptr<Edge> AddSource(Node *input) = 0;
  /// @brief Add an output to this node.
  virtual std::shared_ptr<Edge> AddSink(Node *output) = 0;
  /// @brief Add an edge to this node.
  virtual bool AddEdge(const std::shared_ptr<Edge> &edge) = 0;
  /// @brief Remove an edge of this node.
  virtual bool RemoveEdge(Edge *edge) = 0;
  /// @brief Return all edges this Node is on.
  virtual std::deque<Edge *> edges() const;
  /// @brief Get the input edges of this Node.
  virtual std::deque<Edge *> sources() const { return {}; }
  /// @brief Get the output edges of this Node.
  virtual std::deque<Edge *> sinks() const { return {}; }
  /// @brief Recursively list any nodes that this node owns.
  virtual std::deque<const Node *> ownees() const { return {}; }

  /// @brief Set parent array.
  void SetArray(const NodeArray *array) { array_ = array; }
  /// @brief Return parent array, if any.
  std::optional<const NodeArray *> array() const { return array_; }

  /// @brief Return a human-readable string of this node.
  virtual std::string ToString() const;

 protected:
  /// Node type ID.
  NodeID node_id_;
  /// The Type of this Node.
  std::shared_ptr<Type> type_;
  /// Parent if this belongs to an array
  std::optional<const NodeArray *> array_ = {};
};

/**
 * @brief A MultiOutputNode is a Node that can drive multiple outputs.
 */
struct MultiOutputNode : public Node {
  /// @brief The outgoing Edges that sink this Node.
  std::deque<std::shared_ptr<Edge>> outputs_;

  /// @brief MultiOutputNode constructor.
  MultiOutputNode(std::string name, Node::NodeID id, std::shared_ptr<Type> type) : Node(std::move(name),
                                                                                        id,
                                                                                        std::move(type)) {}

  /// @brief Return the incoming edges (in this case just the single input edge).
  std::deque<Edge *> sources() const override { return {}; }
  /// @brief The outgoing Edges that have sinks to this Node.
  std::deque<Edge *> sinks() const override { return ToRawPointers(outputs_); }

  /// @brief Add an output edge to this node.
  std::shared_ptr<Edge> AddSink(Node *sink) override;
  /// @brief Remove an edge from this node.
  bool RemoveEdge(Edge *edge) override;
  /// @brief Add an output edge to this node.
  bool AddEdge(const std::shared_ptr<Edge> &edge) override;

  /// @brief Return output edge i of this node.
  inline std::shared_ptr<Edge> output(size_t i) const { return outputs_[i]; }
  /// @brief Return the number of edges of this node.
  inline size_t num_outputs() const { return outputs_.size(); }
};

/**
 * @brief A NormalNode is a single-input, multiple-outputs node
 */
struct NormalNode : public MultiOutputNode {
  /// @brief The incoming Edge that sources this Node.
  std::shared_ptr<Edge> input_;

  /// @brief NormalNode constructor.
  NormalNode(std::string name, Node::NodeID id, std::shared_ptr<Type> type) : MultiOutputNode(std::move(name),
                                                                                              id,
                                                                                              std::move(type)) {}

  /// @brief Return the incoming edges (in this case just the single input edge).
  std::deque<Edge *> sources() const override;

  /// @brief Return the single incoming edge.
  std::optional<Edge *> input() const;

  /// @brief Set the input edge of this node.
  std::shared_ptr<Edge> AddSource(Node *source) override;

  /// @brief Add an edge to this node.
  bool AddEdge(const std::shared_ptr<Edge> &edge) override;

  /// @brief Remove an edge from this node.
  bool RemoveEdge(Edge *edge) override;
};

/**
 * @brief Class to mark nodes with information for synchronous designs, e.g. clock domain.
 */
class Synchronous {
 public:
  /// @brief Synchronous constructor.
  explicit Synchronous(std::shared_ptr<ClockDomain> domain) : domain_(std::move(domain)) {}
  /// @brief Return the clock domain to which something is synchronized.
  std::shared_ptr<ClockDomain> domain() const { return domain_; }
  /// @brief Set the clock domain to which something should be synchronized.
  void SetDomain(std::shared_ptr<ClockDomain> domain) { domain_ = std::move(domain); }
 protected:
  /// The clock domain.
  std::shared_ptr<ClockDomain> domain_;
};

/**
 * @brief A Signal Node.
 *
 * A Signal Node can have a single input and multiple outputs.
 */
class Signal : public NormalNode, public Synchronous {
 public:
  /// @brief Signal constructor.
  Signal(std::string name, std::shared_ptr<Type> type, std::shared_ptr<ClockDomain> domain = default_domain());
  /// @brief Create a new Signal and return a smart pointer to it.
  static std::shared_ptr<Signal> Make(std::string name,
                                      const std::shared_ptr<Type> &type,
                                      std::shared_ptr<ClockDomain> domain = default_domain());
  /// @brief Create a new Signal and return a smart pointer to it. The Signal name is derived from the Type name.
  static std::shared_ptr<Signal> Make(const std::shared_ptr<Type> &type,
                                      std::shared_ptr<ClockDomain> domain = default_domain());
  /// @brief Create a copy of this Signal.
  std::shared_ptr<Object> Copy() const override;
};

/**
 * @brief A Parameter node.
 *
 * Can be used to define implementation-specific characteristics of a Graph, or can be connected to e.g. Vector widths.
 */
class Parameter : public NormalNode {
 public:
  /// @brief Get a smart pointer to a new Parameter, optionally owning a default value Literal.
  static std::shared_ptr<Parameter> Make(const std::string &name,
                                         const std::shared_ptr<Type> &type,
                                         const std::optional<std::shared_ptr<Literal>> &default_value = {});

  /// @brief Create a copy of this Parameter.
  std::shared_ptr<Object> Copy() const override;

  /// @brief Short hand to get value node.
  std::optional<Node *> GetValue() const;
 protected:
  /// @brief Construct a new Parameter, optionally defining a default value Literal.
  Parameter(std::string name,
            const std::shared_ptr<Type> &type,
            std::optional<std::shared_ptr<Literal>> default_value = {});

  /// @brief An optional default value.
  std::optional<std::shared_ptr<Literal>> default_value_;
};

/// @brief Convert a Node ID to a human-readable string.
std::string ToString(Node::NodeID id);

}  // namespace cerata
