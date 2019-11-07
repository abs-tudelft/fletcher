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

#include <gtest/gtest.h>
#include <vector>

#include "fletchgen/dag/test_utils.h"
#include "fletchgen/dag/api.h"

using namespace fletchgen::dag::transform;

namespace fletchgen::dag {

TEST(Example, Sum) {

  auto g = Graph();

  auto source = g <<= Source("number", list(u32()));
  auto sum = g <<= Sum(list(u32()));
  auto sink = g <<= Sink("result", u32());

  g <<= sum << source;
  g <<= sink << sum;

  DumpToDot(g);
}

TEST(Example, WhereSelect) {
  auto g = Graph();
  auto liststr = list(utf8());
  auto listu8 = list(u8());

  auto table = struct_({field("name", liststr), field("age", listu8)});

  auto source = g <<= DesyncedSource("table", table);
  auto limit = g <<= Source("limit", u8());
  auto where = g <<= CompOp(listu8, ">", u8());
  auto index = g <<= IndexIfTrue();
  auto select = g <<= SelectByIndex(utf8());
  auto sink = g <<= Sink("name", utf8());

  g <<= where(0) << source.o("age");
  g <<= where(1) << limit;
  g <<= index << where;
  g <<= select("in") << source.o("name");
  g <<= select("index") << index;
  g <<= sink << select;

  DumpToDot(g);
}

TEST(Example, WordCount) {
  auto strings = list(utf8());
  auto g = Graph();

  auto source = g <<= Source("sentences", strings);
  auto constant = g <<= Source("constant", u32());
  auto split = g <<= SplitByRegex(R"(\s)");
  auto dupl = g <<= DuplicateForEach(strings, u32());
  auto sink = g <<= DesyncedSink("result", struct_({field("word", list(utf8())), field("count", list(u32()))}));

  g <<= split("in") << source;
  g <<= (dupl(0) << split).named("words");
  g <<= dupl(1) << constant;
  g <<= sink(0) << dupl.o(0);
  g <<= sink(1) << dupl.o(1);

  DumpToDot(g);
}

}  // namespace fletchgen::dag
