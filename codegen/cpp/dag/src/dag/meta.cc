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

#include "dag/meta.h"

#include <memory>
#include <utility>

#include "dag/dag.h"

namespace dag {

Transform Map(std::string name, const TypeRef &t, const TypeRef &u) {
  Transform result;
  result.name = std::move(name);
  result += in("in", list(t));
  result += out("out", list(u));
  return result;
}

Transform Map(const Transform &function) {
  Transform result;
  result.name = "Map(" + function.name + ")";

  for (const auto& co : function.constants) {
    result += constant(co->name, co->value);
  }

  for (size_t i = 0; i < function.inputs.size(); i++) {
    auto t = function.inputs[i]->type;
    result += in("in_" + std::to_string(i), list(t));
  }
  for (size_t o = 0; o < function.outputs.size(); o++) {
    auto t = function.outputs[o]->type;
    result += out("out_" + std::to_string(o), list(t));
  }
  return result;
}

Transform Reduce(std::string name, const TypeRef &t, const TypeRef &u) {
  Transform result;
  result.name = std::move(name);
  result += in("in", list(t));
  result += out("out", u);
  return result;
}

}  // namespace dag
