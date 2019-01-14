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
namespace stream {

// Forward Declarations
struct Edge;

struct NodeType {
  enum ID {
    PORT,
    SIGNAL,
    PARAMETER,
    LITERAL
  };
  NodeType(ID id, std::shared_ptr<Type> type) : id(id), type(std::move(type)) {}
  ID id;
  std::shared_ptr<Type> type;
  virtual ~NodeType() = default;
};

/**
 * @brief A node.
 */
struct Node : public Named {
  Node(std::string name, std::shared_ptr<NodeType> type) : Named(std::move(name)), type(std::move(type)) {}

  static std::shared_ptr<Node> Make(std::string name, const std::shared_ptr<NodeType> &type);
  std::deque<std::shared_ptr<Edge>> edges() const;

  std::shared_ptr<NodeType> type;
  std::deque<std::shared_ptr<Edge>> ins;
  std::deque<std::shared_ptr<Edge>> outs;
};

struct Signal : public Named, NodeType {
  Signal(std::string name, std::shared_ptr<Type> type)
      : Named(std::move(name)), NodeType(NodeType::SIGNAL, std::move(type)) {}

  static std::shared_ptr<Signal> Make(std::string name, std::shared_ptr<Type> type) {
    auto ret = std::make_shared<Signal>(name, type);
    return ret;
  }

  static std::shared_ptr<Node> ToNode(std::string name, const std::shared_ptr<Signal> &signal) {
    auto node = std::make_shared<Node>(name, signal);
    return node;
  }
};

struct Literal : public Named, NodeType {

  Literal(std::string name, std::shared_ptr<Type> type, std::string value)
      : Named(std::move(name)), NodeType(NodeType::LITERAL, std::move(type)), value(value) {}

  static std::shared_ptr<Literal> Make(std::string name,
                                       std::shared_ptr<Type> type,
                                       std::string value) {
    return std::make_shared<Literal>(name, type, value);
  }

  static std::shared_ptr<Node> ToNode(std::string name, const std::shared_ptr<Literal> &literal) {
    auto node = std::make_shared<Node>(name, literal);
    return node;
  }

  std::string value;
};

struct Parameter : public Named, NodeType {
  Parameter(std::string name, std::shared_ptr<Type> type, std::shared_ptr<Literal> default_value = nullptr)
      : Named(std::move(name)),
        NodeType(NodeType::PARAMETER, std::move(type)),
        default_value(std::move(default_value)) {}

  static std::shared_ptr<Parameter> Make(std::string name,
                                         std::shared_ptr<Type> type,
                                         std::shared_ptr<Literal> default_value = nullptr) {
    return std::make_shared<Parameter>(name, type, default_value);
  }
  std::shared_ptr<Literal> default_value;
};

struct Port : public Named, NodeType {
  enum Dir { IN, OUT };

  Port(std::string name, std::shared_ptr<Type> type, Dir dir)
      : Named(std::move(name)), NodeType(NodeType::PORT, std::move(type)), dir(dir) {}

  static std::shared_ptr<Port> Make(std::string name, std::shared_ptr<Type> type, Dir dir) {
    return std::make_shared<Port>(name, type, dir);
  };

  Dir dir;
};

}  // namespace stream
}  // namespace fletchgen
