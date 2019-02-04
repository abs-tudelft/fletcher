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

#include "./edges.h"

#include <memory>
#include <deque>
#include <string>

namespace fletchgen {

std::shared_ptr<Edge> Connect(std::shared_ptr<Node> dst, std::shared_ptr<Node> src) {
  // Check for potential errors
  if (src == nullptr) {
    throw std::runtime_error("Source node is null");
  }
  if (dst == nullptr) {
    throw std::runtime_error("Destination node is null");
  }
  if (dst->input()) {
    throw std::runtime_error("Node " + dst->name() + " cannot have multiple edges.");
  }
  if (!WeaklyEqual(src->type(), dst->type())) {
    std::cerr << "source: " << std::endl << ToString(Flatten(src->type())) << std::endl;
    std::cerr << "destination: " << std::endl << ToString(Flatten(dst->type())) << std::endl;
    throw std::runtime_error("Cannot connect nodes of weakly different types.");
  }

  std::string edge_name = src->name() + "_to_" + dst->name();
  auto edge = Edge::Make(edge_name, dst, src);
  src->AddOutput(edge);
  dst->SetInput(edge);
  return edge;
}

std::shared_ptr<Edge> operator<<=(const std::shared_ptr<Node> &lhs, const std::shared_ptr<Node> &rhs) {
  return Connect(lhs, rhs);
}

std::shared_ptr<Signal> insert(const std::shared_ptr<Edge> &edge, const std::string &name_prefix) {
  // Sanity checks
  if (!edge->src) {
    throw std::runtime_error("Cannot insert Node on Edge, because it has no source Node.");
  }
  if (!edge->dst) {
    throw std::runtime_error("Cannot insert Node on Edge, because it has no destination Node.");
  }

  auto src = *edge->src;
  auto dst = *edge->dst;

  // The signal to return
  std::shared_ptr<Signal> signal;

  // Get the destination type
  auto type = dst->type();
  auto name = name_prefix + dst->name();
  // Create the signal
  signal = Signal::Make(name, type);
  // Remove the original edge from the source and destination node
  src->RemoveEdge(edge);
  dst->RemoveEdge(edge);
  // Make the new connections, effectively creating two new edges.
  signal <<= src;
  dst <<= signal;
  // Return the new signal
  return signal;
}

std::shared_ptr<Edge> Edge::Make(std::string name,
                                 const std::shared_ptr<Node> &dst,
                                 const std::shared_ptr<Node> &src) {
  return std::make_shared<Edge>(name, dst, src);
}

std::shared_ptr<Node> Edge::GetOtherNode(const std::shared_ptr<Node> &node) {
  if (IsComplete()) {
    if (*src == node) {
      return *dst;
    } else {
      return *src;
    }
  } else {
    throw std::runtime_error("Could not obtain other node of edge: " + name() + ". Edge is not complete.");
  }
}

void Edge::CheckEdgeOfNode(const std::shared_ptr<Edge> &edge, const std::shared_ptr<Node> &node) {
  if (edge == nullptr) {
    throw std::runtime_error("CheckEdgeOfNode: Edge is null.");
  }
  if (node == nullptr) {
    throw std::runtime_error("Node: Node is null.");
  }
  if (!(edge->src == node) && !(edge->dst == node)) {
    throw std::runtime_error("Edge " + edge->name() + "is not connected to node " + node->name());
  }
}

}  // namespace fletchgen
