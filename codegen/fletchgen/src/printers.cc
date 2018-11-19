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

#include <iostream>

#include "./printers.h"

using vhdl::t;

namespace fletchgen {

std::string getFieldInfoString(const std::shared_ptr<arrow::Field> &field, ArrowStream *parent) {
  std::string ret;

  int epc = fletcher::getEPC(field);

  int l = 0;

  if (parent != nullptr) {
    l = parent->depth() + 1;
  }

  ret += t(l) + "<Field>: ";
  ret += field->name() + "\n";

  if (parent != nullptr) {
    if (parent->isStruct())
      ret += t(l + 1) + "Struct child.\n";
    if (parent->isList())
      ret += t(l + 1) + "List child.\n";
  }
  if (field->nullable())
    ret += t(l + 1) + "Nullable.\n";

  ret += t(l + 1) + "Type: " + field->type()->ToString() + "\n";
  ret += t(l + 1) + "Width: " + getWidth(field->type().get()).toString() + "\n";

  if ((epc != 1) && (field->type()->id() != arrow::Type::BINARY) && (field->type()->id() != arrow::Type::STRING)) {
    ret += t(l + 1) + "EPC: " + std::to_string(epc) + "\n";
  }

  if (field->type()->num_children() > 0) {
    ret += t(l + 1) + "Children: " + std::to_string(field->type()->num_children()) + "\n";
  }

  ret.pop_back();
  return ret;
}

}  // namespace fletchgen
