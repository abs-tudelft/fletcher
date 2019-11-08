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

Transform All(const TypeRef &t) {
  Transform result;
  result.name = "All";
  result += in("in", t);
  result += out("out", bool_());
  return result;
}

Transform Any(const TypeRef &t) {
  Transform result;
  result.name = "Any";
  result += in("in", t);
  result += out("out", bool_());
  return result;
}

Transform Min(const ListRef &t) { return Reduce("Min", t->item->type, t->item->type); }
Transform Max(const ListRef &t) { return Reduce("Max", t->item->type, t->item->type); }
Transform Sum(const ListRef &t) { return Reduce("Sum", t->item->type, t->item->type); }
Transform Prod(const ListRef &t) { return Reduce("Sum", t->item->type, t->item->type); }

Transform Mean(const ListRef &t) { return Reduce("Mean", t->item->type, t->item->type); }
Transform Median(const ListRef &t) { return Reduce("Median", t->item->type, t->item->type); }
Transform Std(const ListRef &t) { return Reduce("Std", t->item->type, t->item->type); }
Transform Mad(const ListRef &t) { return Reduce("Mad", t->item->type, t->item->type); }

Transform CumMin(const ListRef &t) { return Map("Min", t->item->type, t->item->type); }
Transform CumMax(const ListRef &t) { return Map("Max", t->item->type, t->item->type); }
Transform CumSum(const ListRef &t) { return Map("Sum", t->item->type, t->item->type); }
Transform CumProd(const ListRef &t) { return Map("Sum", t->item->type, t->item->type); }

}  // namespace dag::transform
