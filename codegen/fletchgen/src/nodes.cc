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

#include "./nodes.h"

#include <optional>
#include <deque>
#include <memory>
#include <string>

namespace fletchgen {

std::deque<std::shared_ptr<Edge>> Node::edges() const {
  std::deque<std::shared_ptr<Edge>> ret;
  for (const auto &e : ins) {
    ret.push_back(e);
  }
  for (const auto &e : outs) {
    ret.push_back(e);
  }
  return ret;
}

Node::Node(std::string name, Node::ID id, std::shared_ptr<Type> type)
    : Named(std::move(name)), id(id), type(std::move(type)) {}

std::string Literal::ToValueString() {
  if (val_storage_type == BOOL) {
    return std::to_string(bool_val);
  } else if (val_storage_type == STRING) {
    return str_val;
  } else {
    return std::to_string(int_val);
  }
}

std::shared_ptr<Literal> Literal::Make(std::string name, const std::shared_ptr<Type>& type, bool value) {
  return std::make_shared<Literal>(name, type, value);
}

std::shared_ptr<Literal> Literal::Make(std::string name, const std::shared_ptr<Type>& type, int value) {
  return std::make_shared<Literal>(name, type, value);
}

std::shared_ptr<Literal> Literal::Make(const std::shared_ptr<Type>& type, std::string value) {
  return std::make_shared<Literal>(value, type, value);
}

std::shared_ptr<Literal> Literal::Make(std::string name, const std::shared_ptr<Type>& type, std::string value) {
  return std::make_shared<Literal>(name, type, value);
}

Literal::Literal(std::string name, const std::shared_ptr<Type>& type, std::string value)
    : Node(std::move(name), Node::LITERAL, type), val_storage_type(STRING), str_val(std::move(value)) {}

Literal::Literal(std::string name, const std::shared_ptr<Type>& type, int value)
    : Node(std::move(name), Node::LITERAL, type), val_storage_type(INT), int_val(value) {}

Literal::Literal(std::string name, const std::shared_ptr<Type>& type, bool value)
    : Node(std::move(name), Node::LITERAL, type), val_storage_type(BOOL), bool_val(value) {}

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

std::shared_ptr<Port> Port::Copy() {
  return std::make_shared<Port>(name(), type, dir);
}

Port::Port(std::string name, std::shared_ptr<Type> type, Port::Dir dir)
    : Node(std::move(name), Node::PORT, std::move(type)), dir(dir) {}

std::shared_ptr<Parameter> Parameter::Copy() {
  return std::make_shared<Parameter>(name(), type, default_value);
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

}  // namespace fletchgen
