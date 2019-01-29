#include <utility>

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

#include "nodes.h"

#include <optional>
#include <deque>
#include <memory>
#include <string>

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

size_t Node::num_edges() const {
  return ins_.size() + outs_.size();
}

size_t Node::num_ins() const {
  return ins_.size();
}

size_t Node::num_outs() const {
  return outs_.size();
}

std::shared_ptr<Node> Node::Copy() const {
  auto ret = std::make_shared<Node>(this->name(), this->id_, this->type_);
  return ret;
}

std::string Node::ToString() {
  return name();
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

std::shared_ptr<Literal> litstr(std::string str) {
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
  return std::make_shared<Port>(name(), type_, dir);
}

Port::Port(std::string name, std::shared_ptr<Type> type, Port::Dir dir)
    : Node(std::move(name), Node::PORT, std::move(type)), dir(dir) {}

std::shared_ptr<Node> Parameter::Copy() const {
  return std::make_shared<Parameter>(name(), type_, default_value);
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

std::string ToString(const std::shared_ptr<Node> &node) {
  if (node->IsLiteral()) {
    auto x = *Cast<Literal>(node);
    return x->ToString();
  } else if (node->IsParameter()) {
    auto x = *Cast<Parameter>(node);
    return x->name();
  } else {
    return node->name();
  }
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

std::shared_ptr<Node> Expression::Minimize() {
  // TODO(johanpel): put some more elaborate minimization function here

  auto lhe = Cast<Expression>(lhs);
  auto rhe = Cast<Expression>(rhs);
  if (lhe) {
    lhs = (*lhe)->Minimize();
  }
  if (rhe) {
    rhs = (*rhe)->Minimize();
  }

  if (operation == Expression::ADD) {
    if (lhs == litint<0>()) {
      return rhs;
    } else if (rhs == litint<0>()) {
      return lhs;
    }
  }
  if (operation == Expression::MUL) {
    if (lhs == litint<0>()) {
      return litint<0>();
    } else if (rhs == litint<0>()) {
      return litint<0>();
    }
  }

  return shared_from_this();
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

  auto min = Minimize();
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
