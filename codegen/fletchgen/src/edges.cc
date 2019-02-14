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
  } else if (dst == nullptr) {
    throw std::runtime_error("Destination node is null");
  }

  // Check if the types can be mapped onto each other
  if (!src->type()->GetMapper(dst->type().get())) {
    throw std::runtime_error(
        "No known type mapping available during connection of node "
            + src->ToString() + " (" + src->type()->ToString() + ")  to ("
            + src->ToString() + " (" + src->type()->ToString() + ")");
  }

  // If the destination is a port, check if we're not driving an output port
  if (dst->IsPort()) {
    auto p = *Cast<Port>(dst);
    if (p->IsOutput()) {
      throw std::runtime_error("Cannot drive port " + p->ToString() + " of mode output");
    }
  }

  // Defer to ArrayNodes if applicable
  if (src->IsArray()) {
    auto sa = *Cast<ArrayNode>(src);
    return sa->Append(dst);
  } else if (dst->IsArray()) {
    auto da = *Cast<ArrayNode>(dst);
    return da->Append(src);
  }

  std::string edge_name = src->name() + "_to_" + dst->name();
  auto edge = Edge::Make(edge_name, dst, src);
  src->AddOutput(edge);
  dst->AddInput(edge);
  return edge;
}

std::shared_ptr<Edge> operator<<=(const std::shared_ptr<Node> &dst, const std::shared_ptr<Node> &src) {
  return Connect(dst, src);
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
