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
#include "cerata/nodes.h"

namespace cerata {

/// @brief A directed edge between two nodes
struct Edge : public Named {
  /// @brief Destination node
  std::optional<std::shared_ptr<Node>> dst;
  /// @brief Source node
  std::optional<std::shared_ptr<Node>> src;
  /// @brief Return true if edge has both source and destination, false otherwise.
  inline bool IsComplete() { return dst && src; }

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

  /**
   * @brief Check if an edge is an edge on a node.
   * @param edge    The edge.
   * @param node    The node.
   */
  static void CheckEdgeOfNode(const std::shared_ptr<Edge> &edge, const std::shared_ptr<Node> &node);
};

/**
 * @brief Connect two nodes, returns the corresponding edge.
 * @param dst The destination node.
 * @param src The source node.
 * @return The edge connecting the nodes.
 */
std::shared_ptr<Edge> Connect(const std::shared_ptr<Node>& dst, const std::shared_ptr<Node>& src);

/// @brief Shorthand for Connect
std::shared_ptr<Edge> operator<<=(const std::shared_ptr<Node> &dst, const std::shared_ptr<Node> &src);

/// @brief Split an edge up to create two new edges with a signal node in the middle. Returns the new signal.
std::shared_ptr<Signal> insert(const std::shared_ptr<Edge> &edge, const std::string &name_prefix = "int_");

}  // namespace cerata
