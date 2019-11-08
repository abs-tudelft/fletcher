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
#include "api.h"

namespace dag {

Graph Map(Graph f) {
  Graph result;
  if (f.inputs.size() > 1) {
    throw std::runtime_error("Map function argument can only have single input.");
  }
  if (f.outputs.size() > 1) {
    throw std::runtime_error("Map function argument can only have single input.");
  }
  if ((f.inputs.size() != 1) || (f.outputs.size() != 1)) {
    throw std::runtime_error("Map function argument must take exactly one input and one output type");
  }

  result.name = "Map(.->" + f.name + "(.))";

  auto &func = result += std::move(f);

  auto input = func.i(0);
  auto &flat = result += std::move(Flatten(input.type));
  auto output = func.o(0);
  auto &seq = result += std::move(Sequence(output.type));

  // Make copies of in and outputs.
  auto &in = result += flat("in");
  auto &out = result += seq("out");

  // Connect size stream
  result += seq("size") <<= flat("size");

  result += flat("in") <<= in;
  result += out <<= seq("out");

  result += func.i(0) <<= flat("out");
  result += seq("in") <<= func.o(0);

  return result;
}

Graph FlatMap(Graph f) {
  Graph result;
  if (f.inputs.size() > 1) {
    throw std::runtime_error("FlatMap function argument can only have single input.");
  }
  if (f.outputs.size() > 1) {
    throw std::runtime_error("FlatMap function argument can only have single input.");
  }
  if ((f.inputs.size() != 1) || (f.outputs.size() != 1)) {
    throw std::runtime_error("FlatMap function argument must take exactly one input and one output type");
  }
  if ((!f.outputs[0]->type->IsList())) {
    throw std::runtime_error("FlatMap function argument must return list.");
  }

  result.name = "FlatMap(.->" + f.name + "(.))";

  auto &func = result += std::move(f);

  auto input = func.i(0);
  auto &flat = result += std::move(Flatten(input.type));

  // Make copies of in and outputs.
  auto &in = result += flat("in");
  auto &out = result += func.o(0);

  result += flat("in") <<= in;
  result += out <<= func.o(0);

  result += func.i(0) <<= flat("out");

  return result;
}

Graph Reduce(std::string name, const TypeRef &t, const TypeRef &u) {
  Graph result;
  result.name = std::move(name);
  result += In("in", list(t));
  result += Out("out", u);
  return result;
}

Graph Flatten(const TypeRef &t, const PrimRef &index_type) {
  Graph result;
  result.name = "Flatten";
  result += In("in", list(t));
  result += Out("out", t);
  result += Out("size", index_type);
  return result;
}

Graph Sequence(const TypeRef &t, const PrimRef &index_type) {
  Graph result;
  result.name = "Sequence";
  result += In("in", t);
  result += In("size", index_type);
  result += Out("out", list(t));
  return result;
}

Graph MergeLists(const std::vector<ListRef> &list_types) {
  Graph result("Merge");
  std::vector<TypeRef> flat_types;
  flat_types.reserve(list_types.size());
  for (const auto &list_type : list_types) {
    flat_types.push_back(list_type->item->type);
  }
  auto &ma = result += Merge(flat_types);
  auto &sa = result += Sequence(ma.o(0).type);
  for (size_t t = 0; t < list_types.size(); t++) {
    auto &i = result += In("in_" + std::to_string(t), list_types[t]);
    auto &f = result += Flatten(list_types[t]->item->type);
    result += f("in") <<= i;
    result += ma.i(t) <<= f("out");
    result += sa("size") <<= f("size");
  }
  result += sa("in") <<= ma;

  auto &o = result += Out("out", sa.o(0).type);
  result += o <<= sa;
  return result;
}

}  // namespace dag
