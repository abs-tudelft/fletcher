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

#include "dag/stream.h"

#include <string>

#include "dag/dag.h"

namespace dag {

Graph Duplicate(const TypeRef &t, uint32_t num_outputs) {
  Graph result;
  result.name = "Duplicate";
  result += In("in", t);
  for (size_t o = 0; o < num_outputs; o++) {
    result += Out("out_" + std::to_string(o), t);
  }
  return result;
}

Graph DuplicateForEach(const ListRef &l, const TypeRef &t) {
  Graph result;
  result.name = "DuplicateForEach";
  result += In("in_0", l);
  result += In("in_1", t);
  result += Out("out_0", l);
  result += Out("out_1", list(t));
  return result;
}

Graph Split(const StructRef &s) {
  Graph result;
  result.name = "Split";
  result += In("in", s);
  for (size_t i = 0; i < s->fields.size(); i++) {
    result += Out("out_" + std::to_string(i), s->fields[i]->type);
  }
  return result;
}

Graph Merge(const std::vector<TypeRef> &ts) {
  Graph result;
  result.name = "Merge";
  std::vector<FieldRef> fields;
  for (size_t i = 0; i < ts.size(); i++) {
    result += In("in_" + std::to_string(i), ts[i]);
    fields.push_back(field("f" + std::to_string(i), ts[i]));
  }
  result += Out("out", struct_(fields));
  return result;
}

Graph Buffer(const TypeRef &t, uint32_t depth) {
  Graph result;
  result.name = "Buffer";
  result += Constant("depth", std::to_string(depth));
  result += In("in", t);
  result += Out("out", t);
  return result;
}

}  // namespace dag
