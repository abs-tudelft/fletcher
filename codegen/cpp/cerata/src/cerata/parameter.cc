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

#include <utility>
#include <vector>
#include <string>
#include <memory>

#include "cerata/parameter.h"
#include "cerata/pool.h"
#include "cerata/graph.h"
#include "cerata/edge.h"

namespace cerata {

Parameter::Parameter(std::string name, const std::shared_ptr<Type> &type, std::shared_ptr<Literal> default_value)
    : NormalNode(std::move(name), Node::NodeID::PARAMETER, type), default_value_(std::move(default_value)) {
  if (default_value_ == nullptr) {
    switch (type->id()) {
      case Type::ID::STRING: default_value_ = strl("");
        break;
      case Type::ID::BOOLEAN: default_value_ = booll(false);
        break;
      case Type::ID::INTEGER: default_value_ = intl(0);
        break;
      default:CERATA_LOG(ERROR, "Parameter default value can not be set implicitly.");
    }
  } else if (!default_value_->IsLiteral()) {
    CERATA_LOG(ERROR, "Parameter default value must be literal.");
  }
  Connect(this, default_value_);
}

std::shared_ptr<Parameter> parameter(const std::string &name,
                                     const std::shared_ptr<Type> &type,
                                     std::shared_ptr<Literal> default_value) {
  auto p = new Parameter(name, type, std::move(default_value));
  return std::shared_ptr<Parameter>(p);
}

std::shared_ptr<Parameter> parameter(const std::string &name, int default_value) {
  return parameter(name, integer(), intl(default_value));
}

std::shared_ptr<Parameter> parameter(const std::string &name, bool default_value) {
  return parameter(name, boolean(), booll(default_value));
}

std::shared_ptr<Parameter> parameter(const std::string &name, std::string default_value) {
  return parameter(name, string(), strl(std::move(default_value)));
}

std::shared_ptr<Parameter> parameter(const std::string &name) {
  return parameter(name, 0);
}

Node *Parameter::value() const {
  if (input()) {
    return input().value()->src();
  } else {
    CERATA_LOG(FATAL, "Parameter node " + name() + " lost input edge.");
  }
}

Parameter *Parameter::SetValue(const std::shared_ptr<Node> &value) {
  if (value->IsSignal() || value->IsPort()) {
    CERATA_LOG(FATAL, "Parameter value can not be or refer to signal or port nodes.");
  }

  Connect(this, value);
  return this;
}

std::shared_ptr<Object> Parameter::Copy() const {
  auto result = parameter(name(), type_, default_value_);
  result->meta = this->meta;
  return result;
}

void Parameter::TraceValue(std::vector<Node *> *trace) {
  trace->push_back(this);
  if (value()->IsParameter()) {
    value()->AsParameter()->TraceValue(trace);
  } else {
    trace->push_back(value());
  }
}

}  // namespace cerata
