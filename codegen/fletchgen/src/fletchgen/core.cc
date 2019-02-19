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

#include "fletcher/common/arrow-utils.h"

#include "fletchgen/basic_types.h"
#include "fletchgen/schema.h"
#include "fletchgen/core.h"

namespace fletchgen {

using cerata::Cast;

static Port::Dir mode2dir(fletcher::Mode mode) {
  if (mode == fletcher::Mode::READ) {
    return Port::Dir::IN;
  } else {
    return Port::Dir::OUT;
  }
}

ArrowPort::ArrowPort(std::string name, std::shared_ptr<arrow::Field> field, fletcher::Mode mode, Port::Dir dir)
    : Port(std::move(name), GetStreamType(field, mode), dir), field_(std::move(field)) {}

std::shared_ptr<ArrowPort> ArrowPort::Make(std::shared_ptr<arrow::Field> field, fletcher::Mode mode, Port::Dir dir) {
  return std::make_shared<ArrowPort>(field->name(), field, mode, dir);
}

Core::Core(std::string name, std::shared_ptr<SchemaSet> schema_set)
    : Component(std::move(name)), schema_set_(std::move(schema_set)) {
  for (const auto &s : schema_set_->schema_list_) {
    auto mode = fletcher::getMode(s);
    for (const auto &f : s->fields()) {
      if (!fletcher::mustIgnore(f)) {
        AddNode(ArrowPort::Make(f, mode, mode2dir(mode)));
        AddNode(Port::Make(f->name() + "_cmd", cmd(), Port::OUT));
      }
    }
  }
}

std::shared_ptr<Core> Core::Make(std::shared_ptr<SchemaSet> schema_set) {
  return std::make_shared<Core>("uc_" + schema_set->name(), schema_set);
}

std::shared_ptr<ArrowPort> Core::GetArrowPort(std::shared_ptr<arrow::Field> field) {
  for (const auto &n : nodes_) {
    auto ap = Cast<ArrowPort>(n);
    if (ap) {
      if ((*ap)->field_ == field) {
        return *ap;
      }
    }
  }
  throw std::runtime_error("Field " + field->name() + " did not generate an ArrowPort for Core " + name() + ".");
}
std::deque<std::shared_ptr<ArrowPort>> Core::GetAllArrowPorts() {
  std::deque<std::shared_ptr<ArrowPort>> result;
  for (const auto &n : nodes_) {
    auto ap = Cast<ArrowPort>(n);
    if (ap) {
      result.push_back(*ap);
    }
  }
  return result;
}

}  // namespace fletchgen
