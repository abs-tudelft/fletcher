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

#include "cerata/nodes.h"

#include <optional>
#include <utility>
#include <deque>
#include <memory>
#include <string>

#include "cerata/utils.h"
#include "cerata/edges.h"

namespace cerata {

Node::Node(std::string name, Node::NodeID id, std::shared_ptr<Type> type)
    : Object(std::move(name), Object::NODE), node_id_(id), type_(std::move(type)) {}

std::string Node::ToString() const {
  return name();
}

bool MultiOutputNode::AddEdge(const std::shared_ptr<Edge> &edge) {
  bool success = false;
  // Check if this edge has a source
  if (edge->src) {
    // Check if the source is this node
    if ((*edge->src).get() == this) {
      // Check if this node does not already contain this edge
      if (!contains(outputs_, edge)) {
        // Add the edge to this node
        outputs_.push_back(edge);
        success = true;
      }
    }
  }
  return success;
}

bool MultiOutputNode::RemoveEdge(const std::shared_ptr<Edge> &edge) {
  bool success = false;
  if (edge->src) {
    if ((*edge->src).get() == this) {
      // This node sources the edge.
      // Remove it from the sinks.
      success = remove(&outputs_, edge);
      if (success) {
        // Remove it from the edge source.
        edge->src = {};
      }
    }
  }
  return success;
}

std::shared_ptr<Edge> MultiOutputNode::AddSink(const std::shared_ptr<Node> &sink) {
  return Connect(sink, shared_from_this());
}

std::optional<std::shared_ptr<Edge>> NormalNode::input() const {
  if (input_ != nullptr) {
    return input_;
  }
  return {};
}

std::deque<std::shared_ptr<Edge>> NormalNode::sources() const {
  if (input_ != nullptr) {
    return {input_};
  } else {
    return {};
  }
}

bool NormalNode::AddEdge(const std::shared_ptr<Edge> &edge) {
  // first attempt to add the edge as an output.
  bool success = MultiOutputNode::AddEdge(edge);
  // If we couldn't add the edge as output, it must be input
  if (!success) {
    // Check if the edge has a destination
    if (edge->dst) {
      // Check if this is the destination
      if ((*edge->dst).get() == this) {
        // Check if this node already had some source
        if (input_ != nullptr) {
          // Invalidate the destination on that edge.
          input_->dst = {};
        }
        // Set this node source to the edge.
        input_ = edge;
        success = true;
      }
    }
  }
  return success;
}

bool NormalNode::RemoveEdge(const std::shared_ptr<Edge> &edge) {
  // First remove the edge from any outputs
  bool success = MultiOutputNode::RemoveEdge(edge);
  // Check if the edge is an input to this node
  if (edge->dst && !success) {
    if (((*edge->dst).get() == this) && (input_ == edge)) {
      input_ = nullptr;
      edge->dst = {};
      success = true;
    }
  }
  return success;
}

std::shared_ptr<Edge> NormalNode::AddSource(const std::shared_ptr<Node> &source) {
  return Connect(shared_from_this(), source);
}

std::string Literal::ToString() const {
  if (storage_type_ == BOOL) {
    return std::to_string(bool_val_);
  } else if (storage_type_ == STRING) {
    return str_val_;
  } else {
    return std::to_string(int_val_);
  }
}

Literal::Literal(std::string name, const std::shared_ptr<Type> &type, std::string value)
    : MultiOutputNode(std::move(name), Node::LITERAL, type), storage_type_(STRING), str_val_(std::move(value)) {}
Literal::Literal(std::string name, const std::shared_ptr<Type> &type, int value)
    : MultiOutputNode(std::move(name), Node::LITERAL, type), storage_type_(INT), int_val_(value) {}
Literal::Literal(std::string name, const std::shared_ptr<Type> &type, bool value)
    : MultiOutputNode(std::move(name), Node::LITERAL, type), storage_type_(BOOL), bool_val_(value) {}

std::shared_ptr<Literal> Literal::Make(std::string name, const std::shared_ptr<Type> &type, bool value) {
  return std::make_shared<Literal>(name, type, value);
}
std::shared_ptr<Literal> Literal::Make(std::string name, const std::shared_ptr<Type> &type, int value) {
  return std::make_shared<Literal>(name, type, value);
}
std::shared_ptr<Literal> Literal::Make(const std::shared_ptr<Type> &type, std::string value) {
  return std::make_shared<Literal>(value, type, value);
}
std::shared_ptr<Literal> Literal::Make(std::string name, const std::shared_ptr<Type> &type, std::string value) {
  return std::make_shared<Literal>(name, type, value);
}
std::shared_ptr<Literal> Literal::Make(int value) {
  auto ret = std::make_shared<Literal>("int" + std::to_string(value), integer(), value);
  return ret;
}

std::shared_ptr<Object> Literal::Copy() const {
  auto ret = std::make_shared<Literal>(name(), type(), storage_type_, str_val_, int_val_, bool_val_);
  return ret;
}
std::shared_ptr<Edge> Literal::AddSource(const std::shared_ptr<Node> &source) {
  throw std::runtime_error("Cannot drive a literal node.");
}

std::shared_ptr<Literal> strl(std::string str) {
  auto result = Literal::Make(string(), std::move(str));
  return result;
}

std::shared_ptr<Literal> bool_true() {
  static auto result = Literal::Make("bool_true", boolean(), true);
  return result;
}

std::shared_ptr<Literal> bool_false() {
  static auto result = Literal::Make("bool_true", boolean(), false);
  return result;
}

std::string ToString(Node::NodeID id) {
  switch (id) {
    case Node::PORT:return "Port";
    case Node::SIGNAL:return "Signal";
    case Node::LITERAL:return "Literal";
    case Node::PARAMETER:return "Parameter";
    case Node::EXPRESSION:return "Expression";
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
  return std::make_shared<Port>(name(), type(), dir());
}

Port::Port(std::string
           name, std::shared_ptr<Type>
           type, Term::Dir
           dir)
    : NormalNode(std::move(name), Node::PORT, std::move(type)), Term(dir) {}

std::shared_ptr<Port> Port::InvertDirection() {
  dir_ = Term::Invert(dir_);
  return *Cast<Port>(shared_from_this());
}

std::shared_ptr<Object> Parameter::Copy() const {
  return std::make_shared<Parameter>(name(), type(), default_value);
}

std::shared_ptr<Parameter> Parameter::Make(std::string name,
                                           std::shared_ptr<Type> type,
                                           std::optional<std::shared_ptr<Literal>> default_value) {
  return std::make_shared<Parameter>(name, type, default_value);
}

Parameter::Parameter(std::string
                     name,
                     const std::shared_ptr<Type> &type,
                     std::optional<std::shared_ptr<Literal>> default_value)
    : NormalNode(std::move(name), Node::PARAMETER, type), default_value(std::move(default_value)) {}

std::optional<std::shared_ptr<Node>> Parameter::value() const {
  if (input()) {
    auto edge = *input();
    if (edge->src) {
      return *edge->src;
    }
  } else if (default_value) {
    return *default_value;
  }
  return {};
}

Signal::Signal(std::string
               name, std::shared_ptr<Type>
               type)
    : NormalNode(std::move(name), Node::SIGNAL, std::move(type)) {}

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

std::shared_ptr<Expression> Expression::Make(Expression::Operation op,
                                             const std::shared_ptr<Node> &lhs,
                                             const std::shared_ptr<Node> &rhs) {
  return std::make_shared<Expression>(op, lhs, rhs);
}

Expression::Expression(Expression::Operation
                       op,
                       const std::shared_ptr<Node> &left,
                       const std::shared_ptr<Node> &right)
    : MultiOutputNode(::cerata::ToString(op), EXPRESSION, string()),
      operation(op), lhs(left), rhs(right) {}

std::shared_ptr<Expression> operator+(const std::shared_ptr<Node> &lhs, const std::shared_ptr<Node> &rhs) {
  return Expression::Make(Expression::ADD, lhs, rhs);
}

std::shared_ptr<Node> operator+(const std::shared_ptr<Node> &lhs, int rhs) {
  if (lhs->IsLiteral()) {
    auto li = *Cast<Literal>(lhs);
    if (li->storage_type_ == Literal::INT) {
      return Literal::Make(li->int_val_ + rhs);
    }
  }
  return lhs + Literal::Make(rhs);
}

std::shared_ptr<Node> operator-(const std::shared_ptr<Node> &lhs, int rhs) {
  if (lhs->IsLiteral()) {
    auto li = *Cast<Literal>(lhs);
    if (li->storage_type_ == Literal::INT) {
      return Literal::Make(li->int_val_ - rhs);
    }
  }
  return lhs - Literal::Make(rhs);
}

std::shared_ptr<Expression> operator-(const std::shared_ptr<Node> &lhs, const std::shared_ptr<Node> &rhs) {
  return Expression::Make(Expression::SUB, lhs, rhs);
}

std::shared_ptr<Expression> operator*(const std::shared_ptr<Node> &lhs, const std::shared_ptr<Node> &rhs) {
  return Expression::Make(Expression::MUL, lhs, rhs);
}

std::shared_ptr<Expression> operator/(const std::shared_ptr<Node> &lhs, const std::shared_ptr<Node> &rhs) {
  return Expression::Make(Expression::DIV, lhs, rhs);
}

static std::shared_ptr<Node> MergeIfIntLiterals(std::shared_ptr<Node> node) {
  auto pexp = Cast<Expression>(node);
  if (pexp) {
    auto exp = *pexp;
    auto ret = Expression::Make(exp->operation, Expression::Minimize(exp->lhs), Expression::Minimize(exp->rhs));
    if (ret->lhs->IsLiteral() && ret->rhs->IsLiteral()) {
      auto ll = *Cast<Literal>(ret->lhs);
      auto lr = *Cast<Literal>(ret->rhs);
      if ((ll->storage_type_ == Literal::INT) && (lr->storage_type_ == Literal::INT)
          && (ll->type() == lr->type())) {
        switch (exp->operation) {
          case Expression::ADD:
            return Literal::Make(ll->name() + lr->name(),
                                 ll->type(),
                                 ll->int_val_ + lr->int_val_);
          case Expression::SUB:
            return Literal::Make(ll->name() + lr->name(),
                                 ll->type(),
                                 ll->int_val_ - lr->int_val_);
          case Expression::MUL:
            return Literal::Make(ll->name() + lr->name(),
                                 ll->type(),
                                 ll->int_val_ * lr->int_val_);
          case Expression::DIV:
            return Literal::Make(ll->name() + lr->name(),
                                 ll->type(),
                                 ll->int_val_ / lr->int_val_);
        }
      }
      return ret;
    }
  }
  return node;
}

static std::shared_ptr<Node> EliminateZeroOne(std::shared_ptr<Node> node) {
  auto pexp = Cast<Expression>(node);
  if (pexp) {
    auto exp = *pexp;
    auto ret = Expression::Make(exp->operation, Expression::Minimize(exp->lhs), Expression::Minimize(exp->rhs));
    switch (ret->operation) {
      case Expression::ADD: {
        if (ret->lhs == intl<0>()) return ret->rhs;
        if (ret->rhs == intl<0>()) return ret->lhs;
        break;
      }
      case Expression::SUB: {
        if (ret->rhs == intl<0>()) return ret->lhs;
        break;
      }
      case Expression::MUL: {
        if (ret->lhs == intl<0>()) return intl<0>();
        if (ret->rhs == intl<0>()) return intl<0>();
        if (ret->lhs == intl<1>()) return ret->rhs;
        if (ret->rhs == intl<1>()) return ret->lhs;
        break;
      }
      case Expression::DIV: {
        if (ret->lhs == intl<0>() && ret->rhs != intl<0>()) return intl<0>();
        if (ret->rhs == intl<0>()) throw std::runtime_error("Division by 0.");
        if (ret->rhs == intl<1>()) return ret->lhs;
        break;
      }
    }
    return ret;
  }
  return node;
}

std::shared_ptr<Node> Expression::Minimize(const std::shared_ptr<Node> &node) {
  // TODO(johanpel): put some more elaborate minimization function/rules etc.. here
  auto min = EliminateZeroOne(node);
  min = MergeIfIntLiterals(min);
  return min;
}

std::string ToString(Expression::Operation operation) {
  switch (operation) {
    case Expression::ADD:return "+";
    case Expression::SUB:return "-";
    case Expression::MUL:return "*";
    case Expression::DIV:return "/";
    default:return "INVALID OP";
  }
}

std::shared_ptr<Node> operator+(const std::shared_ptr<Node> &lhs, const std::optional<std::shared_ptr<Node>> &rhs) {
  if (rhs) {
    return lhs + *rhs;
  } else {
    return lhs;
  }
}

std::string Expression::ToString() const {
  auto min = Minimize(std::const_pointer_cast<Node>(shared_from_this()));
  auto mine = Cast<Expression>(min);
  if (mine) {
    auto ls = (*mine)->lhs->ToString();
    auto op = cerata::ToString(operation);
    auto rs = (*mine)->rhs->ToString();
    return ls + op + rs;
  } else {
    return min->ToString();
  }
}

std::shared_ptr<Object> Expression::Copy() const {
  return Expression::Make(operation, lhs, rhs);
}

std::shared_ptr<Edge> Expression::AddSource(const std::shared_ptr<Node> &source) {
  throw std::runtime_error("Cannot drive an expression node.");
}

std::string Term::str(Term::Dir dir) {
  switch (dir) {
    default: return "none";
    case IN: return "in";
    case OUT: return "out";
  }
}

Term::Dir Term::Invert(Term::Dir dir) {
  if (dir == IN) { return OUT; }
  if (dir == OUT) { return IN; }
  return NONE;
}
}  // namespace cerata
