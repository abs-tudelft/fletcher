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
#include "fletchgen/dag/composer.h"
#include "fletchgen/dag/transformations.h"

namespace fletchgen::dag {

TEST(Example, Sum) {

  auto g = Graph();

  auto source = g <<= Source("number", list(u32()));
  auto sum = g <<= Sum(u32());
  auto sink = g <<= Sink("result", u32());

  g <<= sum << source;
  g <<= sink << sum;

  DumpToDot(g);
}

TEST(Example, WhereSelect) {
  auto g = Graph();
  auto table = struct_({field("name", list(utf8())), field("age", list(u8()))});

  auto source = g <<= DesyncedSource("table", table);
  auto where = g <<= IndexOfComparison(list(u8()), ">");
  auto select = g <<= Select(list(utf8()));
  auto sink = g <<= Sink("name", utf8());

  g <<= where("in") << source.o("age");
  g <<= select("in") << source.o("name");
  g <<= select("index") << where;
  g <<= sink << select;

  DumpToDot(g);
}

TEST(Example, WordCount) {
  auto g = Graph();

  auto source = g <<= Source("sentences", list(utf8()));
  auto c = g <<= Source("c", u32());
  auto split = g <<= SplitByRegex(R"(\s)");
  auto zip = g <<= Zip(list(utf8()), u32());
  auto sink = g <<= Sink("result", list(struct_({field("word", utf8()), field("count", u32())})));

  g <<= split("in") << source;
  g <<= zip(0) << split;
  g <<= zip(1) << c;
  g <<= sink << zip;

  DumpToDot(g);
}

}  // namespace fletchgen::dag
