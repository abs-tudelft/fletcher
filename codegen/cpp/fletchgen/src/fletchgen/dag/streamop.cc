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

#include "fletchgen/dag/streamop.h"

#include <string>

#include "fletchgen/dag/dag.h"

namespace fletchgen::dag {

Transform Duplicate(const TypeRef &t, uint32_t num_outputs) {
  Transform result;
  result.name = "Duplicate";
  result += in("in", t);
  for (size_t o = 0; o < num_outputs; o++) {
    result += out("out_" + std::to_string(o), t);
  }
  return result;
}

Transform DuplicateForEach(const ListRef &l, const TypeRef &t) {
  Transform result;
  result.name = "DuplicateForEach";
  result += in("in_0", l);
  result += in("in_1", t);
  result += out("out_0", l);
  result += out("out_1", list(t));
  return result;
}

Transform Split(const StructRef &s) {
  Transform result;
  result.name = "Split";
  result += in("in", s);
  for (size_t i = 0; i < s->fields.size(); i++) {
    result += out("out_" + std::to_string(i), s->fields[i]->type);
  }
  return result;
}

Transform Merge(const std::vector<TypeRef> &ts) {
  Transform result;
  result.name = "Merge";
  std::vector<FieldRef> fields;
  for (size_t i = 0; i < ts.size(); i++) {
    result += in("in_" + std::to_string(i), ts[i]);
    fields.push_back(field("f" + std::to_string(i), ts[i]));
  }
  result += out("out", struct_(fields));
  return result;
}

Transform Buffer(const TypeRef &t, uint32_t depth) {
  Transform result;
  result.name = "Buffer";
  result += constant("depth", std::to_string(depth));
  result += in("in", t);
  result += out("out", t);
  return result;
}

}  // namespace fletchgen::dag
