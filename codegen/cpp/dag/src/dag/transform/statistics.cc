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

#include "dag/transform/statistics.h"

#include "dag/meta.h"

#include "dag/dag.h"

namespace dag::transform {

Graph All(const TypeRef &t) {
  Graph result;
  result.name = "All";
  result += In("in", t);
  result += Out("out", bool_());
  return result;
}

Graph Any(const TypeRef &t) {
  Graph result;
  result.name = "Any";
  result += In("in", t);
  result += Out("out", bool_());
  return result;
}

Graph Min(const ListRef &t) { return Reduce("Min", t->item->type, t->item->type); }
Graph Max(const ListRef &t) { return Reduce("Max", t->item->type, t->item->type); }
Graph Sum(const ListRef &t) { return Reduce("Sum", t->item->type, t->item->type); }
Graph Prod(const ListRef &t) { return Reduce("Sum", t->item->type, t->item->type); }

Graph Mean(const ListRef &t) { return Reduce("Mean", t->item->type, t->item->type); }
Graph Median(const ListRef &t) { return Reduce("Median", t->item->type, t->item->type); }
Graph Std(const ListRef &t) { return Reduce("Std", t->item->type, t->item->type); }
Graph Mad(const ListRef &t) { return Reduce("Mad", t->item->type, t->item->type); }

}  // namespace dag::transform
