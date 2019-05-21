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

#include "cerata/nodes.h"
#include "cerata/edges.h"
#include "cerata/types.h"

namespace cerata {

std::shared_ptr<Node> IncrementNode(const std::shared_ptr<Node> &node);

class NodeArray : public Object {
 public:
  Node::NodeID node_id() { return node_id_; }

  /// @brief ArrayNode constructor.
  NodeArray(std::string name, Node::NodeID id, std::shared_ptr<Node> base, std::shared_ptr<Node> size)
      : Object(std::move(name), Object::ARRAY), node_id_(id), base_(std::move(base)), size_(std::move(size)) {
    base_->SetArray(this);
  }

  void SetParent(const Graph *parent) override;

  inline std::shared_ptr<Node> size() const { return size_; }
  void SetSize(const std::shared_ptr<Node> &size);

  std::shared_ptr<Type> type() const { return base_->type(); }

  std::shared_ptr<Object> Copy() const override;

  /// @brief Append a node to this array. Returns a pointer to that node.
  std::shared_ptr<Node> Append();
  /// @brief Return all nodes of this NodeArray.
  std::deque<std::shared_ptr<Node>> nodes() const { return nodes_; };
  /// @brief Return element node i.
  std::shared_ptr<Node> node(size_t i) const;
  /// @brief Return element node i.
  std::shared_ptr<Node> operator[](size_t i) const { return node(i); }
  /// @brief Return the number of element nodes.
  size_t num_nodes() const { return nodes_.size(); }
  /// @brief Return the index of a specific node.
  size_t IndexOf(const std::shared_ptr<Node> &n) const;

  std::string ToString() const { return name(); }

  std::shared_ptr<Node> base() { return base_; }

 protected:
  Node::NodeID node_id_;
  /// @brief Increment the size of the ArrayNode.
  void increment();
  /// A node representing the template for each of the element nodes.
  std::shared_ptr<Node> base_;
  /// A node representing the number of concatenated edges.
  std::shared_ptr<Node> size_;
  /// The nodes contained by this array
  std::deque<std::shared_ptr<Node>> nodes_;
};

/**
 * @brief An array of port nodes
 */
class PortArray : public NodeArray, public Term {
 public:
  PortArray(std::string name, std::shared_ptr<Type> type, std::shared_ptr<Node> size, Term::Dir dir);
  PortArray(std::string name, std::shared_ptr<Port> base, std::shared_ptr<Node> size);

  /// @brief Get a smart pointer to a new ArrayPort.
  static std::shared_ptr<PortArray> Make(std::string name,
                                         std::shared_ptr<Type> type,
                                         std::shared_ptr<Node> size,
                                         Port::Dir dir = Port::Dir::IN);
  /// @brief Get a smart pointer to a new ArrayPort. The ArrayPort name is derived from the Base name.
  static std::shared_ptr<PortArray> Make(std::shared_ptr<Type> type,
                                         std::shared_ptr<Node> size,
                                         Port::Dir dir = Port::Dir::IN);

  /// @brief Get a smart pointer to a new ArrayPort with a base type other than the default Port.
  static std::shared_ptr<PortArray> Make(const std::string& name,
                                         std::shared_ptr<Port> base,
                                         const std::shared_ptr<Node>& size);

  /// @brief Make a copy of this port array
  std::shared_ptr<Object> Copy() const override;
};

}