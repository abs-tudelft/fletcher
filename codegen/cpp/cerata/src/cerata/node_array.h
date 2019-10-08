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
#include <optional>
#include <string>
#include <memory>
#include <deque>

#include "cerata/node.h"
#include "cerata/port.h"
#include "cerata/edge.h"
#include "cerata/type.h"

namespace cerata {

/// An array of nodes.
class NodeArray : public Object {
 public:
  /// @brief Return the type ID of the nodes in this NodeArray.
  Node::NodeID node_id() { return node_id_; }

  /// @brief ArrayNode constructor.
  NodeArray(std::string name, Node::NodeID id, std::shared_ptr<Node> base, std::shared_ptr<Node> size)
      : Object(std::move(name), Object::ARRAY), node_id_(id), base_(std::move(base)), size_(std::move(size)) {
    base_->SetArray(this);
  }

  /// @brief Set the parent of this NodeArray.
  void SetParent(Graph *parent) override;

  /// @brief Return the size node.
  inline Node *size() const { return size_.get(); }

  /// @brief Set the size node.
  void SetSize(const std::shared_ptr<Node> &size);

  /// @brief Return the type of the nodes in the NodeArray.
  Type *type() const { return base_->type(); }

  /// @brief Deep-copy the NodeArray.
  std::shared_ptr<Object> Copy() const override;

  /// @brief Append a node to this array, optionally incrementing the size node. Returns a pointer to that node.
  Node *Append(bool increment_size = true);
  /// @brief Return all nodes of this NodeArray.
  std::deque<Node *> nodes() const { return ToRawPointers(nodes_); }
  /// @brief Return element node i.
  Node *node(size_t i) const;
  /// @brief Return element node i.
  Node *operator[](size_t i) const { return node(i); }
  /// @brief Return the number of element nodes.
  size_t num_nodes() const { return nodes_.size(); }
  /// @brief Return the index of a specific node.
  size_t IndexOf(const Node &n) const;

  /// @brief Return a human-readable representation of this NodeArray.
  std::string ToString() const { return name(); }

  /// @brief Return the base node of this NodeArray.
  std::shared_ptr<Node> base() { return base_; }

 protected:
  /// The type ID of the nodes in this NodeArray.
  Node::NodeID node_id_;
  /// @brief Increment the size of the ArrayNode.
  void IncrementSize();
  /// A node representing the template for each of the element nodes.
  std::shared_ptr<Node> base_;
  /// A node representing the number of concatenated edges.
  std::shared_ptr<Node> size_;
  /// The nodes contained by this array
  std::deque<std::shared_ptr<Node>> nodes_;
};

/// An array of signal nodes.
class SignalArray : public NodeArray {
 public:
  /**
   * @brief Construct a new node array and return a shared pointer to it.
   * @param name    The name of the node array.
   * @param type    The type of the nodes in the node array.
   * @param size    The size node of the node array.
   * @param domain  The clock domain of the nodes in the node array.
   * @return        A shared pointer to the new node array.
   */
  static std::shared_ptr<NodeArray> Make(const std::string &name,
                                         const std::shared_ptr<Type> &type,
                                         std::shared_ptr<Node> size,
                                         const std::shared_ptr<ClockDomain> &domain = default_domain());
 protected:
  /// SignalArray constructor.
  SignalArray(const std::shared_ptr<Signal> &base, std::shared_ptr<Node> size) :
      NodeArray(base->name(), Node::NodeID::SIGNAL, std::dynamic_pointer_cast<Node>(base), std::move(size)) {}
};

/**
 * @brief An array of port nodes
 */
class PortArray : public NodeArray, public Term {
 public:
  /// @brief Get a smart pointer to a new ArrayPort.
  static std::shared_ptr<PortArray> Make(const std::string &name,
                                         const std::shared_ptr<Type> &type,
                                         std::shared_ptr<Node> size,
                                         Port::Dir dir = Port::Dir::IN,
                                         const std::shared_ptr<ClockDomain> &domain = default_domain());

  /// @brief Get a smart pointer to a new ArrayPort with a base type other than the default Port.
  static std::shared_ptr<PortArray> Make(const std::shared_ptr<Port> &base_node,
                                         std::shared_ptr<Node> size);

  /// @brief Make a copy of this port array
  std::shared_ptr<Object> Copy() const override;

 protected:
  /// @brief Construct a new port array.
  PortArray(const std::shared_ptr<Port> &base, std::shared_ptr<Node> size, Term::Dir dir);
};

}  // namespace cerata
