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
#include <sstream>

#include "fletchgen/dag/types.h"

namespace fletchgen::dag {

PrimRef prim(const std::string &name, uint32_t width) { return std::make_shared<Prim>(name, width); }

#define PRIM_IMPL_FACTORY(NAME, WIDTH) PrimRef NAME() { static PrimRef result = prim(#NAME, WIDTH); return result; }

PRIM_IMPL_FACTORY(boolean, 8)
PRIM_IMPL_FACTORY(i8, 8)
PRIM_IMPL_FACTORY(i16, 16)
PRIM_IMPL_FACTORY(i32, 32)
PRIM_IMPL_FACTORY(i64, 64)
PRIM_IMPL_FACTORY(u8, 8)
PRIM_IMPL_FACTORY(u16, 16)
PRIM_IMPL_FACTORY(u32, 32)
PRIM_IMPL_FACTORY(u64, 64)
PRIM_IMPL_FACTORY(f16, 16)
PRIM_IMPL_FACTORY(f32, 32)
PRIM_IMPL_FACTORY(f64, 64)
PRIM_IMPL_FACTORY(idx32, 32)
PRIM_IMPL_FACTORY(idx64, 64)

FieldRef field(const std::string &name, const TypeRef &type) { return std::make_shared<Field>(name, type); }

ListRef list(const std::string &name, const FieldRef &item) {
  return std::make_shared<List>(name, item);
}

ListRef list(const std::string &name, const TypeRef &item_type) {
  return std::make_shared<List>(name, field("item", item_type));
}

ListRef list(const TypeRef &item_type) {
  return std::make_shared<List>("list<" + item_type->name + ">", field("item", item_type));
}

StructRef struct_(const std::vector<FieldRef> &fields) {
  std::stringstream name;
  name << "struct<";
  for (const auto &f : fields) {
    name << f->name << ": " << f->type->name;
    if (f != fields.back()) {
      name << ", ";
    }
  }
  name << ">";
  return std::make_shared<Struct>(name.str(), fields);
}

StructRef struct_(const std::string &name, const std::vector<FieldRef> &fields) {
  return std::make_shared<Struct>(name, fields);
}

ListRef utf8() { return list("utf8", field("char", u8())); }
ListRef bin() { return list("binary", field("byte", u8())); }

}  // namespace fletchgen::dag
