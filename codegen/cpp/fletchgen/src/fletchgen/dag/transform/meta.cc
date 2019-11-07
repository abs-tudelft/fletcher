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

#include "fletchgen/dag/transform/meta.h"

#include <memory>
#include <utility>

#include "fletchgen/dag/dag.h"

namespace fletchgen::dag::transform {

Transform Map(std::string name, const TypeRef &t, const TypeRef &u) {
  Transform result;
  result.name = std::move(name);
  result += in("in", list(t));
  result += out("out", list(u));
  return result;
}

Transform Reduce(std::string name, const TypeRef &t, const TypeRef &u) {
  Transform result;
  result.name = std::move(name);
  result += in("in", list(t));
  result += out("out", u);
  return result;
}

Transform SplitByRegex(const std::string &regex) {
  Transform result;
  result.name = "SplitByRegex";
  result.constants.push_back(constant("expr", regex));
  result += in("in", list(utf8()));
  result += out("out", list(utf8()));
  return result;
}

Transform Sort(const ListRef &list_type) {
  Transform result;
  result.name = "Sort";
  result += in("in", list_type);
  result += out("out", list_type);
  return result;
}

Transform SortBy(const Struct &input, size_t field_idx) {
  Transform result;
  result.name = "SortBy";
  int i = 0;
  result += constant("column", std::to_string(field_idx));
  for (const auto &f : input.fields) {
    result += in("in_" + std::to_string(i), f->type);
    result += out("out_" + std::to_string(i), f->type);
    i++;
  }
  return result;
}

}  // namespace fletchgen::dag::transform
