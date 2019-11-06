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

#include <algorithm>
#include <iostream>
#include <utility>
#include <memory>
#include <string>
#include <vector>

#include "cerata/utils.h"
#include "cerata/node.h"
#include "cerata/array.h"
#include "cerata/pool.h"

namespace cerata {

// Forward decl.
class Component;

/// @brief A directed edge between two nodes.
class Edge : public Named {
 public:
  /// @brief Shorthand to get a smart pointer to an edge.
  static std::shared_ptr<Edge> Make(const std::string &name, Node *dst, Node *src);

  /// @brief Get the node opposite to the other edge node.
  [[nodiscard]] std::optional<Node *> GetOtherNode(const Node &node) const;

  /// @brief Return the destination node.
  [[nodiscard]] Node *dst() const { return dst_; }
  /// @brief Return the source node.
  [[nodiscard]] Node *src() const { return src_; }

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

/**
 * @brief Connect two nodes, returns the corresponding edge.
 * @param dst The destination node.
 * @param src The source node.
 * @return The edge connecting the nodes.
 */
std::shared_ptr<Edge> Connect(Node *dst, const std::shared_ptr<Node> &src);

/**
 * @brief Connect two nodes, returns the corresponding edge.
 * @param dst The destination node.
 * @param src The source node.
 * @return The edge connecting the nodes.
 */
std::shared_ptr<Edge> Connect(const std::shared_ptr<Node> &dst, Node *src);

/**
 * @brief Connect two nodes, returns the corresponding edge.
 * @param dst The destination node.
 * @param src The source node.
 * @return The edge connecting the nodes.
 */
std::shared_ptr<Edge> Connect(const std::shared_ptr<Node> &dst, const std::shared_ptr<Node> &src);

/**
 * @brief Connect a string literal to another node.
 * @param dst The destination node.
 * @param str A string out of which a string literal node will be created..
 * @return The edge connecting the nodes.
 */
std::shared_ptr<Edge> Connect(Node *dst, std::string str);

// Connect operators:

/// @brief Create an edge, connecting the src node to the dst node.
std::shared_ptr<Edge> operator<<=(Node *dst, const std::shared_ptr<Node> &src);
/// @brief Create an edge, connecting the src node to the dst node.
std::shared_ptr<Edge> operator<<=(const std::shared_ptr<Node> &dst, const std::shared_ptr<Node> &src);
/// @brief Create an edge, connecting the src node to the dst node.
std::shared_ptr<Edge> operator<<=(const std::shared_ptr<Node> &dst, Node *src);

/// @brief Obtain all edges in a graph.
std::vector<Edge *> GetAllEdges(const Graph &graph);

/**
 * @brief Attach a Signal to a Node, redirecting all edges through the new Signal.
 * @param comp        The component to add and own the Signal.
 * @param node        The Node to attach the Signal to.
 * @param rebinding   A pointer to a NodeMap to which all rebound Nodes will be appended.
 * @param name        A name for the new Signal.
 * @return            A pointer to the new Signal.
 */
Signal *AttachSignalToNode(Component *comp, NormalNode *node, NodeMap *rebinding, std::string name = "");

/**
 * @brief Attach a SignalArray to a Node, redirecting all edges through the new SignalArray.
 * @param comp        The component to add and own the SignalArray.
 * @param array       The NodeArray to attach the SignalArray to.
 * @param rebinding   A pointer to a NodeMap to which all rebound Nodes will be appended.
 * @return            A pointer to the new SignalArray.
 */
SignalArray *AttachSignalArrayToNodeArray(Component *comp, NodeArray *array, NodeMap *rebinding);

}  // namespace cerata
