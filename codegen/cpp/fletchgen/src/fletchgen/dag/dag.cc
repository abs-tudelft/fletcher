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

#include "fletchgen/dag/dag.h"

#include <sstream>

#include "fletchgen/dag/types.h"

namespace fletchgen::dag {

std::shared_ptr<Constant> constant(const std::string &name, const AnyParamFunc &value) {
  return std::make_shared<Constant>(name, value);
}

Constant &Constant::operator=(AnyParamFunc func) {
  value = std::move(func);
  return *this;
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

std::string Transform::ToStringOutputs() const {
  std::stringstream str;
  for (auto i = outputs.begin(); i != outputs.end(); i++) {
    str << (*i)->name;
    if (i != outputs.end() - 1) {
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
  for (const auto &i : inputs) {
    if (i.get() == &v) {
      return true;
    }
  }
  for (const auto &o : outputs) {
    if (o.get() == &v) {
      return true;
    }
  }
  return false;
}

const Vertex &Transform::operator()(size_t i) const {
  if (i > inputs.size()) {
    throw std::runtime_error("Index " + std::to_string(i) + " out of bounds. Transformation has "
                                 + std::to_string(inputs.size()) + " inputs.");
  }
  return *inputs[i];
}

std::shared_ptr<In> in(const std::string &name, const TypeRef &type) {
  return std::make_shared<In>(name, type);
}

std::shared_ptr<Out> out(const std::string &name, const TypeRef &type) {
  return std::make_shared<Out>(name, type);
}

std::string Transform::ToString() const {
  return "Transform[" + name + "]";
}

Constant &Transform::c(const std::string &constant_name) const {
  for (const auto &c : constants) {
    if (c->name == constant_name) {
      return *c;
    }
  }
  throw std::runtime_error(this->ToString() + "\" has no constant named \"" + constant_name + "\". "
                               + "Inputs: " + this->ToStringInputs());
}

const Vertex &Transform::o(size_t i) const {
  if (i > outputs.size()) {
    throw std::runtime_error("Index " + std::to_string(i) + " out of bounds. Transformation has "
                                 + std::to_string(outputs.size()) + " outputs.");
  }
  return *outputs[i];
}

const Vertex &Transform::o(const std::string &output_name) const {
  for (const auto &o : outputs) {
    if (o->name == output_name) {
      return *o;
    }
  }
  throw std::runtime_error(this->ToString() + "\" has no output named \"" + output_name + "\". "
                               + "Outputs: " + this->ToStringOutputs());
}

Transform &Transform::operator+=(const std::shared_ptr<Vertex> &v) {
  if (v->IsInput()) {
    inputs.push_back(std::dynamic_pointer_cast<In>(v));
  } else if (v->IsOutput()) {
    outputs.push_back(std::dynamic_pointer_cast<Out>(v));
  }
  return *this;
}

Transform &Transform::operator+=(const std::shared_ptr<Constant> &c) {
  constants.push_back(c);
  return *this;
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
}

Edge operator<<(const Transform &dst, const Vertex &src) {
  if (dst.inputs.size() > 1) {
    throw std::runtime_error("Cannot implicitly select input of " + dst.ToString()
                                 + " because transformation has multiple inputs.");
  }
  return Edge(dst.inputs[0].get(), &src);
}

Edge operator<<(const Vertex &dst, const Transform &src) {
  if (src.outputs.size() > 1) {
    throw std::runtime_error("Cannot implicitly select output of " + src.ToString()
                                 + " because transformation has multiple outputs.");
  }
  return Edge(&dst, src.outputs[0].get());
}

Edge operator<<(const Transform &dst, const Transform &src) {
  if (dst.inputs.empty()) {
    throw std::runtime_error(dst.name + " has no inputs.");
  }
  if (src.outputs.empty()) {
    throw std::runtime_error(src.name + " has no outputs.");
  }
  if (dst.inputs.size() > 1) {
    throw std::runtime_error("Cannot implicitly select input of " + dst.ToString()
                                 + " because transformation has multiple inputs.");
  }
  if (src.outputs.size() > 1) {
    throw std::runtime_error("Cannot implicitly select output of " + src.ToString()
                                 + " because transformation has multiple outputs.");
  }
  return Edge(dst.inputs[0].get(), src.outputs[0].get());
}

Edge::Edge(const Vertex *dst, const Vertex *src) : src_(src), dst_(dst) {
  if (!src_->type->Equals(*dst_->type)) {
    throw std::runtime_error("Can't connect type " + src_->type->name + " to " + dst_->type->name);
  }
}

Edge &Edge::named(std::string new_name) {
  this->name = std::move(new_name);
  return *this;
}

}  // namespace fletchgen::dag
