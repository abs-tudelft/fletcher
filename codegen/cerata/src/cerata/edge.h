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

#include <algorithm>
#include <iostream>
#include <utility>
#include <memory>
#include <string>
#include <deque>

#include "cerata/utils.h"
#include "cerata/node.h"

namespace cerata {

/// @brief A directed edge between two nodes.
class Edge : public Named {
 public:
  /// @brief Shorthand to get a smart pointer to an edge.
  static std::shared_ptr<Edge> Make(const std::string &name, Node *dst, Node *src);

  /// @brief Get the node opposite to the other edge node.
  std::optional<Node *> GetOtherNode(const Node &node) const;

  /// @brief Return the destination node.
  Node *dst() const { return dst_; }
  /// @brief Return the source node.
  Node *src() const { return src_; }

 protected:
  /**
   * @brief Construct a new edge.
   * @param name    The name of the edge.
   * @param dst     The destination node.
   * @param src     The source node.
  */
  Edge(std::string name, Node *dst, Node *src);

  /// @brief Destination node
  Node *dst_;
  /// @brief Source node
  Node *src_;
};

/**
 * @brief Connect two nodes, returns the corresponding edge.
 * @param dst The destination node.
 * @param src The source node.
 * @return The edge connecting the nodes.
 */
std::shared_ptr<Edge> Connect(Node *dst, Node *src);

// Connect operators:
/// @brief Create an edge, connecting the src node to the dst node.
std::shared_ptr<Edge> operator<<=(Node *dst, const std::shared_ptr<Node> &src);
/// @brief Create an edge, connecting the src node to the dst node.
std::shared_ptr<Edge> operator<<=(const std::weak_ptr<Node> &dst, Node *src);
/// @brief Create an edge, connecting the src node to the dst node.
std::shared_ptr<Edge> operator<<=(const std::weak_ptr<Node> &dst, const std::weak_ptr<Node> &src);
/// @brief Create an edge, connecting the src node to the dst node.
std::shared_ptr<Edge> operator<<=(const std::weak_ptr<Node> &dst, const std::shared_ptr<Node> &src);
/// @brief Create an edge, connecting the src node to the dst node.
std::shared_ptr<Edge> operator<<=(const std::shared_ptr<Node> &dst, const std::shared_ptr<Node> &src);

/// @brief Split an edge up to create two new edges with a signal node in the middle. Returns the new signal.
std::shared_ptr<Signal> insert(Edge *edge,
                               const std::string &name_prefix = "int_",
                               std::optional<Graph *> new_owner = std::nullopt);

/// @brief Obtain all edges in a graph.
std::deque<Edge *> GetAllEdges(const Graph &graph);

}  // namespace cerata
