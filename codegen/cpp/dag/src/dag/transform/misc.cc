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

#include "dag/transform/misc.h"

#include <memory>

#include "dag/dag.h"

namespace dag::transform {

Graph Sort(const ListRef &list_type) {
  Graph result;
  result.name = "Sort";
  result += In("in", list_type);
  result += Out("out", list_type);
  return result;
}

Graph SortBy(const Struct &input, size_t field_idx) {
  Graph result;
  result.name = "SortBy";
  int i = 0;
  result += Constant("column", std::to_string(field_idx));
  for (const auto &f : input.fields) {
    result += In("in_" + std::to_string(i), f->type);
    result += Out("out_" + std::to_string(i), f->type);
    i++;
  }
  return result;
}

}  // namespace dag::transform
