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

#include "fletchgen/dag/indexop.h"

#include <string>

#include "fletchgen/dag/dag.h"

namespace fletchgen::dag {

Transform IndexIfTrue(const PrimRef &index_type) {
  Transform result;
  result.name = "IndexIfTrue";
  result += in("in", list(boolean()));
  result += out("out", list(index_type));
  return result;
}

Transform SelectByIndex(const TypeRef &t, const PrimRef &index_type) {
  Transform result;
  result.name = "FilterByIndex";
  result += in("in", list(t));
  result += in("index", list(index_type));
  result += out("out", t);
  return result;
}

}  // namespace fletchgen::dag
