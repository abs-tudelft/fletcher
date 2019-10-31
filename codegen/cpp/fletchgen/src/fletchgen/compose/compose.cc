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

#include "compose.h"

namespace fletchgen::compose {

bool HaveSameFieldType(const arrow::Schema &a, const arrow::Schema &b) {
  if (a.num_fields() != b.num_fields()) {
    return false;
  }
  for (int i = 0; i < a.num_fields(); i++) {
    if (!a.field(i)->type()->Equals(b.field(i)->type())) {
      return false;
    }
  }
  return true;
}

#define VERTEX_IMPL_FACTORY(TYPE) Vertex TYPE##_vertex() { return Vertex(#TYPE, arrow :: TYPE()); }

VERTEX_IMPL_FACTORY(int8)
VERTEX_IMPL_FACTORY(uint8)
VERTEX_IMPL_FACTORY(int16)
VERTEX_IMPL_FACTORY(uint16)
VERTEX_IMPL_FACTORY(int32)
VERTEX_IMPL_FACTORY(uint32)
VERTEX_IMPL_FACTORY(int64)
VERTEX_IMPL_FACTORY(uint64)
VERTEX_IMPL_FACTORY(float16)
VERTEX_IMPL_FACTORY(float32)
VERTEX_IMPL_FACTORY(float64)
VERTEX_IMPL_FACTORY(date32)
VERTEX_IMPL_FACTORY(date64)
VERTEX_IMPL_FACTORY(utf8)
VERTEX_IMPL_FACTORY(binary)

std::string Transformation::ToStringInputs() const {
  std::stringstream str;
  for (auto i = inputs.begin(); i != inputs.end(); i++) {
    str << (*i)->name;
    if (i != inputs.end() - 1) {
      str << ", ";
    }
  }
  return str.str();
}

const Vertex &Transformation::operator()(const std::string &input_name) const {
  for (const auto &i : inputs) {
    if (i->name == input_name) {
      return *i;
    }
  }
  throw std::runtime_error(
      "Transformation \"" + name + "\" has no input named \"" + input_name + "\". Inputs: " + ToStringInputs());
}

bool Transformation::Has(const Vertex &v) const {
  if (has_output) {
    if (output.get() == &v) { return true; }
  }
  for (const auto &i : inputs) {
    if (i.get() == &v) {
      return true;
    }
  }
  return false;
}

const Vertex &Transformation::operator()(size_t i) const { return *inputs[i]; }

const Transformation &Graph::Add(const Transformation &t) {
  transformations.push_back(std::make_shared<Transformation>(t));
  return *transformations.back();
}

const Transformation &Graph::operator<<=(const Transformation &t) { return Add(t); }

const Edge &Graph::Add(const Edge &e) {
  edges.push_back(std::make_shared<Edge>(e));
  return *edges.back();
}

const Edge &Graph::operator<<=(const Edge &e) { return Add(e); }

const Transformation &Graph::ParentOf(const Vertex &v) const {
  for (const auto &t : transformations) {
    if (t->Has(v)) {
      return *t;
    }
  }
  throw std::runtime_error("Vertex \"" + v.name + "\" does not exist in transformations of Graph \"" + name + "\"");
}

Edge operator<<(const Vertex &dst, const Vertex &src) {
  return Edge(&dst, &src);
};

Edge operator<<(const Vertex &dst, const Transformation &src) {
  return Edge(&dst, src.output.get());
};

struct TypeNameVisitor {
  std::string operator()(const Constant &s) { return "const"; }
  std::string operator()(const Scalar &s) { return s->ToString(); }
  std::string operator()(const Array &a) { return "[" + a->ToString() + "]"; }
  std::string operator()(const Batch &b) {
    std::stringstream str;
    str << "{";
    auto fields = b->fields();
    for (const auto &f : fields) {
      str << f->ToString();
      if (&f != &fields.back()) {
        str << ", ";
      }
    }
    str << "}";
    return str.str();
  }
};

Transformation Literal(const Constant &output_type) {
  Transformation result;
  result.name = "Literal";
  result.output = std::make_shared<Vertex>(output_type, output_type);
  return result;
}


Transformation Source(const Any &output_type) {
  Transformation result;
  result.name = "Source";
  result.output = std::make_shared<Vertex>("out", output_type);
  return result;
}

Transformation Sink(const Any &input_type) {
  Transformation result;
  result.name = "Sink";
  result.inputs.push_back(std::make_shared<Vertex>("in", input_type));
  result.has_output = false;
  return result;
}

Transformation Sum(const Scalar &type) {
  Transformation result;
  result.name = "Sum";
  result.inputs.push_back(std::make_shared<Vertex>("in", type));
  result.output = std::make_shared<Vertex>("out", type);
  return result;
}

Transformation SplitByRegex() {
  static Transformation result;
  result.name = "SplitByRegex";
  result.inputs.push_back(std::make_shared<Vertex>("in", arrow::field("in", arrow::utf8())));
  result.inputs.push_back(std::make_shared<Vertex>("expr", " "));
  result.output = std::make_shared<Vertex>("out", arrow::field("out", arrow::utf8()));
  return result;
}

struct SchemaGeneratingVisitor {
  std::shared_ptr<arrow::Schema> operator()(const Constant &s) {
    return arrow::schema({arrow::field(s, arrow::utf8(), false)});
  }
  std::shared_ptr<arrow::Schema> operator()(const Scalar &s) {
    return arrow::schema({arrow::field(s->name(), s, false)});
  }
  std::shared_ptr<arrow::Schema> operator()(const Array &a) {
    return arrow::schema({a});
  }
  std::shared_ptr<arrow::Schema> operator()(const Batch &b) {
    return b;
  }
};

struct TuplicateBatchGeneratingVisitor {
  Batch operator()(const Constant &s) {
    throw std::runtime_error("Tuplicating constant is not allowed or sensible.");
  }
  Batch operator()(const Scalar &s) {
    throw std::runtime_error("Tuplicating scalar is not allowed or sensible.");
  }
  Batch operator()(const Array &a) {
    return arrow::schema({a});
  }
  Batch operator()(const Batch &b) {
    return b;
  }
};

Transformation TuplicateWithConst(const Any &input_type,
                                  const Array &output_type) {
  Transformation result;
  result.name = "TuplicateWithConstant";
  result.inputs.push_back(std::make_shared<Vertex>("first", input_type));
  result.inputs.push_back(std::make_shared<Vertex>("second", output_type));
  std::shared_ptr<arrow::Schema> in_schema = visit(TuplicateBatchGeneratingVisitor(), input_type);
  std::shared_ptr<arrow::Schema> out_schema;
  if (!in_schema->AddField(in_schema->num_fields(), output_type, &out_schema).ok()) {
    throw std::runtime_error("Could not append constant field to Arrow schema.");
  }
  result.output = std::make_shared<Vertex>("out", out_schema);
  return result;
}

inline std::string Sanitize(std::string in) {
  std::replace(in.begin(), in.end(), '\\', '_');
  std::replace(in.begin(), in.end(), ':', '_');
  std::replace(in.begin(), in.end(), '-', '_');
  std::replace(in.begin(), in.end(), '"', '_');
  return in;
}

std::string Graph::DotName(const Transformation &t) const {
  std::stringstream str;
  str << reinterpret_cast<uint64_t>(&t);
  auto result = str.str();
  for (auto &c : result) {
    c += 17;
  }
  return result;
}

std::string Graph::DotLabel(const Transformation &t) const {
  return Sanitize(t.name);
}

std::string Graph::DotName(const Vertex &v) const {
  std::stringstream str;
  str << reinterpret_cast<uint64_t>(&v);
  auto result = str.str();
  for (auto &c : result) {
    c += 17;
  }
  return result;
}

std::string Graph::DotLabel(const Vertex &v) const {
  auto result = Sanitize(v.name);
  result += "\\n" + visit(TypeNameVisitor(), v.type);
  return result;
}

std::string Graph::ToDot() const {
  std::stringstream str;
  // Header
  str << "digraph {\n";
  // Transformations.
  for (const auto &t : transformations) {
    str << "  subgraph cluster_" + DotName(*t) << " {\n";
    str << "    label = \"" + DotLabel(*t) + "\";\n";
    // Input nodes.
    for (const auto &i : t->inputs) {
      str << "    " << DotName(*i) << " [label=\"" + DotLabel(*i) + "\"];\n";
    }
    // Output node.
    if (t->has_output) {
      str << "    " << DotName(*t->output) << " [label=\"" + DotLabel(*t->output) + "\"];\n";
    }
    str << "  }\n";
  }
  // Edges.
  for (const auto &e : edges) {
    str << "  " << DotName(*e->src) << " -> " << DotName(*e->dst) << ";\n";
  }
  str << "}";

  return str.str();
}

}  // namespace compose
