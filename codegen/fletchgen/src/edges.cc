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
  if (src->type()->id() != dst->type()->id()) {
    throw std::runtime_error("Cannot connect nodes of different types.");
    // TODO(johanpel): more elaborate compatibility checking goes here
  }

  std::string edge_name = src->name() + "_to_" + dst->name();
  auto edge = Edge::Make(edge_name, dst, src);
  src->AddOutput(edge);
  dst->AddInput(edge);
  return edge;
}

std::shared_ptr<Edge> operator<<=(const std::shared_ptr<Node> &lhs, const std::shared_ptr<Node> &rhs) {
  return Connect(lhs, rhs);
}

std::shared_ptr<Signal> insert(const std::shared_ptr<Edge> &edge, const std::string &name_prefix) {
  auto src = edge->src;
  auto dst = edge->dst;

  // The signal to return
  std::shared_ptr<Signal> signal;

  if ((src->num_outs() == 1) && (dst->num_ins() == 1)) {  // One source to one destination
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
  } else if ((src->num_outs() > 1) && (dst->num_ins() == 1)) {  // Multiple sources to one destination
    // Get the source type and create a new signal based on this type.
    auto type = src->type();
    auto name = name_prefix + src->name();
    signal = Signal::Make(name, type);
    // Iterate over all sibling edges
    for (auto &sib : src->outs()) {
      // Drive the original destination node with the signal.
      sib->dst <<= signal;
      // Remove the original edge from source & from the destination node.
      src->RemoveEdge(sib);
      sib->dst->RemoveEdge(sib);
    }
    // Drive the signal with the original source
    signal <<= src;
  } else if ((src->num_outs() == 1) && (dst->num_ins() > 1)) {  // One source to multiple destinations
    // Get the source type and create a new signal based on this type.
    auto type = dst->type();
    auto name = name_prefix + dst->name();
    signal = Signal::Make(name, type);
    // Iterate over all sibling edges
    for (auto &sib : dst->ins()) {
      // Drive the signal with the original source
      signal <<= sib->src;
      // Remove the original outgoing edge & the original incoming edge
      sib->src->RemoveEdge(sib);
      dst->RemoveEdge(sib);
    }
    // Drive the destination with the new signal
    dst <<= signal;
  } else {
    if ((src->num_outs() == 0) || (dst->num_ins() == 0)) {
      throw std::runtime_error("Encountered edge where source or destination has 0 outgoing or incoming edges.");
    } else {
      throw std::runtime_error("Encountered edge with double-sided concatenation. Design is corrupt.");
    }
  }
  // Return the new signal
  return signal;
}

std::shared_ptr<Edge> Edge::Make(std::string name,
                                 const std::shared_ptr<Node> &dst,
                                 const std::shared_ptr<Node> &src) {
  return std::make_shared<Edge>(name, dst, src);
}

std::shared_ptr<Node> Edge::GetOtherNode(const std::shared_ptr<Node> &node) {
  if (src == node) {
    return dst;
  } else if (dst == node) {
    return src;
  } else {
    throw std::runtime_error("Could not obtain other node of edge: " + name());
  }
}

size_t Edge::GetIndexOf(const std::shared_ptr<Edge> &edge, const std::shared_ptr<Node> &node) {
  CheckEdgeOfNode(edge, node);
  auto siblings = edge->GetAllSiblings(node);
  auto it = std::find(std::begin(siblings), std::end(siblings), edge);
  return static_cast<size_t>(std::distance(std::begin(siblings), it));
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

std::deque<std::shared_ptr<Edge>> Edge::GetAllSiblings(const std::shared_ptr<Node> &node) const {
  if (src == node) {
    return src->outs();
  } else {
    return dst->ins();
  }
}

size_t Edge::num_siblings(const std::shared_ptr<Node> &node) const {
  if (src == node) {
    return src->num_outs();
  } else if (dst == node) {
    return dst->num_ins();
  } else {
    throw std::runtime_error("Node " + node->name() + " does not belong to Edge " + name());
  }
}

bool Edge::HasSiblings(const std::shared_ptr<Node> &node) const {
  return num_siblings(node) > 1;
}

}  // namespace fletchgen
