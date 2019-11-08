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

#include "dag/memory.h"

#include <string>

#include "dag/dag.h"

namespace dag {

Graph Load(const std::string &name, const TypeRef &output) {
  Graph result;
  result.name = "Load";
  result.reads_memory = true;
  result += Out(name, output);
  return result;
}

Graph Store(const std::string &name, const TypeRef &input) {
  Graph result;
  result.name = "Store";
  result.writes_memory = true;
  result += In(name, input);
  return result;
}

} // namespace dag
