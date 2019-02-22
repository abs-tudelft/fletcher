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

class ArrayNode : public Node {
 public:
  /// @brief ArrayNode constructor.
  ArrayNode(std::string name, Node::ID id, std::shared_ptr<Type> type) : Node(std::move(name), id, std::move(type)) {}
  /// @brief Append the ArrayNode with a new source.
  std::shared_ptr<Edge> AddSource(const std::shared_ptr<Node> &source) override;
  /// @brief Append the ArrayNode with a new sink.
  std::shared_ptr<Edge> AddSink(const std::shared_ptr<Node> &sink) override;

  /// @brief Add an edge to this node.
  bool AddEdge(const std::shared_ptr<Edge>& edge) override;
  /// @brief Remove an edge of this node.
  bool RemoveEdge(const std::shared_ptr<Edge> &edge) override;

  /// @brief Return the Edge to the Node representing the number of edges on the array side of this ArrayNode.
  inline std::shared_ptr<Edge> size_edge() const { return size_; }
  /// @brief Return the Node representing the number of edges on the array side of this ArrayNode.
  inline std::shared_ptr<Node> size() const { return *size_->src; }
  /// @brief Set the array size of this ArrayNode. The size Node must appear as a node on the parent Graph.
  void SetSize(const std::shared_ptr<Node> &size);

  /// @brief Return all incoming edges of this node.
  std::deque<std::shared_ptr<Edge>> sources() const override;
  /// @brief Return all outgoing edges of this node.
  std::deque<std::shared_ptr<Edge>> sinks() const override;

  /// @brief Return array node i.
  std::shared_ptr<Node> operator[](size_t i);

 private:
  /// @brief Increment the size of the ArrayNode.
  void increment();
  /// A node representing the number of concatenated edges.
  std::shared_ptr<Edge> size_;
  /// The nodes contained by this array
  std::deque<std::shared_ptr<Node>> nodes_;
};

/**
 * @brief A port node that has an array of multiple edges to other nodes.
 */
struct ArrayPort : public ArrayNode, public Term {
  /// @brief Construct a new ArrayPort.
  ArrayPort(std::string name, std::shared_ptr<Type> type, Port::Dir dir);

  /// @brief Get a smart pointer to a new ArrayPort.
  static std::shared_ptr<ArrayPort> Make(std::string name,
                                         std::shared_ptr<Type> type,
                                         std::shared_ptr<Node> size,
                                         Port::Dir dir = Port::Dir::IN);
  /// @brief Get a smart pointer to a new ArrayPort. The ArrayPort name is derived from the Type name.
  static std::shared_ptr<ArrayPort> Make(std::shared_ptr<Type> type,
                                         std::shared_ptr<Node> size,
                                         Port::Dir dir = Port::Dir::IN);

  /// @brief Create a copy of this ArrayPort.
  std::shared_ptr<Node> Copy() const override;
};

}