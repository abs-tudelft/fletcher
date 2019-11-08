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

#include <string>
#include <functional>
#include <utility>
#include <variant>
#include <memory>
#include <vector>

#include "dag/types.h"

#pragma once

namespace dag {

struct VertexProfile {
  uint32_t elements;
  uint32_t valids;
  uint32_t readies;
  uint32_t transfers;
  uint32_t packets;
  uint32_t cycles;
};

typedef std::vector<VertexProfile> ProfileParam;

typedef std::function<std::string(ProfileParam)> ProfileParamFunc;
typedef std::variant<std::string, ProfileParamFunc> AnyParamFunc;

struct Graph;

struct Constant {
  Constant(std::string name, AnyParamFunc value)
      : name(std::move(name)), value(std::move(value)), parent(nullptr) {}
  Constant(std::string name, AnyParamFunc value, Graph *parent)
      : name(std::move(name)), value(std::move(value)), parent(parent) {}
  std::string name;
  AnyParamFunc value;
  Graph *parent;
  Constant &operator=(AnyParamFunc func);
};

struct Vertex : public std::enable_shared_from_this<Vertex> {
  Vertex(std::string name, TypeRef type, bool is_input = true, Graph *parent = nullptr)
      : name(std::move(name)), type(std::move(type)), input(is_input), parent(parent) {}
  std::string name;
  TypeRef type;
  bool input;
  Graph *parent;
  [[nodiscard]] bool IsInput() const { return input; }
  [[nodiscard]] bool IsOutput() const { return !input; }
};

inline Vertex In(std::string name, TypeRef type) {
  return Vertex(std::move(name), std::move(type), true);
}
inline Vertex In(std::string name, TypeRef type, Graph *parent) {
  return Vertex(std::move(name), std::move(type), true, parent);
}
inline Vertex Out(std::string name, TypeRef type) {
  return Vertex(std::move(name), std::move(type), false);
}
inline Vertex Out(std::string name, TypeRef type, Graph *parent) {
  return Vertex(std::move(name), std::move(type), false, parent);
}

struct Edge {
  Edge(const Vertex *dst, const Vertex *src);
  std::string name;
  const Vertex *src_;
  const Vertex *dst_;

  Edge &named(std::string name);
};

struct Graph {
  Graph() = default;
  Graph(Graph &&other) noexcept;
  explicit Graph(std::string name) : name(std::move(name)) {}
  std::string name;
  std::vector<std::unique_ptr<Constant>> constants;
  std::vector<std::unique_ptr<Vertex>> inputs;
  std::vector<std::unique_ptr<Vertex>> outputs;
  std::vector<std::unique_ptr<Graph>> children;
  std::vector<std::unique_ptr<Edge>> edges;
  bool reads_memory = false;
  bool writes_memory = false;

  // Functions to copy objects onto the graph.
  Constant &Add(const Constant &c);
  Vertex &Add(const Vertex &v);
  Edge &Add(const Edge &e);
  Graph &Add(Graph g);

  Constant &operator+=(Constant c);
  Vertex &operator+=(Vertex v);
  Edge &operator+=(Edge e);
  Graph &operator+=(Graph t);

  // Functions to copy objects onto the graph, losing the reference to the object.
  Graph &operator<<(Constant c);
  Graph &operator<<(Vertex v);
  Graph &operator<<(Edge e);
  Graph &operator<<(Graph g);

  [[nodiscard]] Constant &c(const std::string &Constant_name);
  [[nodiscard]] const Vertex &o(size_t i) const;
  [[nodiscard]] const Vertex &i(size_t i) const;

  const Vertex &operator()(const std::string &vertex_name) const;

  [[nodiscard]] std::string ToString() const;
  [[nodiscard]] std::string ToStringInputs() const;
  [[nodiscard]] std::string ToStringOutputs() const;
};

void operator<<=(const Constant &dst, const std::string &src);
Edge operator<<=(const Vertex &dst, const Vertex &src);
Edge operator<<=(const Graph &dst, const Vertex &src);
Edge operator<<=(const Vertex &dst, const Graph &src);
Edge operator<<=(const Graph &dst, const Graph &src);

}  // namespace dag
