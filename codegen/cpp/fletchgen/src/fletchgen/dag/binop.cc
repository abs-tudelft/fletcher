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

#include "fletchgen/dag/binop.h"

#include <memory>

#include "fletchgen/dag/dag.h"

namespace fletchgen::dag {

Transform BinOp(const PrimRef &t0, const std::string &op, const PrimRef &t1) {
  if (t0 != t1) {
    throw std::runtime_error("Binary operation types must be equivalent.");
  }
  Transform result;
  result.name = "PrimBinOpPrim";
  result += constant("op", op);
  result += in("in_0", t0);
  result += in("in_1", t1);
  result += out("out", t0);
  return result;
}

Transform BinOp(const ListRef &t0, const std::string &op, const PrimRef &t1) {
  if (t0->item->type != t1) {
    throw std::runtime_error("Binary operation list item type and primitive"
                             " type must be equivalent.");
  }
  Transform result;
  result.name = "ListBinOpPrim";
  result += constant("op", op);
  result += in("in_0", t0);
  result += in("in_1", t1);
  result += out("out", t0);
  return result;
}

Transform BinOp(const ListRef &t0, const std::string &op, const ListRef &t1) {
  if (t0->item->type != t1->item->type) {
    throw std::runtime_error("Binary operation list item types must be equivalent.");
  }
  Transform result;
  result.name = "ListBinOpList";
  result += constant("op", op);
  result += in("in_0", t0);
  result += in("in_1", t1);
  result += out("out", t0);
  return result;
}

Transform BinOp(const StructRef &t0, const std::string &op, const PrimRef &t1) {
  // TODO(johanpel): this one is weird, as it could be expected that it would binary op every struct field.
  for (const auto &f : t0->fields) {
    if (!f->type->IsList() || f->type->AsRef<List>()->item->type != t1) {
      throw std::runtime_error("Can only perform element-wise binary operation"
                               " of struct and primitive if struct fields are "
                               "all lists of same primitive type.");
    }
  }
  Transform result;
  result.name = "StructBinOpPrim";
  result += constant("op", op);
  result += in("in_0", t0);
  result += in("in_1", t1);
  result += out("out", t0);
  return result;
}

Transform BinOp(const StructRef &t0, const std::string &op, const ListRef &t1) {
  for (const auto &f : t0->fields) {
    if (!f->type->IsList() || f->type->AsRef<List>()->item->type != t1->item->type) {
      throw std::runtime_error("Can only perform element-wise binary operation"
                               " of struct and list if struct fields are "
                               "all lists of same type.");
    }
  }
  Transform result;
  result.name = "StructBinOpList";
  result += constant("op", op);
  result += in("in_0", t0);
  result += in("in_1", t1);
  result += out("out", t0);
  return result;
}

Transform BinOp(const StructRef &t0, const std::string &op, const StructRef &t1) {
  if (t0->fields.size() != t1->fields.size()) {
    throw std::runtime_error("Field sizes must be equivalent.");
  }
  for (size_t i = 0; i < t0->fields.size(); i++) {
    if (t0->fields[i]->type != t1->fields[i]->type) {
      throw std::runtime_error("Fields of structs used in binary operation must be equivalent.");
    }
  }
  Transform result;
  result.name = "StructBinOpStruct";
  result += constant("op", op);
  result += in("in_0", t0);
  result += in("in_1", t1);
  result += out("out", t0);
  return result;
}

}  // namespace fletchgen::dag
