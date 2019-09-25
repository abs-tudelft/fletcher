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
#include "cerata/graph.h"

namespace cerata {

static std::shared_ptr<Node> IncrementNode(const Node &node) {
  if (node.IsLiteral() || node.IsExpression()) {
    return node + 1;
  } else if (node.IsParameter()) {
    // If the node is a parameter.
    auto &param = dynamic_cast<const Parameter &>(node);
    // Make a copy of the parameter.
    std::shared_ptr<Node> new_param = std::dynamic_pointer_cast<Node>(param.Copy());
    // Figure out who should own the copy.
    if (param.parent()) {
      param.parent().value()->AddObject(new_param);
    } else {
      // If theres no parent, place it in the default node pool.
      // TODO(johanpel): this is a bit ugly.
      default_node_pool()->Add(new_param);
    }
    if (param.GetValue()) {
      auto param_value = param.GetValue().value();
      // Recurse until we reach the literal.
      new_param <<= IncrementNode(*param_value);
    } else {
      // Otherwise connect an integer literal of 1 to the parameter.
      new_param <<= intl(1);
    }
    return new_param;
  } else {
    CERATA_LOG(FATAL, "Cannot increment node " + node.name() + " of type " + ToString(node.node_id()));
  }
}

void NodeArray::SetSize(const std::shared_ptr<Node> &size) {
  if (size == nullptr) {
    throw std::runtime_error("Cannot set ArrayNode size to nullptr.");
  } else {
    size_ = size;
  }
}

void NodeArray::IncrementSize() {
  if (size_ != nullptr) {
    if (parent_) {
      parent_.value()->RemoveObject(size_.get());
    }
    auto new_size = IncrementNode(*size_);
    SetSize(new_size);
  } else {
    throw std::runtime_error("Corrupted NodeArray. Size is nullptr.");
  }
}

Node *NodeArray::Append(bool increment_size) {
  auto elem = std::dynamic_pointer_cast<Node>(base_->Copy());
  if (parent()) {
    elem->SetParent(*parent());
  }
  elem->SetArray(this);
  nodes_.push_back(elem);
  if (increment_size) {
    IncrementSize();
  }
  return elem.get();
}

Node *NodeArray::node(size_t i) const {
  if (i < nodes_.size()) {
    return nodes_[i].get();
  } else {
    CERATA_LOG(FATAL, "Index " + std::to_string(i) + " out of bounds for node " + ToString());
  }
}

std::shared_ptr<Object> NodeArray::Copy() const {
  auto p = parent();
  auto ret = std::make_shared<NodeArray>(name(), node_id_, base_, std::dynamic_pointer_cast<Node>(size()->Copy()));
  if (p) {
    ret->SetParent(*p);
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
  CERATA_LOG(FATAL, "Node " + n.ToString() + " is not element of " + this->ToString());
}

PortArray::PortArray(const std::shared_ptr<Port> &base,
                     std::shared_ptr<Node> size,
                     Term::Dir dir) :
    NodeArray(base->name(), Node::NodeID::PORT, base, std::move(size)), Term(base->dir()) {}

std::shared_ptr<PortArray> PortArray::Make(const std::string &name,
                                           const std::shared_ptr<Type> &type,
                                           std::shared_ptr<Node> size,
                                           Port::Dir dir,
                                           const std::shared_ptr<ClockDomain> &domain) {
  auto base_node = Port::Make(name, type, dir, domain);
  auto *port_array = new PortArray(base_node, std::move(size), dir);
  return std::shared_ptr<PortArray>(port_array);
}

std::shared_ptr<PortArray> PortArray::Make(const std::shared_ptr<Port> &base_node,
                                           std::shared_ptr<Node> size) {
  auto *port_array = new PortArray(base_node, std::move(size), base_node->dir());
  return std::shared_ptr<PortArray>(port_array);
}

std::shared_ptr<Object> PortArray::Copy() const {
  // Make a copy of the size node.
  auto size_copy = std::dynamic_pointer_cast<Node>(size()->Copy());
  // Cast the base node pointer to a port pointer
  auto base_as_port = std::dynamic_pointer_cast<Port>(base_);
  // Create the new PortArray using the new nodes.
  auto *port_array = new PortArray(base_as_port, size_copy, dir());
  // Return the resulting object.
  return std::shared_ptr<PortArray>(port_array);
}

std::shared_ptr<NodeArray> SignalArray::Make(const std::string &name,
                                             const std::shared_ptr<Type> &type,
                                             std::shared_ptr<Node> size,
                                             const std::shared_ptr<ClockDomain> &domain) {
  auto base_node = Signal::Make(name, type, domain);
  auto *sig_array = new SignalArray(base_node, std::move(size));
  return std::shared_ptr<SignalArray>(sig_array);
}

}  // namespace cerata
