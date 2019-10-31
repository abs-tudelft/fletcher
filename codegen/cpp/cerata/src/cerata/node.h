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
#include <vector>
#include <unordered_map>

#include "cerata/object.h"
#include "cerata/type.h"
#include "cerata/domain.h"

namespace cerata {

// Forward declarations.
class Edge;
class Graph;
class Port;
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
  Node *SetType(const std::shared_ptr<Type> &type);

  /// @brief Return the node type ID
  inline NodeID node_id() const { return node_id_; }
  /// @brief Return whether this node is of a specific node type id.
  inline bool Is(NodeID node_id) const { return node_id_ == node_id; }

  /// Casting convenience functions
#ifndef NODE_CAST_DECL_FACTORY
#define NODE_CAST_DECL_FACTORY(NODE_TYPE, NODE_ID)                            \
  inline bool Is##NODE_TYPE() const { return node_id_ == (NodeID::NODE_ID); } \
  NODE_TYPE* As##NODE_TYPE();                                                 \
  const NODE_TYPE* As##NODE_TYPE() const;
#endif
  NODE_CAST_DECL_FACTORY(Port, PORT)
  NODE_CAST_DECL_FACTORY(Signal, SIGNAL)
  NODE_CAST_DECL_FACTORY(Literal, LITERAL)
  NODE_CAST_DECL_FACTORY(Parameter, PARAMETER)
  NODE_CAST_DECL_FACTORY(Expression, EXPRESSION)

  /// @brief Add an edge to this node.
  virtual bool AddEdge(const std::shared_ptr<Edge> &edge) = 0;
  /// @brief Remove an edge of this node.
  virtual bool RemoveEdge(Edge *edge) = 0;
  /// @brief Return all edges this Node is on.
  virtual std::vector<Edge *> edges() const;
  /// @brief Get the input edges of this Node.
  virtual std::vector<Edge *> sources() const { return {}; }
  /// @brief Get the output edges of this Node.
  virtual std::vector<Edge *> sinks() const { return {}; }

  /// @brief Set parent array.
  void SetArray(NodeArray *array) { array_ = array; }
  /// @brief Return parent array, if any.
  std::optional<NodeArray *> array() const { return array_; }

  /// @brief Replace some node with another node, reconnecting all original edges. Returns the replaced node.
  Node *Replace(Node *replacement);

  /**
   * @brief Copy node onto a graph, implicitly copying over and rebinding e.g. type generics of referenced nodes.
   *
   * Referenced nodes means any nodes this node references in its implementation (including its type), but not that it
   * connects to through edges in the graph.
   *
   * Implicitly rebinding means that, first, any referenced nodes will be searched for on the graph by name.
   * If they don't exist, copies will be made onto the graph as well.
   *
   * This function appends this node to the rebinding.
   *
   * @param dst       The destination graph to copy the node onto.
   * @param name      The name of the new node.
   * @param rebinding The rebinding to use, and to append, if required.
   * @return          The copy.
   */
  virtual Node *CopyOnto(Graph *dst, const std::string &name, NodeMap *rebinding) const;

  /// @brief Return all objects referenced by this node. For default nodes, these are type generics only.
  void AppendReferences(std::vector<Object *> *out) const override;

  /// @brief Return a human-readable string of this node.
  virtual std::string ToString() const;

 protected:
  /// Node type ID.
  NodeID node_id_;
  /// The Type of this Node.
  std::shared_ptr<Type> type_;
  /// Parent if this belongs to an array
  std::optional<NodeArray *> array_ = {};
};

/// @brief Convert a Node ID to a human-readable string.
std::string ToString(Node::NodeID id);

/// A mapping from one object to another object, used in e.g. type generic rebinding.
typedef std::unordered_map<const Node *, Node *> NodeMap;

/**
 * @brief A no-input, multiple-outputs node.
 */
struct MultiOutputNode : public Node {
  /// @brief The outgoing Edges that sink this Node.
  std::vector<std::shared_ptr<Edge>> outputs_;

  /// @brief MultiOutputNode constructor.
  MultiOutputNode(std::string name, Node::NodeID id, std::shared_ptr<Type> type)
      : Node(std::move(name), id, std::move(type)) {}

  /// @brief Return the incoming edges (in this case just the single input edge) that sources this Node.
  std::vector<Edge *> sources() const override { return {}; }
  /// @brief The outgoing Edges that this Node sinks.
  std::vector<Edge *> sinks() const override { return ToRawPointers(outputs_); }

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
 * @brief A single-input, multiple-outputs node.
 */
struct NormalNode : public MultiOutputNode {
  /// @brief The incoming Edge that sources this Node.
  std::shared_ptr<Edge> input_;

  /// @brief NormalNode constructor.
  NormalNode(std::string name, Node::NodeID id, std::shared_ptr<Type> type)
      : MultiOutputNode(std::move(name), id, std::move(type)) {}

  /// @brief Return the incoming edges (in this case just the single input edge).
  std::vector<Edge *> sources() const override;

  /// @brief Return the single incoming edge.
  std::optional<Edge *> input() const;

  /// @brief Add an edge to this node.
  bool AddEdge(const std::shared_ptr<Edge> &edge) override;

  /// @brief Remove an edge from this node.
  bool RemoveEdge(Edge *edge) override;
};

/**
 * @brief Get any sub-objects that are used by an object, e.g. type generic nodes or array size nodes.
 * @param obj The object from which to derive the required objects.
 * @param out The output.
 */
void GetObjectReferences(const Object &obj, std::vector<Object *> *out);

/// @brief Make sure that the NodeMap contains all nodes to be rebound onto the destination graph.
void ImplicitlyRebindNodes(Graph *dst, const std::vector<Node *> &nodes, NodeMap *rebinding);

}  // namespace cerata
