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

#include "cerata/edges.h"

#include <memory>
#include <deque>
#include <string>

#include "cerata/graphs.h"
#include "cerata/nodes.h"
#include "cerata/logging.h"

namespace cerata {

std::shared_ptr<Edge> Connect(const std::shared_ptr<Node>& dst, const std::shared_ptr<Node>& src) {
  // Check for potential errors
  if (src == nullptr) {
    CERATA_LOG(ERROR, "Source node is null");
    return nullptr;
  } else if (dst == nullptr) {
    CERATA_LOG(ERROR, "Destination node is null");
    return nullptr;
  }

  // Check if the types can be mapped onto each other
  if (!src->type()->GetMapper(dst->type().get())) {
    throw std::logic_error(
        "No known type mapping available for connection between node "
            + dst->ToString() + " (" + dst->type()->ToString() + ")  and ("
            + src->ToString() + " (" + src->type()->ToString() + ")");
  }

  // If the destination is a terminator
  if (dst->IsPort()) {
    auto t = *Cast<Term>(dst);
    // Check if it has a parent
    if (dst->parent()) {
      auto parent = *dst->parent();
      if (parent->IsInstance() && t->IsOutput()) {
        // If the parent is an instance, and the terminator node is an output, then we may not drive it.
        throw std::logic_error("Cannot drive instance port " + dst->ToString() + " of mode output.");
      } else if (parent->IsComponent() && t->IsInput()) {
        // If the parent is a component, and the terminator node is an input, then we may not drive it.
        throw std::logic_error("Cannot drive component port " + dst->ToString() + " of mode input.");
      }
    }
  }

  std::string edge_name = src->name() + "_to_" + dst->name();
  auto edge = Edge::Make(edge_name, dst, src);
  src->AddEdge(edge);
  dst->AddEdge(edge);
  return edge;
}

std::shared_ptr<Edge> operator<<=(const std::shared_ptr<Node> &dst, const std::shared_ptr<Node> &src) {
  return Connect(dst, src);
}

std::shared_ptr<Signal> insert(const std::shared_ptr<Edge> &edge, const std::string &name_prefix) {
  // Sanity checks
  if (!edge->src) {
    throw std::logic_error("Cannot insert Node on Edge, because it has no source Node.");
  }
  if (!edge->dst) {
    throw std::logic_error("Cannot insert Node on Edge, because it has no destination Node.");
  }

  auto src = *edge->src;
  auto dst = *edge->dst;

  // The signal to return
  std::shared_ptr<Signal> signal;

  // Get the destination type
  auto type = src->type();
  auto name = name_prefix + src->name();
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

}  // namespace cerata
