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

#include "cerata/array.h"

#include <optional>
#include <utility>
#include <vector>
#include <memory>
#include <string>

#include "cerata/edge.h"
#include "cerata/node.h"
#include "cerata/expression.h"
#include "cerata/parameter.h"
#include "cerata/pool.h"
#include "cerata/graph.h"

namespace cerata {

static std::shared_ptr<Node> IncrementNode(Node *node) {
  if (node->IsLiteral() || node->IsExpression()) {
    return node->shared_from_this() + 1;
  } else if (node->IsParameter()) {
    // If the node is a parameter, we should be able to trace its source back to a literal node.
    // We then replace the last parameter node in the trace by a copy and source the copy from an incremented literal.
    auto param = dynamic_cast<Parameter *>(node);
    // Initialize the trace with the parameter node.
    std::vector<Node *> value_trace;
    param->TraceValue(&value_trace);
    // Sanity check the trace.
    if (!value_trace.back()->IsLiteral()) {
      CERATA_LOG(FATAL, "Parameter node " + param->ToString() + " not (indirectly) sourced by literal.");
    }
    // The second-last node is of importance, because this is the final parameter node.
    auto second_last = value_trace[value_trace.size() - 2];
    auto incremented = value_trace.back()->shared_from_this() + 1;
    // Source the second last node with whatever literal was at the end of the trace, plus one.
    Connect(second_last, incremented);
    return node->shared_from_this();
  } else {
    CERATA_LOG(FATAL, "Can only increment literal, expression or parameter size node " + node->ToString());
  }
}

void NodeArray::SetSize(const std::shared_ptr<Node> &size) {
  if (!(size->IsLiteral() || size->IsParameter() || size->IsExpression())) {
    CERATA_LOG(FATAL, "NodeArray size node must be literal, parameter or expression.");
  }
  if (size->IsParameter()) {
    auto param = size->AsParameter();
    if (param->node_array_parent) {
      auto na = size->AsParameter()->node_array_parent.value();
      if (na != this) {
        CERATA_LOG(FATAL, "NodeArray size can only be used by a single NodeArray.");
      }
    }
    param->node_array_parent = this;
  }
  size_ = size;
}

void NodeArray::IncrementSize() {
  SetSize(IncrementNode(size()));
}

std::shared_ptr<Node> NodeArray::Append(bool increment_size) {
  // Create a new copy of the base node.
  auto new_node = std::dynamic_pointer_cast<Node>(base_->Copy());
  if (parent()) {
    new_node->SetParent(*parent());
  }
  new_node->SetArray(this);
  nodes_.push_back(new_node);

  // Increment this NodeArray's size node.
  if (increment_size) {
    IncrementSize();
  }

  // Return the new node.
  return new_node;
}

Node *NodeArray::node(size_t i) const {
  if (i < nodes_.size()) {
    return nodes_[i].get();
  } else {
    CERATA_LOG(FATAL, "Index " + std::to_string(i) + " out of bounds for node " + ToString());
  }
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

void NodeArray::SetType(const std::shared_ptr<Type> &type) {
  base_->SetType(type);
  for (auto &n : nodes_) {
    n->SetType(type);
  }
}

NodeArray::NodeArray(std::string name, Node::NodeID id, std::shared_ptr<Node> base, const std::shared_ptr<Node> &size)
    : Object(std::move(name), Object::ARRAY), node_id_(id), base_(std::move(base)) {
  base_->SetArray(this);
  SetSize(size);
}

std::shared_ptr<Object> NodeArray::Copy() const {
  auto ret = std::make_shared<NodeArray>(name(), node_id_, base_, intl(0));
  return ret;
}

NodeArray *NodeArray::CopyOnto(Graph *dst, const std::string &name, NodeMap *rebinding) {
  // Make a normal copy (that does not rebind the type generics).
  auto result = std::dynamic_pointer_cast<NodeArray>(this->Copy());
  result->SetName(name);

  // Figure out the right size node.
  std::shared_ptr<Node> new_size = result->size_;
  if (size_->IsParameter()) {
    if (rebinding->count(size_.get()) == 0) {
      CERATA_LOG(FATAL, "Size node parameters of NodeArray " + size_->name()
          + " must be in rebind map before NodeArray can be copied.");
    } else {
      result->SetSize(rebinding->at(size_.get())->shared_from_this());
    }
  }

  // Obtains the references of the base type.
  auto base_generics = base_->type()->GetGenerics();
  if (!base_generics.empty()) {
    ImplicitlyRebindNodes(dst, base_generics, rebinding);
    // Make a copy of the type, rebinding the generic nodes.
    auto rebound_base_type = result->type()->Copy(*rebinding);
    // Set the type of the new node to this new type.
    result->base_->SetType(rebound_base_type);
  }

  // It should now be possible to add the copy of the array onto the graph.
  dst->Add(result);

  return result.get();
}

PortArray::PortArray(const std::shared_ptr<Port> &base,
                     const std::shared_ptr<Node> &size) :
    NodeArray(base->name(), Node::NodeID::PORT, base, size), Term(base->dir()) {}

std::shared_ptr<PortArray> port_array(const std::string &name,
                                      const std::shared_ptr<Type> &type,
                                      const std::shared_ptr<Node> &size,
                                      Port::Dir dir,
                                      const std::shared_ptr<ClockDomain> &domain) {
  auto base_node = port(name, type, dir, domain);
  auto *port_array = new PortArray(base_node, size);
  return std::shared_ptr<PortArray>(port_array);
}

std::shared_ptr<PortArray> port_array(const std::shared_ptr<Port> &base_node,
                                      const std::shared_ptr<Node> &size) {
  auto *port_array = new PortArray(base_node, size);
  return std::shared_ptr<PortArray>(port_array);
}

std::shared_ptr<Object> PortArray::Copy() const {
  // Create the new PortArray using the new nodes.
  auto result = port_array(name(), base_->type()->shared_from_this(), intl(0), dir_, *GetDomain(*base_));
  // Return the resulting object.
  return result;
}

std::shared_ptr<SignalArray> signal_array(const std::string &name,
                                          const std::shared_ptr<Type> &type,
                                          const std::shared_ptr<Node>& size,
                                          const std::shared_ptr<ClockDomain> &domain) {
  auto base_node = signal(name, type, domain);
  auto *sig_array = new SignalArray(base_node, size);
  return std::shared_ptr<SignalArray>(sig_array);
}

}  // namespace cerata
