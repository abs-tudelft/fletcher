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

std::string Literal::ToString() const {
  if (storage_type_ == StorageType::BOOL) {
    return std::to_string(Bool_val_);
  } else if (storage_type_ == StorageType::STRING) {
    return String_val_;
  } else {
    return std::to_string(Int_val_);
  }
}

#ifndef LITERAL_IMPL_FACTORY

#define LITERAL_IMPL_FACTORY(NAME, BASETYPE, IDNAME, TYPENAME)                                                       \
  Literal::Literal(std::string name, const std::shared_ptr<Type> &type, TYPENAME value) \
    : MultiOutputNode(std::move(name), Node::NodeID::LITERAL, type), \
      storage_type_(StorageType::IDNAME), \
      NAME##_val_(std::move(value)) {} \
      \
  std::shared_ptr<Literal> Literal::Make##NAME(TYPENAME value) {  \
  std::stringstream str;  \
  str << #NAME << "_" << value; \
  auto ret = std::make_shared<Literal>(str.str(), BASETYPE(), value); \
  return ret; \
}
#endif

LITERAL_IMPL_FACTORY(String, string, STRING, std::string)
LITERAL_IMPL_FACTORY(Bool, boolean, BOOL, bool)
LITERAL_IMPL_FACTORY(Int, integer, INT, int)

std::shared_ptr<Object> Literal::Copy() const {
  switch (storage_type_) {
    default:return strl(String_val_);
    case StorageType::BOOL:return booll(Bool_val_);
    case StorageType::INT:return intl(Int_val_);
  }
}

std::shared_ptr<Edge> Literal::AddSource(Node *source) {
  throw std::runtime_error("Cannot drive a literal node.");
}

std::string ToString(Node::NodeID id) {
  switch (id) {
    case Node::NodeID::PORT:return "Port";
    case Node::NodeID::SIGNAL:return "Signal";
    case Node::NodeID::LITERAL:return "Literal";
    case Node::NodeID::PARAMETER:return "Parameter";
    case Node::NodeID::EXPRESSION:return "Expression";
    default:throw std::runtime_error("Unsupported Node type");
  }
}

std::shared_ptr<Port> Port::Make(std::string name, std::shared_ptr<Type> type, Term::Dir dir) {
  return std::make_shared<Port>(name, type, dir);
}

std::shared_ptr<Port> Port::Make(std::shared_ptr<Type> type, Term::Dir dir) {
  return std::make_shared<Port>(type->name(), type, dir);
}

std::shared_ptr<Object> Port::Copy() const {
  return std::make_shared<Port>(name(), type_, dir());
}

Port::Port(std::string
           name, std::shared_ptr<Type>
           type, Term::Dir
           dir)
    : NormalNode(std::move(name), Node::NodeID::PORT, std::move(type)), Term(dir) {}

Port &Port::InvertDirection() {
  dir_ = Term::Invert(dir_);
  return *this;
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

Signal::Signal(std::string name, std::shared_ptr<Type> type)
    : NormalNode(std::move(name), Node::NodeID::SIGNAL, std::move(type)) {}

std::shared_ptr<Signal> Signal::Make(std::string name, const std::shared_ptr<Type> &type) {
  auto ret = std::make_shared<Signal>(name, type);
  return ret;
}

std::shared_ptr<Signal> Signal::Make(const std::shared_ptr<Type> &type) {
  auto ret = std::make_shared<Signal>(type->name() + "_signal", type);
  return ret;
}

std::shared_ptr<Object> Signal::Copy() const {
  auto ret = std::make_shared<Signal>(this->name(), this->type_);
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
