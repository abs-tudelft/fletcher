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

#include "cerata/node.h"

#include <optional>
#include <utility>
#include <vector>
#include <memory>
#include <string>

#include "cerata/utils.h"
#include "cerata/edge.h"
#include "cerata/pool.h"
#include "cerata/graph.h"
#include "cerata/expression.h"
#include "cerata/parameter.h"

namespace cerata {

Node::Node(std::string name, Node::NodeID id, std::shared_ptr<Type> type)
    : Object(std::move(name), Object::NODE), node_id_(id), type_(std::move(type)) {}

std::string Node::ToString() const {
  return name();
}

void ImplicitlyRebindNodes(Graph *dst, const std::vector<Node *> &nodes, NodeMap *rebinding) {
  for (const auto &n : nodes) {
    if (rebinding->count(n) > 0) {
      // If it's already in the map, skip it.
      continue;
    } else if (dst->Has(n->name())) {
      // If it already has a node with that name, select that one for rebinding. This is the implicit part.
      (*rebinding)[n] = dst->Get<Node>(n->name());
    } else if (!n->IsLiteral()) {
      // We skip literals. Any other nodes we copy onto the destination graph.
      n->CopyOnto(dst, n->name(), rebinding);
    }
  }
}

Node *Node::CopyOnto(Graph *dst, const std::string &name, NodeMap *rebinding) const {
  // Make a normal copy (that does not rebind the type generics).
  auto result = std::dynamic_pointer_cast<Node>(this->Copy());
  result->SetName(name);
  // Default node only has a type in which other nodes could be referenced through the type's generics.
  auto generics = this->type()->GetGenerics();
  // If it has any generics, we might need to rebind them.
  if (!generics.empty()) {
    // Resolve the rebinding.
    ImplicitlyRebindNodes(dst, generics, rebinding);
    // Make a copy of the type, rebinding the generic nodes.
    auto rebound_type = result->type()->Copy(*rebinding);
    // Set the type of the new node to this new type.
    result->SetType(rebound_type);
  }
  // Append this node to the rebind map.
  (*rebinding)[this] = result.get();
  // It is now possible to add the copy onto the graph.
  dst->Add(result);
  return result.get();
}

Node *Node::Replace(Node *replacement) {
  // Iterate over all sourcing edges of the original node.
  for (const auto &e : this->sources()) {
    auto src = e->src();
    src->RemoveEdge(e);
    this->RemoveEdge(e);
    Connect(replacement, src);
  }
  // Iterate over all sinking edges of the original node.
  for (const auto &e : this->sinks()) {
    auto dst = e->src();
    dst->RemoveEdge(e);
    this->RemoveEdge(e);
    Connect(dst, replacement);
  }
  // Remove the node from its parent, if it has one.
  if (this->parent()) {
    this->parent().value()->Remove(this);
    this->parent().value()->Add(this->shared_from_this());
  }
  // Set array size node, if this is one.
  if (this->IsParameter()) {
    auto param = this->AsParameter();
    if (param->node_array_parent) {
      param->node_array_parent.value()->SetSize(replacement->shared_from_this());
    }
  }
  return replacement;
}

std::vector<Edge *> Node::edges() const {
  auto snk = sinks();
  auto src = sources();
  std::vector<Edge *> edges;
  edges.insert(edges.end(), snk.begin(), snk.end());
  edges.insert(edges.end(), src.begin(), src.end());
  return edges;
}

Node *Node::SetType(const std::shared_ptr<Type> &type) {
  type_ = type;
  return this;
}

void Node::AppendReferences(std::vector<Object *> *out) const {
  for (const auto &g : type()->GetGenerics()) {
    out->push_back(g);
    // A type generic may refer to objects itself, append that as well.
    g->AppendReferences(out);
  }
}

// Generate node casting convenience functions.
#ifndef NODE_CAST_IMPL_FACTORY
#define NODE_CAST_IMPL_FACTORY(NODENAME)                                                        \
NODENAME * Node::As##NODENAME() { auto result = dynamic_cast<NODENAME*>(this);                  \
  if (result != nullptr) {                                                                      \
    return result;                                                                              \
  } else {                                                                                      \
    CERATA_LOG(FATAL, "Node is not " + std::string(#NODENAME));                                 \
}}                                                                                              \
const NODENAME* Node::As##NODENAME() const { auto result = dynamic_cast<const NODENAME*>(this); \
  if (result != nullptr) {                                                                      \
    return result;                                                                              \
  } else {                                                                                      \
    CERATA_LOG(FATAL, "Node is not " + std::string(#NODENAME));                                 \
  }                                                                                             \
}
#endif

NODE_CAST_IMPL_FACTORY(Port)
NODE_CAST_IMPL_FACTORY(Signal)
NODE_CAST_IMPL_FACTORY(Parameter)
NODE_CAST_IMPL_FACTORY(Literal)
NODE_CAST_IMPL_FACTORY(Expression)

#ifndef TYPE_STRINGIFICATION_FACTORY
#define TYPE_STRINGIFICATION_FACTORY(NODE_TYPE)             \
  template<>                                                \
  std::string ToString<NODE_TYPE>() { return #NODE_TYPE; }
#endif
TYPE_STRINGIFICATION_FACTORY(Port)
TYPE_STRINGIFICATION_FACTORY(Signal)
TYPE_STRINGIFICATION_FACTORY(Literal)
TYPE_STRINGIFICATION_FACTORY(Parameter)
TYPE_STRINGIFICATION_FACTORY(Expression)

bool MultiOutputNode::AddEdge(const std::shared_ptr<Edge> &edge) {
  bool success = false;
  // Check if the source is this node
  if (edge->src() == this) {
    // Check if this node does not already contain this edge
    if (!Contains(outputs_, edge)) {
      // Add the edge to this node
      outputs_.push_back(edge);
      success = true;
    }
  }
  return success;
}

bool MultiOutputNode::RemoveEdge(Edge *edge) {
  if (edge->src() == this) {
    // This node sources the edge.
    for (auto i = outputs_.begin(); i < outputs_.end(); i++) {
      if (i->get() == edge) {
        outputs_.erase(i);
        return true;
      }
    }
  }
  return false;
}

std::optional<Edge *> NormalNode::input() const {
  if (input_ != nullptr) {
    return input_.get();
  }
  return {};
}

std::vector<Edge *> NormalNode::sources() const {
  if (input_ != nullptr) {
    return {input_.get()};
  } else {
    return {};
  }
}

bool NormalNode::AddEdge(const std::shared_ptr<Edge> &edge) {
  // first attempt to add the edge as an output.
  bool success = MultiOutputNode::AddEdge(edge);
  // If we couldn't add the edge as output, it must be input.
  if (!success) {
    // Check if the edge has a destination.
    if (edge->dst()) {
      // Check if this is the destination.
      if (edge->dst() == this) {
        // Set this node source to the edge.
        input_ = edge;
        success = true;
      }
    }
  }
  return success;
}

bool NormalNode::RemoveEdge(Edge *edge) {
  // First remove the edge from any outputs
  bool success = MultiOutputNode::RemoveEdge(edge);
  // Check if the edge is an input to this node
  if ((edge->dst() != nullptr) && !success) {
    if ((edge->dst() == this) && (input_.get() == edge)) {
      input_.reset();
      success = true;
    }
  }
  return success;
}

std::string ToString(Node::NodeID id) {
  switch (id) {
    case Node::NodeID::PORT:return "Port";
    case Node::NodeID::SIGNAL:return "Signal";
    case Node::NodeID::LITERAL:return "Literal";
    case Node::NodeID::PARAMETER:return "Parameter";
    case Node::NodeID::EXPRESSION:return "Expression";
  }
  throw std::runtime_error("Corrupted node type.");
}

void GetObjectReferences(const Object &obj, std::vector<Object *> *out) {
  if (obj.IsNode()) {
    // If the object is a node, its type may be a generic type.
    auto &node = dynamic_cast<const Node &>(obj);
    // Obtain any potential type generic nodes.
    auto params = node.type()->GetGenerics();
    for (const auto &p : params) {
      out->push_back(p);
    }
    // If the node is an expression, we need to grab every object from the tree.

  } else if (obj.IsArray()) {
    // If the object is an array, we can obtain the generic nodes from the base type.
    auto &array = dynamic_cast<const NodeArray &>(obj);
    // Add the type generic nodes of the base node first.
    GetObjectReferences(*array.base(), out);
    // An array has a size node. Add that as well.
    out->push_back(array.size());
  }
}

}  // namespace cerata
