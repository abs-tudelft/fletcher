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

bool HaveSameFieldType(const arrow::Schema &a, const arrow::Schema &b);

struct Edge;

struct Vertex {
  Vertex(std::string name, Any type)
      : name(std::move(name)), type(std::move(type)) {};
  std::string name;
  Any type;
};

struct Transformation {
  std::string name;
  std::vector<std::shared_ptr<Vertex>> inputs;
  std::shared_ptr<Vertex> output;
  bool has_output = true;

  const Vertex &operator()(const std::string &input_name) const;
  const Vertex &operator()(size_t i) const;

  [[nodiscard]] bool Has(const Vertex &v) const;

  [[nodiscard]] std::string ToStringInputs() const;
};

struct Edge {
  Edge(const Vertex *dst, const Vertex *src) : src(src), dst(dst) {};
  const Vertex *src;
  const Vertex *dst;
};

Edge operator<<(const Vertex &dst, const std::string &str);
Edge operator<<(const Vertex &dst, const Vertex &src);
Edge operator<<(const Vertex &dst, const Transformation &src);

struct Graph {
  std::string name = "FletcherDAG";
  std::vector<std::shared_ptr<Transformation>> transformations;
  std::vector<std::shared_ptr<Edge>> edges;

  const Transformation &Add(const Transformation &t);
  const Edge &Add(const Edge &e);

  const Transformation &operator<<=(const Transformation &t);
  const Edge &operator<<=(const Edge &e);

  [[nodiscard]] const Transformation &ParentOf(const Vertex &v) const;

  [[nodiscard]] std::string DotName(const Transformation &t) const;
  [[nodiscard]] std::string DotLabel(const Transformation &t) const;
  [[nodiscard]] std::string DotName(const Vertex &v) const;
  [[nodiscard]] std::string DotLabel(const Vertex &v) const;
  [[nodiscard]] std::string ToDot() const;
};

#define VERTEX_DECL_FACTORY(TYPE) Vertex TYPE##_vertex()

VERTEX_DECL_FACTORY(int8);
VERTEX_DECL_FACTORY(uint8);
VERTEX_DECL_FACTORY(int16);
VERTEX_DECL_FACTORY(uint16);
VERTEX_DECL_FACTORY(int32);
VERTEX_DECL_FACTORY(uint32);
VERTEX_DECL_FACTORY(int64);
VERTEX_DECL_FACTORY(uint64);
VERTEX_DECL_FACTORY(float8);
VERTEX_DECL_FACTORY(float16);
VERTEX_DECL_FACTORY(float32);
VERTEX_DECL_FACTORY(float64);
VERTEX_DECL_FACTORY(date32);
VERTEX_DECL_FACTORY(date64);
VERTEX_DECL_FACTORY(utf8);
VERTEX_DECL_FACTORY(byt);
VERTEX_DECL_FACTORY(offset);

Transformation Literal(const Constant &constant_type);
Transformation Source(const Any &output_type);
Transformation Sink(const Any &input_type);

Transformation Sum(const Scalar &type);
Transformation SplitByRegex();
Transformation TuplicateWithConst(const Any &input_type, const Array &output_type);

}  // namespace compose
