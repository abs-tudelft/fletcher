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

#include "./nodes.h"

#include <optional>
#include <utility>
#include <deque>
#include <memory>
#include <string>

#include "./utils.h"
#include "./edges.h"
#include "nodes.h"

namespace fletchgen {

std::deque<std::shared_ptr<Edge>> Node::edges() const {
  std::deque<std::shared_ptr<Edge>> ret;
  for (const auto &e : ins_) {
    ret.push_back(e);
  }
  for (const auto &e : outs_) {
    ret.push_back(e);
  }
  return ret;
}

Node::Node(std::string name, Node::ID id, std::shared_ptr<Type> type)
    : Named(std::move(name)), id_(id), type_(std::move(type)) {}

std::shared_ptr<Node> Node::Copy() const {
  auto ret = std::make_shared<Node>(this->name(), this->id_, this->type_);
  return ret;
}

std::string Node::ToString() {
  return name();
}

void Node::AddInput(std::shared_ptr<Edge> edge) {
  // TODO(johanpel): implement more sanity checks
  // Check if the edge destination is this node
  if (edge->dst == shared_from_this()) {
    ins_.push_back(edge);
  } else if (edge->dst == nullptr) {
    // There is no destination set, make this node the destination
    edge->dst = shared_from_this();
    ins_.push_back(edge);
  } else {
    throw std::runtime_error("Cannot add edge as input to node " + name()
                                 + ". Edge has other destination: " + edge->dst->name());
  }
}

void Node::AddOutput(std::shared_ptr<Edge> edge) {
  // TODO(johanpel): implement more sanity checks
  // Check if the edge destination is this node
  if (edge->src == shared_from_this()) {
    outs_.push_back(edge);
  } else if (edge->src == nullptr) {
    // There is no destination set, make this node the destination
    edge->src = shared_from_this();
    outs_.push_back(edge);
  } else {
    throw std::runtime_error("Cannot add edge as output of node " + name()
                                 + ". Edge has other source: " + edge->src->name());
  }
}

void Node::SetParent(const Graph *parent) {
  parent_ = parent;
}

Node &Node::RemoveEdge(const std::shared_ptr<Edge> &edge) {
  bool success = false;
  if (edge->src == shared_from_this()) {
    success = remove(&outs_, edge);
  } else if (edge->dst == shared_from_this()) {
    success = remove(&ins_, edge);
  }
  if (!success) {
    throw std::runtime_error("Edge " + edge->name() + " could not be removed from " + name()
                                 + " because it was neither input or output.");
  }
  return *this;
}

std::optional<std::deque<std::shared_ptr<Node>>> Node::GetWidthDrivingNodes() const {
  std::deque<std::shared_ptr<Node>> ret;
  if (num_ins() > num_outs()) {
    for (const auto &e : ins()) {
      ret.push_back(e->src);
    }
  } else if (num_ins() < num_outs()) {
    for (const auto &e : outs()) {
      ret.push_back(e->dst);
    }
  } else {
    return {};
  }
  return ret;
}

std::string Literal::ToString() {
  if (storage_type_ == BOOL) {
    return std::to_string(bool_val_);
  } else if (storage_type_ == STRING) {
    return str_val_;
  } else {
    return std::to_string(int_val_);
  }
}

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

Literal::Literal(std::string name, const std::shared_ptr<Type> &type, std::string value)
    : Node(std::move(name), Node::LITERAL, type), storage_type_(STRING), str_val_(std::move(value)) {}

Literal::Literal(std::string name, const std::shared_ptr<Type> &type, int value)
    : Node(std::move(name), Node::LITERAL, type), storage_type_(INT), int_val_(value) {}

Literal::Literal(std::string name, const std::shared_ptr<Type> &type, bool value)
    : Node(std::move(name), Node::LITERAL, type), storage_type_(BOOL), bool_val_(value) {}

std::shared_ptr<Node> Literal::Copy() const {
  auto ret = std::make_shared<Literal>(name(), type(), storage_type_, str_val_, int_val_, bool_val_);
  return ret;
}
std::shared_ptr<Literal> Literal::Make(int value) {
  auto ret = std::make_shared<Literal>("int" + std::to_string(value), integer(), value);
  return ret;
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

std::string ToString(Node::ID id) {
  switch (id) {
    case Node::PORT:return "port";
    case Node::SIGNAL:return "signal";
    case Node::LITERAL:return "literal";
    case Node::PARAMETER:return "parameter";
    default:throw std::runtime_error("Unsupported Node type");
  }
}

std::shared_ptr<Port> Port::Make(std::string name, std::shared_ptr<Type> type, Port::Dir dir) {
  return std::make_shared<Port>(name, type, dir);
}

std::shared_ptr<Port> Port::Make(std::shared_ptr<Type> type, Port::Dir dir) {
  return std::make_shared<Port>(type->name(), type, dir);
}

std::shared_ptr<Node> Port::Copy() const {
  return std::make_shared<Port>(name(), type(), dir);
}

Port::Port(std::string name, std::shared_ptr<Type> type, Port::Dir dir)
    : Node(std::move(name), Node::PORT, std::move(type)), dir(dir) {}

std::shared_ptr<Node> Parameter::Copy() const {
  return std::make_shared<Parameter>(name(), type(), default_value);
}

std::shared_ptr<Parameter> Parameter::Make(std::string name,
                                           std::shared_ptr<Type> type,
                                           std::optional<std::shared_ptr<Literal>> default_value) {
  return std::make_shared<Parameter>(name, type, default_value);
}

Parameter::Parameter(std::string name,
                     const std::shared_ptr<Type> &type,
                     std::optional<std::shared_ptr<Literal>> default_value)
    : Node(std::move(name), Node::PARAMETER, type), default_value(std::move(default_value)) {}

Signal::Signal(std::string name, std::shared_ptr<Type> type)
    : Node(std::move(name), Node::SIGNAL, std::move(type)) {}

std::shared_ptr<Signal> Signal::Make(std::string name, const std::shared_ptr<Type> &type) {
  auto ret = std::make_shared<Signal>(name, type);
  return ret;
}

std::shared_ptr<Signal> Signal::Make(const std::shared_ptr<Type> &type) {
  auto ret = std::make_shared<Signal>(type->name() + "_signal", type);
  return ret;
}

std::shared_ptr<Expression> Expression::Make(Expression::Operation op,
                                             const std::shared_ptr<Node> &lhs,
                                             const std::shared_ptr<Node> &rhs) {
  return std::make_shared<Expression>(op, lhs, rhs);
}

Expression::Expression(Expression::Operation op, const std::shared_ptr<Node> &left, const std::shared_ptr<Node> &right)
    : Node(::fletchgen::ToString(op), EXPRESSION, string()),
      operation(op), lhs(left), rhs(right) {}

std::shared_ptr<Expression> operator+(const std::shared_ptr<Node> &lhs, const std::shared_ptr<Node> &rhs) {
  return Expression::Make(Expression::ADD, lhs, rhs);
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
      if ((ll->storage_type_ == Literal::INT) && (lr->storage_type_ == Literal::INT) && (ll->type() == lr->type())) {
        switch (exp->operation) {
          case Expression::ADD: return Literal::Make(ll->name() + lr->name(), ll->type(), ll->int_val_ + lr->int_val_);
          case Expression::SUB: return Literal::Make(ll->name() + lr->name(), ll->type(), ll->int_val_ - lr->int_val_);
          case Expression::MUL: return Literal::Make(ll->name() + lr->name(), ll->type(), ll->int_val_ * lr->int_val_);
          case Expression::DIV: return Literal::Make(ll->name() + lr->name(), ll->type(), ll->int_val_ / lr->int_val_);
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
        if (ret->lhs == intl<0>()) return node;
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
        if (ret->lhs == intl<0>()) return intl<0>();
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

std::string Expression::ToString() {
  std::string ls;
  std::string op;
  std::string rs;

  auto min = Minimize(shared_from_this());
  auto mine = Cast<Expression>(min);
  if (mine) {
    ls = (*mine)->lhs->ToString();
    op = fletchgen::ToString(operation);
    rs = (*mine)->rhs->ToString();
    return ls + op + rs;
  } else {
    return min->ToString();
  }
}

std::shared_ptr<Node> Expression::Copy() const {
  return Expression::Make(operation, lhs, rhs);
}
}  // namespace fletchgen
