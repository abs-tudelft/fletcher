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
#include <deque>
#include <memory>
#include <string>

#include "cerata/utils.h"
#include "cerata/edge.h"
#include "cerata/pool.h"
#include "cerata/graph.h"
#include "cerata/expression.h"

namespace cerata {

Node::Node(std::string name, Node::NodeID id, std::shared_ptr<Type> type)
    : Object(std::move(name), Object::NODE), node_id_(id), type_(std::move(type)) {}

std::string Node::ToString() const {
  return name();
}

std::deque<Edge *> Node::edges() const {
  auto snk = sinks();
  auto src = sources();
  std::deque<Edge *> edges;
  edges.insert(edges.end(), snk.begin(), snk.end());
  edges.insert(edges.end(), src.begin(), src.end());
  return edges;
}

// Generate node casting convenience functions.
#ifndef NODE_CAST_IMPL_FACTORY
#define NODE_CAST_IMPL_FACTORY(NODENAME)                                                     \
NODENAME& Node::As##NODENAME() { return dynamic_cast<NODENAME &>(*this); }                   \
const NODENAME &Node::As##NODENAME() const { return dynamic_cast<const NODENAME &>(*this); }
NODE_CAST_IMPL_FACTORY(Port)
NODE_CAST_IMPL_FACTORY(Signal)
NODE_CAST_IMPL_FACTORY(Parameter)
NODE_CAST_IMPL_FACTORY(Literal)
NODE_CAST_IMPL_FACTORY(Expression)
#endif

bool MultiOutputNode::AddEdge(const std::shared_ptr<Edge> &edge) {
  bool success = false;
  // Check if this edge has a source
  if (edge->src()) {
    // Check if the source is this node
    if (edge->src() == this) {
      // Check if this node does not already contain this edge
      if (!Contains(outputs_, edge)) {
        // Add the edge to this node
        outputs_.push_back(edge);
        success = true;
      }
    }
  }
  return success;
}

bool MultiOutputNode::RemoveEdge(Edge *edge) {
  if (edge->src()) {
    if (edge->src() == this) {
      // This node sources the edge.
      for (auto i = outputs_.begin(); i < outputs_.end(); i++) {
        if (i->get() == edge) {
          outputs_.erase(i);
          return true;
        }
      }
    }
  }
  return false;
}

std::shared_ptr<Edge> MultiOutputNode::AddSink(Node *sink) {
  return Connect(sink, this);
}

std::optional<Edge *> NormalNode::input() const {
  if (input_ != nullptr) {
    return input_.get();
  }
  return {};
}

std::deque<Edge *> NormalNode::sources() const {
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
  if (edge->dst() && !success) {
    if ((edge->dst() == this) && (input_.get() == edge)) {
      input_.reset();
      success = true;
    }
  }
  return success;
}

std::shared_ptr<Edge> NormalNode::AddSource(Node *source) {
  return Connect(this, source);
}

std::string ToString(Node::NodeID id) {
  switch (id) {
    case Node::NodeID::PORT:return "Port";
    case Node::NodeID::SIGNAL:return "Signal";
    case Node::NodeID::LITERAL:return "Literal";
    case Node::NodeID::PARAMETER:return "Parameter";
    case Node::NodeID::EXPRESSION:return "Expression";
    default:throw std::runtime_error("Corrupted node type.");
  }
}

std::shared_ptr<Object> Parameter::Copy() const {
  return Make(name(), type()->shared_from_this(), default_value_);
}

std::shared_ptr<Parameter> Parameter::Make(const std::string &name,
                                           const std::shared_ptr<Type> &type,
                                           const std::optional<std::shared_ptr<Literal>> &default_value) {
  auto p = new Parameter(name, type, default_value);
  return std::shared_ptr<Parameter>(p);
}

Parameter::Parameter(std::string name,
                     const std::shared_ptr<Type> &type,
                     std::optional<std::shared_ptr<Literal>> default_value)
    : NormalNode(std::move(name), Node::NodeID::PARAMETER, type), default_value_(std::move(default_value)) {}

std::optional<Node *> Parameter::GetValue() const {
  if (input()) {
    return input().value()->src();
  } else if (default_value_) {
    return default_value_->get();
  }
  return std::nullopt;
}

Signal::Signal(std::string name, std::shared_ptr<Type> type, std::shared_ptr<ClockDomain> domain)
    : NormalNode(std::move(name), Node::NodeID::SIGNAL, std::move(type)), Synchronous(domain) {}

std::shared_ptr<Signal> Signal::Make(std::string name,
                                     const std::shared_ptr<Type> &type,
                                     std::shared_ptr<ClockDomain> domain) {
  auto ret = std::make_shared<Signal>(name, type, domain);
  return ret;
}

std::shared_ptr<Signal> Signal::Make(const std::shared_ptr<Type> &type,
                                     std::shared_ptr<ClockDomain> domain) {
  auto ret = std::make_shared<Signal>(type->name() + "_signal", type, domain);
  return ret;
}

std::shared_ptr<Object> Signal::Copy() const {
  auto ret = std::make_shared<Signal>(this->name(), this->type_, this->domain_);
  return ret;
}

std::string Term::str(Term::Dir dir) {
  switch (dir) {
    default: return "none";
    case IN: return "in";
    case OUT: return "out";
  }
}

Term::Dir Term::Invert(Term::Dir dir) {
  if (dir == IN) {
    return OUT;
  } else if (dir == OUT) {
    return IN;
  } else {
    CERATA_LOG(FATAL, "Corrupted terminator direction.");
  }
}

}  // namespace cerata
