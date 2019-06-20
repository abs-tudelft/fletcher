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

#include "cerata/node_array.h"

#include <optional>
#include <utility>
#include <deque>
#include <memory>
#include <string>

#include "cerata/utils.h"
#include "cerata/edge.h"
#include "cerata/node.h"
#include "cerata/pool.h"
#include "cerata/expression.h"

namespace cerata {

static std::shared_ptr<Node> IncrementNode(const Node& node) {
  if (node.IsLiteral() || node.IsExpression()) {
    return node.shared_from_this() + 1;
  } else if (node.IsParameter()) {
    // If the node is a parameter
    auto param = dynamic_cast<const Parameter&>(node);
    std::shared_ptr<Node> new_param = std::dynamic_pointer_cast<Node>(param.Copy());
    if (param.val()) {
      // Recurse until we reach the literal
      new_param <<= IncrementNode(**param.val());
    } else {
      // Otherwise connect an integer literal of 1 to the parameter
      new_param <<= intl(1);
    }
    return new_param;
  }
  throw std::runtime_error("Cannot increment node " + node.name() + " of type " + ToString(node.node_id()));
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
    SetSize(IncrementNode(*size_));
  } else {
    throw std::runtime_error("Invalid ArrayNode. Size is nullptr.");
  }
}

Node* NodeArray::Append() {
  auto elem = std::dynamic_pointer_cast<Node>(base_->Copy());
  if (parent()) {
    elem->SetParent(*parent());
  }
  elem->SetArray(this);
  nodes_.push_back(elem);
  increment();
  return elem.get();
}

Node* NodeArray::node(size_t i) const {
  if (i < nodes_.size()) {
    return nodes_[i].get();
  } else {
    throw std::runtime_error("Index " + std::to_string(i) + " out of bounds for node " + ToString());
  }
}

std::shared_ptr<Object> NodeArray::Copy() const {
  auto p = parent();
  auto ret = std::make_shared<NodeArray>(name(), node_id_, base_, *Cast<Node>(size()->Copy()));
  if (p) {
    ret->SetParent(*p);
  }
  for (size_t i = 0; i < nodes_.size(); i++) {
    //ret->Append();
  }
  return ret;
}

void NodeArray::SetParent(Graph *parent) {
  Object::SetParent(parent);
  base_->SetParent(parent);
  for (const auto &e : nodes_) {
    e->SetParent(parent);
  }
}

size_t NodeArray::IndexOf(const Node &n) const {
  for (size_t i = 0; i < nodes_.size(); i++) {
    if (nodes_[i].get() == &n) {
      return i;
    }
  }
  throw std::logic_error("Node " + n.ToString() + " is not element of " + this->ToString());
}

PortArray::PortArray(std::string name, std::shared_ptr<Type> type, std::shared_ptr<Node> size, Term::Dir dir)
    : NodeArray(std::move(name), Node::NodeID::PORT, Port::Make(name, std::move(type), dir), std::move(size)),
      Term(dir) {}

PortArray::PortArray(std::string name, const std::shared_ptr<Port>& base, std::shared_ptr<Node> size)
    : NodeArray(std::move(name), Node::NodeID::PORT, base, std::move(size)),
      Term(base->dir()) {}

std::shared_ptr<PortArray> PortArray::Make(std::string name,
                                           std::shared_ptr<Type> type,
                                           std::shared_ptr<Node> size,
                                           Port::Dir dir) {
  return std::make_shared<PortArray>(name, type, size, dir);
}

std::shared_ptr<PortArray> PortArray::Make(const std::shared_ptr<Type>& type, std::shared_ptr<Node> size, Port::Dir dir) {
  return PortArray::Make(type->name(), type, std::move(size), dir);
}

std::shared_ptr<Object> PortArray::Copy() const {
  // Take shared ownership of the type.
  auto typ = type()->shared_from_this();
  // Make a copy of the size node.
  auto siz = std::dynamic_pointer_cast<Node>(size()->Copy());
  // Create the new PortArray using the new nodes.
  auto ret = std::make_shared<PortArray>(name(), typ, siz, dir());
  // Use the same parent if there is a parent.
  if (parent()) {
    ret->SetParent(*parent());
  }
  return ret;
}
std::shared_ptr<PortArray> PortArray::Make(const std::string &name,
                                           std::shared_ptr<Port> base,
                                           const std::shared_ptr<Node> &size) {
  return std::make_shared<PortArray>(name, std::move(base), size);
}

}  // namespace cerata
