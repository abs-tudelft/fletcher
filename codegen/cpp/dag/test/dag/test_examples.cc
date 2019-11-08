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

#include "dag/test_utils.h"
#include "dag/api.h"

using namespace dag::transform;

namespace dag {

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

  g <<= where.i(0) << source("age");
  g <<= where.i(1) << limit;
  g <<= index << where;
  g <<= select("in") << source("name");
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
  g <<= (dupl.i(0) << split).named("words");
  g <<= dupl.i(1) << constant;
  g <<= sink.i(0) << dupl.o(0);
  g <<= sink.i(1) << dupl.o(1);

  DumpToDot(g);
}

TEST(Example, MatchCompressedText) {
  auto g = Graph();

  auto title = g <<= Source("title", list(utf8()));
  auto text = g <<= Source("text", list(binary()));
  auto matched = g <<= Sink("title", list(utf8()));
  auto total = g <<= Sink("total", u32());

  // this should create a sub-graph:
  auto map = g <<= Map(Match("covfefe"));
  auto split = g <<= Duplicate(list(boolean()), 2);
  auto index = g <<= IndexIfTrue();
  auto select = g <<= SelectByIndex(utf8());
  auto cast = g <<= Cast(list(boolean()), list(u32()));
  auto sum = g <<= Sum(list(u32()));

  g <<= map("in_0") << text;
  g <<= split << map;
  g <<= index << split.o(0);
  g <<= select("index") << index;
  g <<= select("in") << title;
  g <<= matched << select;

  g <<= cast << split.o(1);
  g <<= sum << cast;
  g <<= total << sum;

  DumpToDot(g);
}

}  // namespace dag
