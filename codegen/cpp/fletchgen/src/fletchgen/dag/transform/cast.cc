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

#include "fletchgen/dag/transform/cast.h"

#include <memory>

#include "fletchgen/dag/dag.h"

namespace fletchgen::dag::transform {

Transform Cast(const TypeRef &from, const TypeRef &to) {
  Transform result;
  result += in("in", from);
  result += out("out", to);
  return result;
}

}  // namespace fletchgen::dag::transform
