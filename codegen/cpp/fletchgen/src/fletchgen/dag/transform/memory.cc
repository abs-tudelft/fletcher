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

#include "fletchgen/dag/transform/memory.h"

#include <string>

#include "fletchgen/dag/dag.h"

namespace fletchgen::dag::transform {

Transform Source(const std::string &name, const TypeRef &output) {
  Transform result;
  result.name = "Source";
  result.reads_memory = true;
  result += out(name, output);
  return result;
}

Transform DesyncedSource(const std::string &name, const StructRef &output) {
  Transform result;
  result.name = "DesyncedSource";
  result.reads_memory = true;
  for (const auto &f : output->fields) {
    result += out(f->name, f->type);
  }
  return result;
}

Transform Sink(const std::string &name, const TypeRef &input) {
  Transform result;
  result.name = "Sink";
  result.writes_memory = true;
  result += in(name, input);
  return result;
}

Transform DesyncedSink(const std::string &name, const StructRef &input) {
  Transform result;
  result.name = "DesyncedSink";
  result.writes_memory = true;
  for (const auto &f : input->fields) {
    result += in(f->name, f->type);
  }
  return result;
}

} // namespace fletchgen::dag::transform
