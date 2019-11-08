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

#include "dag/dag.h"

#include <sstream>
#include <utility>

#include "dag/types.h"

namespace dag {

Constant &Constant::operator=(AnyParamFunc func) {
  value = std::move(func);
  return *this;
}

std::string Graph::ToStringInputs() const {
  std::stringstream str;
  for (auto i = inputs.begin(); i != inputs.end(); i++) {
    str << (*i)->name;
    if (i != inputs.end() - 1) {
      str << ", ";
    }
  }
  return str.str();
}

std::string Graph::ToStringOutputs() const {
  std::stringstream str;
  for (auto i = outputs.begin(); i != outputs.end(); i++) {
    str << (*i)->name;
    if (i != outputs.end() - 1) {
      str << ", ";
    }
  }
  return str.str();
}

const Vertex &Graph::operator()(const std::string &vertex_name) const {
  for (const auto &i : inputs) {
    if (i->name == vertex_name) {
      return *i;
    }
  }
  for (const auto &o : outputs) {
    if (o->name == vertex_name) {
      return *o;
    }
  }
  throw std::runtime_error(this->ToString() + "\" has no input or output named \"" + name + "\". "
                               + "Inputs: " + this->ToStringInputs()
                               + ". Outputs: " + this->ToStringOutputs());
}

std::string Graph::ToString() const {
  return "Transform[" + name + "]";
}

Constant &Graph::c(const std::string &const_name) {
  for (auto &c : constants) {
    if (c->name == const_name) {
      return *c;
    }
  }
  throw std::runtime_error(this->ToString() + "\" has no Constant named \"" + const_name + "\". "
                               + "Inputs: " + this->ToStringInputs());
}

const Vertex &Graph::i(size_t i) const {
  if (inputs.empty()) {
    throw std::runtime_error("Graph " + name + " has no inputs.");
  }
  if (i > inputs.size()) {
    throw std::runtime_error("Index " + std::to_string(i) + " out of bounds. Transformation has "
                                 + std::to_string(inputs.size()) + " inputs.");
  }
  return *inputs[i].get();
}

const Vertex &Graph::o(size_t i) const {
  if (outputs.empty()) {
    throw std::runtime_error("Graph " + name + " has no outputs.");
  }
  if (i > outputs.size()) {
    throw std::runtime_error("Index " + std::to_string(i) + " out of bounds. Transformation has "
                                 + std::to_string(outputs.size()) + " outputs.");
  }
  return *outputs[i].get();
}

Constant &Graph::Add(const Constant &c) {
  constants.push_back(std::move(std::make_unique<Constant>(c)));
  auto new_c = constants.back().get();
  new_c->parent = this;
  return *new_c;
}

Vertex &Graph::Add(const Vertex &v) {
  if (v.IsInput()) {
    inputs.push_back(std::move(std::make_unique<Vertex>(v)));
    auto new_i = inputs.back().get();
    new_i->parent = this;
    return *new_i;
  } else if (v.IsOutput()) {
    outputs.push_back(std::move(std::make_unique<Vertex>(v)));
    auto new_o = outputs.back().get();
    new_o->parent = this;
    return *new_o;
  } else {
    throw std::runtime_error("Corrupted vertex encountered.");
  }
}

Edge &Graph::Add(const Edge &e) {
  edges.push_back(std::move(std::make_unique<Edge>(e)));
  return *edges.back().get();
}

Graph &Graph::Add(Graph g) {
  children.push_back(std::make_unique<Graph>(std::move(g)));
  return *children.back().get();
}

Constant &Graph::operator+=(Constant c) { return Add(c); }
Vertex &Graph::operator+=(Vertex v) { return Add(v); }
Edge &Graph::operator+=(Edge e) { return Add(e); }
Graph &Graph::operator+=(Graph g) { return Add(std::move(g)); }

Graph &Graph::operator<<(Constant c) {
  Add(c);
  return *this;
}

Graph &Graph::operator<<(Vertex v) {
  Add(v);
  return *this;
}

Graph &Graph::operator<<(Edge e) {
  Add(e);
  return *this;
}

Graph &Graph::operator<<(Graph g) {
  Add(std::move(g));
  return *this;
}

Graph::Graph(Graph &&other) noexcept {
  name = other.name;
  constants = std::move(other.constants);
  inputs = std::move(other.inputs);
  outputs = std::move(other.outputs);
  children = std::move(other.children);
  edges = std::move(other.edges);
  reads_memory = other.reads_memory;
  writes_memory = other.writes_memory;
}

Edge operator<<=(const Vertex &dst, const Vertex &src) {
  return Edge(&dst, &src);
}

Edge operator<<=(const Graph &dst, const Vertex &src) {
  if (dst.inputs.size() > 1) {
    throw std::runtime_error("Cannot implicitly select input of " + dst.ToString()
                                 + " because transformation has multiple inputs.");
  }
  return Edge(&dst.i(0), &src);
}

Edge operator<<=(const Vertex &dst, const Graph &src) {
  if (src.outputs.size() > 1) {
    throw std::runtime_error("Cannot implicitly select output of " + src.ToString()
                                 + " because transformation has multiple outputs.");
  }
  return Edge(&dst, &src.o(0));
}

Edge operator<<=(const Graph &dst, const Graph &src) {
  if (dst.inputs.empty()) {
    throw std::runtime_error(dst.name + " has no inputs.");
  }
  if (src.outputs.empty()) {
    throw std::runtime_error(src.name + " has no outputs.");
  }
  if (dst.inputs.size() > 1) {
    throw std::runtime_error("Cannot implicitly select input of " + dst.ToString()
                                 + " because transformation has multiple inputs: "
                                 + dst.ToStringInputs());
  }
  if (src.outputs.size() > 1) {
    throw std::runtime_error("Cannot implicitly select output of " + src.ToString()
                                 + " because transformation has multiple outputs: "
                                 + src.ToStringOutputs());
  }
  return Edge(&dst.i(0), &src.o(0));
}

Edge::Edge(const Vertex *dst, const Vertex *src) : src_(src), dst_(dst) {
  if (!src_->type->Equals(*dst_->type)) {
    throw std::runtime_error("Can't connect type " + src_->type->name() + " to " + dst_->type->name());
  }
}

Edge &Edge::named(std::string new_name) {
  this->name = std::move(new_name);
  return *this;
}

}  // namespace dag
