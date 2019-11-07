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

#include "fletchgen/dag/compop.h"

#include <memory>

#include "fletchgen/dag/composer.h"

namespace fletchgen::dag {

Transform CompOp(const PrimRef &t0, const std::string &op, const PrimRef &t1) {
  if (t0 != t1) {
    throw std::runtime_error("Comparison operation types must be equivalent.");
  }
  Transform result;
  result.name = "PrimCompOpPrim";
  result += constant("op", op);
  result += in("in_0", t0);
  result += in("in_1", t1);
  result += out("out", boolean());
  return result;
}

Transform CompOp(const ListRef &t0, const std::string &op, const PrimRef &t1) {
  if (t0->item->type != t1) {
    throw std::runtime_error("Comparison operation list item type and primitive type must be equivalent.");
  }
  Transform result;
  result.name = "ListCompOpPrim";
  result += constant("op", op);
  result += in("in_0", t0);
  result += in("in_1", t1);
  result += out("out", list(boolean()));
  return result;
}

Transform CompOp(const ListRef &t0, const std::string &op, const ListRef &t1) {
  if (t0->item->type != t1->item->type) {
    throw std::runtime_error("Comparison operation list item types must be equivalent.");
  }
  Transform result;
  result.name = "ListCompOpList";
  result += constant("op", op);
  result += in("in_0", t0);
  result += in("in_1", t1);
  result += out("out", list(boolean()));
  return result;
}

Transform CompOp(const StructRef &t0, const std::string &op, const PrimRef &t1) {
  // TODO(johanpel): this one is weird, as it could be expected that it would compare every struct field.
  std::vector<FieldRef> comp_result_fields;
  for (const auto &f : t0->fields) {
    if (!f->type->IsList() || f->type->As<List>()->item->type != t1) {
      throw std::runtime_error("Can only perform element-wise comparison operation of struct and primitive if struct "
                               "fields are all lists of same primitive type.");
    }
    comp_result_fields.push_back(field("", list(boolean())));
  }
  Transform result;
  result.name = "StructCompOpPrim";
  result += constant("op", op);
  result += in("in_0", t0);
  result += in("in_1", t1);

  return result;
}

Transform CompOp(const StructRef &t0, const std::string &op, const ListRef &t1) {
  for (const auto &f : t0->fields) {
    if (!f->type->IsList() || f->type->As<List>()->item->type != t1->item->type) {
      throw std::runtime_error("Can only perform element-wise comparison operation of struct and list if struct fields "
                               "are all lists of same type.");
    }
  }
  Transform result;
  result.name = "StructCompOpList";
  result += constant("op", op);
  result += in("in_0", t0);
  result += in("in_1", t1);
  result += out("out", t0);
  return result;
}

Transform CompOp(const StructRef &t0, const std::string &op, const StructRef &t1) {
  if (t0->fields.size() != t1->fields.size()) {
    throw std::runtime_error("Field sizes must be equivalent.");
  }
  for (size_t i = 0; i < t0->fields.size(); i++) {
    if (t0->fields[i]->type != t1->fields[i]->type) {
      throw std::runtime_error("Fields of structs used in comparison operation must be equivalent.");
    }
  }
  Transform result;
  result.name = "StructCompOpStruct";
  result += constant("op", op);
  result += in("in_0", t0);
  result += in("in_1", t1);
  result += out("out", t0);
  return result;
}

}  // namespace fletchgen::dag
