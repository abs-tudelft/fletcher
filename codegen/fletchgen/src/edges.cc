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

namespace fletchgen {

std::shared_ptr<Edge> Connect(std::shared_ptr<Node> dst, std::shared_ptr<Node> src) {
  // Check for potential errors
  if (src == nullptr) {
    throw std::runtime_error("Source node is null");
  }
  if (dst == nullptr) {
    throw std::runtime_error("Destination node is null");
  }
  if (src->type->id != dst->type->id) {
    throw std::runtime_error("Cannot connect nodes of different types.");
  }

  std::string edge_name = src->name() + "_to_" + dst->name();
  auto edge = Edge::Make(edge_name, dst, src);
  src->outs.push_back(edge);
  dst->ins.push_back(edge);
  return edge;
}

std::shared_ptr<Edge> operator<<=(const std::shared_ptr<Node> &lhs, const std::shared_ptr<Node> &rhs) {
  return Connect(lhs, rhs);
}

std::shared_ptr<Signal> insert(const std::shared_ptr<Edge> &edge, const std::string &name_prefix) {
  // Get the source type
  auto type = edge->src->type;

  // Create the signal
  auto signal = Signal::Make(name_prefix + edge->src->name(), type);

  // Make the new connections, effectively creating two new edges.
  signal <<= edge->src;
  edge->dst <<= signal;

  // Remove original edge from outs and ins of both ends
  remove(&edge->src->outs, edge);
  remove(&edge->dst->ins, edge);

  return signal;
}

std::shared_ptr<Edge> Edge::Make(std::string name, const std::shared_ptr<Node> &dst, const std::shared_ptr<Node> &src) {
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

int Edge::CountAllEdges(const std::shared_ptr<Node> &node) {
  return static_cast<int>(node->ins.size() + node->outs.size());
}

int Edge::GetIndexOf(const std::shared_ptr<Edge> &edge, const std::shared_ptr<Node> &node) {
  CheckEdgeOfNode(edge, node);
  auto siblings = edge->GetAllSiblings(node);
  auto it = std::find(std::begin(siblings), std::end(siblings), edge);
  return static_cast<int>(std::distance(std::begin(siblings), it));
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

std::deque<std::shared_ptr<Edge>> Edge::GetAllSiblings(const std::shared_ptr<Node> &node) {
  if (src == node) {
    return src->outs;
  } else {
    return dst->ins;
  }
}

int Edge::GetVectorOffsetOf(const std::shared_ptr<Edge> &edge, const std::shared_ptr<Node> &node) {
  CheckEdgeOfNode(edge, node);
  int offset = 0;
  // Iterate over the other siblings
  auto siblings = edge->GetAllSiblings(node);
  for (const auto &e : siblings) {
    // As long as we haven't reached this edge
    if (e != edge) {
      // Obtain the data type of the other end
      auto dt = e->dst->type;
      if (dt->Is(Type::STREAM)) {
        // If it's a stream, check if it has a vector as child
        auto stream = Cast<Stream>(dt);
        if (stream->element_type()->Is(Type::VECTOR)) {
          auto vec = Cast<Vector>(stream->element_type());
          if (vec->width()->IsLiteral()) {
            auto l = *Cast<Literal>(vec->width());
            if (l->val_storage_type == Literal::INT) {
              offset += l->int_val;
            } else {
              // not supported
            }
          } else if (vec->width()->IsParameter()) {
            auto p = Cast<Literal>(vec->width());
            // not supported
          }
        }
      } else if (dt->Is(Type::VECTOR)) {
        // If it's a vector
        auto vec = Cast<Vector>(dt);
        if (vec->width()->IsLiteral()) {
          auto l = *Cast<Literal>(vec->width());
          if (l->val_storage_type == Literal::INT) {
            offset += l->int_val;
          } else {
            // not supported
          }
        } else if (vec->width()->IsParameter()) {
          auto p = Cast<Literal>(vec->width());
          // not supported
        }
      }
    } else {
      break;
    }
  }
  return offset;
}
bool Edge::HasSiblings(const std::shared_ptr<Node> &node) {
  auto sib = GetAllSiblings(node);
  return sib.size() > 1;
}

}  // namespace fletchgen
