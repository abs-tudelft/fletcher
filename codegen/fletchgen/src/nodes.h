#include <utility>

#include <utility>

#include <utility>

#include <utility>

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

#pragma once

#include "./types.h"

namespace fletchgen {

// Forward Declr.
struct Edge;

/**
 * @brief A node.
 */
struct Node : public Named {
  enum ID {
    PORT,
    SIGNAL,
    PARAMETER,
    LITERAL
  };

  virtual ~Node() = default;

  ID id;

  std::shared_ptr<Type> type;

  std::deque<std::shared_ptr<Edge>> ins;
  std::deque<std::shared_ptr<Edge>> outs;

  Node(std::string name, ID id, std::shared_ptr<Type> type)
      : Named(std::move(name)), id(id), type(std::move(type)) {}

  std::deque<std::shared_ptr<Edge>> edges() const;
  std::shared_ptr<Edge> in(size_t i) { return ins[i]; }
  std::shared_ptr<Edge> out(size_t i) { return outs[i]; }

  bool Is(ID tid) { return id == tid; }
  bool IsPort() { return id == PORT; }
  bool IsSignal() { return id == SIGNAL; }
  bool IsParameter() { return id == PARAMETER; }
  bool IsLiteral() { return id == LITERAL; }

  static bool HasSameWidth(const std::shared_ptr<Node> &a, const std::shared_ptr<Node> &b);
};

struct Signal : public Node {
  std::shared_ptr<Type> type;

  Signal(std::string name, std::shared_ptr<Type> type)
      : Node(std::move(name), Node::SIGNAL, std::move(type)) {}

  static std::shared_ptr<Signal> Make(std::string name, const std::shared_ptr<Type> &type) {
    auto ret = std::make_shared<Signal>(name, type);
    return ret;
  }

  static std::shared_ptr<Signal> Make(const std::shared_ptr<Type> &type) {
    auto ret = std::make_shared<Signal>(type->name() + "_signal", type);
    return ret;
  }
};

struct Literal : public Node {
  enum { INT, STRING, BOOL } lit_type;
  std::string str_val = "";
  int int_val = 0;
  bool bool_val = false;

  Literal(std::string name, std::string value);
  Literal(std::string name, int value);
  Literal(std::string name, bool value);

  static std::shared_ptr<Literal> Make(std::string value);
  static std::shared_ptr<Literal> Make(std::string name, std::string value);
  static std::shared_ptr<Literal> Make(std::string name, int value);
  static std::shared_ptr<Literal> Make(std::string name, bool value);

  std::string ToValueString();
};

template<int V>
std::shared_ptr<Literal> lit() {
  static std::shared_ptr<Literal> result = std::make_shared<Literal>("lit_" + std::to_string(V), V);
  return result;
}

struct Parameter : public Node {
  Parameter(std::string name, std::shared_ptr<Type> type, std::shared_ptr<Literal> default_value = nullptr)
      : Node(std::move(name), Node::PARAMETER, std::move(type)), default_value(std::move(default_value)) {}

  static std::shared_ptr<Parameter> Make(std::string name,
                                         std::shared_ptr<Type> type,
                                         std::shared_ptr<Literal> default_value = nullptr) {
    return std::make_shared<Parameter>(name, type, default_value);
  }
  std::shared_ptr<Literal> default_value;
};

struct Port : public Node {
  enum Dir { IN, OUT };
  Dir dir;

  Port(std::string name, std::shared_ptr<Type> type, Dir dir)
      : Node(std::move(name), Node::PORT, std::move(type)), dir(dir) {}

  static std::shared_ptr<Port> Make(std::string name, std::shared_ptr<Type> type, Dir dir = Dir::IN) {
    return std::make_shared<Port>(name, type, dir);
  };

  static std::shared_ptr<Port> Make(std::shared_ptr<Type> type, Dir dir = Dir::IN) {
    return std::make_shared<Port>(type->name(), type, dir);
  };
};

template<typename T>
std::shared_ptr<T> Cast(std::shared_ptr<Node> &obj) {
  return std::dynamic_pointer_cast<T>(obj);
}

template<typename T>
const std::shared_ptr<T> Cast(const std::shared_ptr<Node> &obj) {
  return std::dynamic_pointer_cast<T>(obj);
}

}  // namespace fletchgen
