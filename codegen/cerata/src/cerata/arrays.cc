#include <utility>

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

#include "cerata/arrays.h"

#include <optional>
#include <utility>
#include <deque>
#include <memory>
#include <string>

#include "cerata/utils.h"
#include "cerata/edges.h"
#include "cerata/nodes.h"

namespace cerata {

std::shared_ptr<Node> IncrementNode(const std::shared_ptr<Node> &node) {
  if (node->IsLiteral() || node->IsExpression()) {
    return node + 1;
  } else if (node->IsParameter()) {
    // If the node is a parameter
    auto param = *Cast<Parameter>(node);
    if (param->value()) {
      // Recurse until we reach the literal
      param <<= IncrementNode(*param->value());
    } else {
      // Otherwise connect an integer literal of 1 to the parameter
      param <<= intl<1>();
    }
    return param;
  }
  throw std::runtime_error("Cannot increment node " + node->name() + " of type " + ToString(node->node_id()));
}

void NodeArray::SetSize(const std::shared_ptr<Node> &size) {
  if (size == nullptr) {
    throw std::runtime_error("Cannot set ArrayNode size to nullptr.");
  } else {
    size_ = size;
  }
}

void NodeArray::increment() {
  if (size_ != nullptr) {
    auto incremented = IncrementNode(size_);
    SetSize(incremented);
  } else {
    throw std::runtime_error("Invalid ArrayNode. Size is nullptr.");
  }
}

std::shared_ptr<Node> NodeArray::Append() {
  auto elem = *Cast<Node>(base_->Copy());
  if (parent()) {
    elem->SetParent(*parent());
  }
  elem->SetArray(this);
  nodes_.push_back(elem);
  increment();
  return elem;
}

std::shared_ptr<Node> NodeArray::node(size_t i) const {
  if (i < nodes_.size()) {
    return nodes_[i];
  } else {
    throw std::runtime_error("Index " + std::to_string(i) + " out of bounds for node " + ToString());
  }
}

std::shared_ptr<Object> NodeArray::Copy() const {
  auto ret = std::make_shared<NodeArray>(name(), node_id_, base_, *Cast<Node>(size()->Copy()));
  ret->SetParent(*parent());
  for (size_t i = 0; i < nodes_.size(); i++) {
    //ret->Append();
  }
  return ret;
}

void NodeArray::SetParent(const Graph *parent) {
  Object::SetParent(parent);
  base_->SetParent(parent);
  for (const auto &e : nodes_) {
    e->SetParent(parent);
  }
}

size_t NodeArray::IndexOf(const std::shared_ptr<Node> &n) const {
  for (size_t i = 0; i < nodes_.size(); i++) {
    if (nodes_[i] == n) {
      return i;
    }
  }
  throw std::logic_error("Node " + n->ToString() + " is not element of " + this->ToString());
}

PortArray::PortArray(std::string name, std::shared_ptr<Type> type, std::shared_ptr<Node> size, Term::Dir dir)
    : NodeArray(std::move(name), Node::PORT, Port::Make(name, std::move(type), dir), std::move(size)),
      Term(dir) {}

PortArray::PortArray(std::string name, std::shared_ptr<Port> base, std::shared_ptr<Node> size)
    : NodeArray(std::move(name), Node::PORT, base, std::move(size)),
      Term(base->dir()) {}

std::shared_ptr<PortArray> PortArray::Make(std::string name,
                                           std::shared_ptr<Type> type,
                                           std::shared_ptr<Node> size,
                                           Port::Dir dir) {
  return std::make_shared<PortArray>(name, type, size, dir);
}

std::shared_ptr<PortArray> PortArray::Make(std::shared_ptr<Type> type, std::shared_ptr<Node> size, Port::Dir dir) {
  return PortArray::Make(type->name(), type, std::move(size), dir);
}

std::shared_ptr<Object> PortArray::Copy() const {
  auto ret = std::make_shared<PortArray>(name(), type(), *Cast<Node>(size()->Copy()), dir());
  ret->SetParent(*parent());
  for (size_t i = 0; i < nodes_.size(); i++) {
    //ret->Append();
  }
  return ret;
}
std::shared_ptr<PortArray> PortArray::Make(const std::string &name,
                                           std::shared_ptr<Port> base,
                                           const std::shared_ptr<Node> &size) {
  return std::make_shared<PortArray>(name, std::move(base), size);
}

}  // namespace cerata
