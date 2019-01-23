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

bool Node::HasSameWidth(const std::shared_ptr<Node> &a, const std::shared_ptr<Node> &b) {
  if ((a->type->id == Type::VECTOR) && (b->type->id == Type::VECTOR)) {
    return Cast<Vector>(a->type)->width() == Cast<Vector>(b->type)->width();
  } else if ((a->type->id == Type::STREAM) && (b->type->id == Type::STREAM)) {
    auto s_a = Cast<Stream>(a->type);
    auto s_b = Cast<Stream>(b->type);
    if ((s_a->element_type()->id == Type::VECTOR) && (s_b->element_type()->id == Type::VECTOR)) {
      return Cast<Vector>(s_a->element_type())->width() == Cast<Vector>(s_b->element_type())->width();
    }
  }
  return a->type->Is(b->type->id);
}

std::string Literal::ToValueString() {
  if (lit_type == BOOL) {
    return std::to_string(bool_val);
  } else if (lit_type == STRING) {
    return str_val;
  } else
    return std::to_string(int_val);
}

std::shared_ptr<Literal> Literal::Make(std::string name, bool value) {
  return std::make_shared<Literal>(name, value);
}

std::shared_ptr<Literal> Literal::Make(std::string name, int value) {
  return std::make_shared<Literal>(name, value);
}

std::shared_ptr<Literal> Literal::Make(std::string value) {
  return std::make_shared<Literal>(value, value);
}

std::shared_ptr<Literal> Literal::Make(std::string name, std::string value) {
  return std::make_shared<Literal>(name, value);
}

Literal::Literal(std::string name, std::string value)
    : Node(std::move(name), Node::LITERAL, nullptr), lit_type(STRING), str_val(std::move(value)) {}

Literal::Literal(std::string name, int value)
    : Node(std::move(name), Node::LITERAL, nullptr), lit_type(INT), int_val(value) {}

Literal::Literal(std::string name, bool value)
    : Node(std::move(name), Node::LITERAL, nullptr), lit_type(BOOL), bool_val(value) {}

std::shared_ptr<Literal> litstr(std::string str) {
  auto result = Literal::Make(str);
  return result;
}

std::string ToString(Node::ID id) {
  switch (id) {
    case Node::PORT:return "port";
    case Node::SIGNAL:return "signal";
    case Node::LITERAL:return "literal";
    case Node::PARAMETER:return "parameter";
    default:
      throw std::runtime_error("Unsupported Node type");
  }
}

}  // namespace fletchgen
