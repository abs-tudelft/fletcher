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

#include <arrow/api.h>

#include <string>
#include <functional>
#include <utility>
#include <variant>
#include <memory>
#include <vector>

#include "fletchgen/dag/types.h"

#pragma once

namespace fletchgen::dag {

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

struct Constant {
  Constant(std::string name, AnyParamFunc value) : name(std::move(name)), value(std::move(value)) {}
  std::string name;
  AnyParamFunc value;

  Constant &operator=(AnyParamFunc func);
};

std::shared_ptr<Constant> constant(const std::string &name, const AnyParamFunc &value);

struct Transform;

struct Vertex {
  Vertex(std::string name, TypeRef type) : name(std::move(name)), type(std::move(type)) {}
  virtual ~Vertex() = default;
  std::string name;
  TypeRef type;
  [[nodiscard]] virtual bool IsInput() const = 0;
  [[nodiscard]] virtual bool IsOutput() const = 0;
};

struct In : public Vertex {
  In(std::string name, TypeRef type) : Vertex(std::move(name), std::move(type)) {}
  [[nodiscard]] bool IsInput() const override { return true; }
  [[nodiscard]] bool IsOutput() const override { return false; }
};

struct Out : public Vertex {
  Out(std::string name, TypeRef type) : Vertex(std::move(name), std::move(type)) {}
  [[nodiscard]] bool IsInput() const override { return false; }
  [[nodiscard]] bool IsOutput() const override { return true; }
};

std::shared_ptr<In> in(const std::string &name, const TypeRef &type);
std::shared_ptr<Out> out(const std::string &name, const TypeRef &type);

struct Edge {
  Edge(const Vertex *dst, const Vertex *src) : src_(src), dst_(dst) {
    if (src_->type->id != dst_->type->id) {
      throw std::runtime_error("Can't connect type " + src_->type->name + " to " + dst_->type->name);
    }
  }
  const Vertex *src_;
  const Vertex *dst_;
};

struct Transform {
  std::string name;
  std::vector<std::shared_ptr<Constant>> constants;
  std::vector<std::shared_ptr<In>> inputs;
  std::vector<std::shared_ptr<Out>> outputs;

  [[nodiscard]] Constant &c(const std::string &constant_name) const;
  [[nodiscard]] const Vertex &o(const std::string &output_name) const;
  [[nodiscard]] const Vertex &o(size_t i) const;

  const Vertex &operator()(const std::string &input_name) const;
  const Vertex &operator()(size_t i) const;
  Transform &operator+=(const std::shared_ptr<Constant> &c);
  Transform &operator+=(const std::shared_ptr<Vertex> &v);

  [[nodiscard]] bool Has(const Vertex &v) const;

  [[nodiscard]] std::string ToString() const;
  [[nodiscard]] std::string ToStringInputs() const;
  [[nodiscard]] std::string ToStringOutputs() const;
};

void operator<<(const Constant &dst, const std::string &src);

Edge operator<<(const Vertex &dst, const Vertex &src);
Edge operator<<(const Transform &dst, const Vertex &src);
Edge operator<<(const Vertex &dst, const Transform &src);
Edge operator<<(const Transform &dst, const Transform &src);

struct Graph {
  std::string name = "FletcherDAG";
  std::vector<std::shared_ptr<Transform>> transformations;
  std::vector<std::shared_ptr<Edge>> edges;

  const Transform &Add(const Transform &t);
  const Edge &Add(const Edge &e);

  const Transform &operator<<=(const Transform &t);
  const Edge &operator<<=(const Edge &e);

  [[nodiscard]] const Transform &ParentOf(const Vertex &v) const;
};

Transform Source(const std::string &name, const TypeRef &output);
Transform DesyncedSource(const std::string &name, const StructRef &output);

Transform Sink(const std::string &name, const TypeRef &input);
Transform DesyncedSink(const std::string &name, const StructRef &input);

Transform Duplicate(const TypeRef &input, uint32_t num_outputs);
Transform Split(const StructRef &input);
Transform Merge(const std::vector<TypeRef> &inputs);

}  // namespace fletchgen::dag
