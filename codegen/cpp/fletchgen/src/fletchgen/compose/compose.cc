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

#include "fletchgen/compose/compose.h"

#include <arrow/api.h>

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

std::string Transform::ToStringInputs() const {
  std::stringstream str;
  for (auto i = inputs.begin(); i != inputs.end(); i++) {
    str << (*i)->name;
    if (i != inputs.end() - 1) {
      str << ", ";
    }
  }
  return str.str();
}

const Vertex &Transform::operator()(const std::string &input_name) const {
  for (const auto &i : inputs) {
    if (i->name == input_name) {
      return *i;
    }
  }
  throw std::runtime_error(this->ToString() + "\" has no input named \"" + input_name + "\". "
                               + "Inputs: " + this->ToStringInputs());
}

bool Transform::Has(const Vertex &v) const {
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

const Vertex &Transform::operator()(size_t i) const { return *inputs[i]; }

std::shared_ptr<Vertex> vertex(const std::string &name, const Any &type) {
  return std::make_shared<Vertex>(name, type);
}

std::string Transform::ToString() const {
  return "Transform[" + name + "]";
}

const Transform &Graph::Add(const Transform &t) {
  transformations.push_back(std::make_shared<Transform>(t));
  return *transformations.back();
}

const Transform &Graph::operator<<=(const Transform &t) { return Add(t); }

const Edge &Graph::Add(const Edge &e) {
  edges.push_back(std::make_shared<Edge>(e));
  return *edges.back();
}

const Edge &Graph::operator<<=(const Edge &e) { return Add(e); }

const Transform &Graph::ParentOf(const Vertex &v) const {
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

Edge operator<<(const Vertex &dst, const Transform &src) {
  return Edge(&dst, src.output.get());
};

Edge operator<<(const Transform &dst, const Transform &src) {
  if (dst.inputs.size() > 1) {
    throw std::runtime_error(
        "Cannot implicitly select input of " + dst.ToString() + " input, because transformation has multiple inputs.");
  }
  return Edge(dst.inputs[0].get(), src.output.get());
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

Transform Literal(const Constant &output_type) {
  Transform result;
  result.name = "Literal";
  result.output = vertex(output_type, output_type);
  return result;
}

Transform Source(const Any &output_type) {
  Transform result;
  result.name = "Source";
  result.output = vertex("out", output_type);
  return result;
}

Transform Sink(const Any &input_type) {
  Transform result;
  result.name = "Sink";
  result.inputs.push_back(vertex("in", input_type));
  result.has_output = false;
  return result;
}

Transform Sum(const Array &type) {
  Transform result;
  result.name = "Sum";
  result.inputs.push_back(vertex("in", type));
  result.output = vertex("out", type);
  return result;
}

Transform SplitByRegex() {
  static Transform result;
  result.name = "SplitByRegex";
  result.inputs.push_back(vertex("in", arrow::field("in", arrow::utf8())));
  result.inputs.push_back(vertex("expr", " "));
  result.output = vertex("out", arrow::field("out", arrow::utf8()));
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

Transform TuplicateWithConst(const Any &input_type,
                             const Array &output_type) {
  Transform result;
  result.name = "TuplicateWithConstant";
  result.inputs.push_back(vertex("first", input_type));
  result.inputs.push_back(vertex("second", output_type));
  std::shared_ptr<arrow::Schema> in_schema = visit(TuplicateBatchGeneratingVisitor(), input_type);
  std::shared_ptr<arrow::Schema> out_schema;
  if (!in_schema->AddField(in_schema->num_fields(), output_type, &out_schema).ok()) {
    throw std::runtime_error("Could not append constant field to Arrow schema.");
  }
  result.output = vertex("out", out_schema);
  return result;
}

Transform WhereGT(const Array &array_type, const Scalar &scalar_type) {
  Transform result;
  result.name = "WhereGreaterThan";
  result.inputs.push_back(vertex("in", array_type));
  result.inputs.push_back(vertex("val", scalar_type));
  result.output = vertex("index", Index());
  return result;
}

Transform Select(const Batch &batch_type, const std::string &field) {
  Transform result;
  result.name = "Select";
  result.inputs.push_back(vertex("in", batch_type));
  result.inputs.push_back(vertex("index", Index()));
  for (const auto &f : batch_type->fields()) {
    if (f->name() == field) {
      result.output = vertex("out", f);
    }
  }
  if (result.output == nullptr) {
    throw std::runtime_error("Field name: \"" + field + "\" does not exist on Batch: " + batch_type->ToString());
  }
  return result;
}

std::string replace(std::string str, const std::string &find, std::string replace) {
  size_t index = 0;
  while (true) {
    /* Locate the substring to replace. */
    index = str.find(find, index);
    if (index == std::string::npos) break;

    /* Make the replacement. */
    str.replace(index, find.size(), replace);

    /* Advance index forward so the next iteration doesn't pick it up as well. */
    index += replace.size();
  }
  return str;
}

inline std::string Sanitize(std::string in) {
  replace(in, "\\", "\\\\");
  replace(in, ":", "\\:");
  replace(in, "-", "\\-");
  replace(in, "\"", "\\\"");
  return in;
}

std::string DotStyle(const Edge &e) {
  return "";
}

std::string DotStyle(const Vertex &v) {
  return "";
}

std::string DotStyle(const Transform &t) {
  if (t.name == "Literal") {
    return "style = filled;\n"
           "color = \"#bfff81\";";
  } else if (t.name == "Source") {
    return "style = filled;\n"
           "color = \"#81ceff\";";
  } else if (t.name == "Sink") {
    return "style = filled;\n"
           "color = \"#f281ff\";";
  }
  return "";
}

std::string Graph::DotName(const Transform &t) const {
  std::stringstream str;
  str << reinterpret_cast<uint64_t>(&t);
  auto result = str.str();
  for (auto &c : result) {
    c += 17;
  }
  return result;
}

std::string Graph::DotLabel(const Transform &t) const {
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
    str << "  subgraph cluster_" << DotName(*t) << " {\n";
    str << "    label = \"" << DotLabel(*t) << "\";\n";
    str << "    " << DotStyle(*t) << "\n";
    // Input nodes.
    for (const auto &i : t->inputs) {
      str << "    " << DotName(*i) << " [label=\"" + DotLabel(*i) + "\","
          << DotStyle(*i) + "];\n";
    }
    // Output node.
    if (t->has_output) {
      str << "    " << DotName(*t->output)
          << " [label=\"" + DotLabel(*t->output) + "\","
          << DotStyle(*t->output) + "];\n";
    }
    str << "  }\n";
  }
  // Edges.
  for (const auto &e : edges) {
    str << "  " << DotName(*e->src) << " -> " << DotName(*e->dst)
        << " [" << DotStyle(*e) << "];\n";
  }
  str << "}";

  return str.str();
}

}  // namespace compose
