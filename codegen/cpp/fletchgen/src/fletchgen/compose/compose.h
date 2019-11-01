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

#include <functional>
#include <utility>
#include <variant>

#include "fletchgen/bus.h"
#include "fletchgen/mmio.h"
#include "fletchgen/schema.h"

#pragma once

namespace fletchgen::compose {

using Constant = std::string;
using Scalar = std::shared_ptr<arrow::DataType>;
using Array = std::shared_ptr<arrow::Field>;
using Batch = std::shared_ptr<arrow::Schema>;
using Any = std::variant<Constant, Scalar, Array, Batch>;

inline Scalar Index() { return arrow::int32(); }

bool HaveSameFieldType(const arrow::Schema &a, const arrow::Schema &b);

struct Edge;

struct Vertex {
  Vertex(std::string name, Any type)
      : name(std::move(name)), type(std::move(type)) {};
  std::string name;
  Any type;
};

std::shared_ptr<Vertex> vertex(const std::string &name, const Any &type);

struct Transform {
  std::string name;
  std::vector<std::shared_ptr<Vertex>> inputs;
  std::shared_ptr<Vertex> output;
  bool has_output = true;

  const Vertex &operator()(const std::string &input_name) const;
  const Vertex &operator()(size_t i) const;

  [[nodiscard]] bool Has(const Vertex &v) const;

  [[nodiscard]] std::string ToString() const;
  [[nodiscard]] std::string ToStringInputs() const;
};

struct Edge {
  Edge(const Vertex *dst, const Vertex *src) : src(src), dst(dst) {};
  const Vertex *src;
  const Vertex *dst;
};

Edge operator<<(const Vertex &dst, const std::string &str);
Edge operator<<(const Vertex &dst, const Vertex &src);
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

  [[nodiscard]] std::string DotName(const Transform &t) const;
  [[nodiscard]] std::string DotLabel(const Transform &t) const;
  [[nodiscard]] std::string DotName(const Vertex &v) const;
  [[nodiscard]] std::string DotLabel(const Vertex &v) const;
  [[nodiscard]] std::string ToDot() const;
};

Transform Literal(const Constant &constant_type);
Transform Source(const Any &output_type);
Transform Sink(const Any &input_type);

Transform WhereGT(const Array &array_type, const Scalar &scalar_type);

Transform Select(const Batch &batch_type, const std::string &field);

Transform Sum(const Array &type);
Transform SplitByRegex();
Transform TuplicateWithConst(const Any &input_type, const Array &output_type);

}  // namespace compose
