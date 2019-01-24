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

#include <iostream>
#include <memory>
#include <algorithm>
#include <utility>

#include "./utils.h"
#include "./nodes.h"

namespace fletchgen {

/// @brief A directed edge between two nodes
struct Edge : public Named {
  /// @brief Destination node
  std::shared_ptr<Node> dst;
  /// @brief Source node
  std::shared_ptr<Node> src;

  /**
   * @brief Construct a new edge.
   * @param name    The name of the edge.
   * @param dst     The destination node.
   * @param src     The source node.
   */
  Edge(std::string name, std::shared_ptr<Node> dst, std::shared_ptr<Node> src)
      : Named(std::move(name)), dst(std::move(dst)), src(std::move(src)) {}

  /// @brief Shorthand to get a smart pointer to an edge.
  static std::shared_ptr<Edge> Make(std::string name,
                                    const std::shared_ptr<Node> &dst,
                                    const std::shared_ptr<Node> &src);

  /// @brief Get the node opposite to the other edge node.
  std::shared_ptr<Node> GetOtherNode(const std::shared_ptr<Node> &node);

  /// @brief Get all sibling nodes
  std::deque<std::shared_ptr<Edge>> GetAllSiblings(const std::shared_ptr<Node> &node);

  // @brief Return true if a node has any siblings, false otherwise.
  bool HasSiblings(const std::shared_ptr<Node> &node);

  /**
   * @brief Check if an edge is an edge on a node.
   * @param edge    The edge.
   * @param node    The node.
   */
  static void CheckEdgeOfNode(const std::shared_ptr<Edge> &edge, const std::shared_ptr<Node> &node);

  /// @brief Count the total number of edges of a specific node (ins and outs)
  static int CountAllEdges(const std::shared_ptr<Node> &node);

  /// @brief Get the index of an edge on some node.
  static int GetIndexOf(const std::shared_ptr<Edge> &edge, const std::shared_ptr<Node> &node);

  // TODO(johanpel): probably move this somewhere else:
  static int GetVectorOffsetOf(const std::shared_ptr<Edge> &edge, const std::shared_ptr<Node> &node);
};

/**
 * @brief Connect two nodes, returns the corresponding edge.
 * @param dst The destination node.
 * @param src The source node.
 * @return The edge connecting the nodes.
 */
std::shared_ptr<Edge> Connect(std::shared_ptr<Node> dst, std::shared_ptr<Node> src);

/// @brief Shorthand for Connect
std::shared_ptr<Edge> operator<<=(const std::shared_ptr<Node> &lhs, const std::shared_ptr<Node> &rhs);

}  // namespace fletchgen
