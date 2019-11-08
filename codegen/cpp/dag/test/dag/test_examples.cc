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

  auto source = g <<= Load("number", list(u32()));
  auto sum = g <<= Sum(list(u32()));
  auto sink = g <<= Store("result", u32());

  g <<= sum << source;
  g <<= sink << sum;

  DumpToDot(g);
}

TEST(Example, WhereSelect) {
  auto g = Graph();
  auto liststr = list(utf8());
  auto listu8 = list(u8());

  auto name = g <<= Load("name", liststr);
  auto age = g <<= Load("age", listu8);
  auto limit = g <<= Load("limit", u8());
  auto where = g <<= CompOp(listu8, ">", u8());
  auto index = g <<= IndexIfTrue();
  auto select = g <<= SelectByIndex(utf8());
  auto sink = g <<= Store("name", utf8());

  g <<= where.i(0) << age;
  g <<= where.i(1) << limit;
  g <<= index << where;
  g <<= select("in") << name;
  g <<= select("index") << index;
  g <<= sink << select;

  DumpToDot(g);
}

TEST(Example, WordCount) {
  auto strings = list(utf8());
  auto g = Graph();

  auto sentences = g <<= Load("sentences", strings);
  auto constant = g <<= Load("constant", u32());
  auto words = g <<= SplitByRegex(R"(\s)");
  auto tuple = g <<= DuplicateForEach(strings, u32());
  auto word = g <<= Store("word", list(utf8()));
  auto count = g <<= Store("count", list(u32()));

  g <<= words << sentences;
  g <<= (tuple.i(0) << words).named("words");
  g <<= tuple.i(1) << constant;
  g <<= word << tuple.o(0);
  g <<= count << tuple.o(1);

  DumpToDot(g);
}

TEST(Example, MatchCompressedText) {
  auto g = Graph();

  auto title = g <<= Load("titles", list(utf8()));
  auto compressed_texts = g <<= Load("compressed_texts", list(binary()));
  auto matched = g <<= Store("titles", list(utf8()));
  auto total = g <<= Store("total", u32());

  // This could create a sub-graph:
  auto flat_d = g <<= Flatten(binary());
  auto decompress = g <<= DecompressSnappy();
  auto match = g <<= Match("covfefe");
  auto seq_m = g <<= Sequence(bool_());

  auto split = g <<= Duplicate(list(bool_()), 2);
  auto index = g <<= IndexIfTrue();
  auto select = g <<= SelectByIndex(utf8());
  auto cast = g <<= Cast(list(bool_()), list(u32()));
  auto sum = g <<= Sum(list(u32()));

  g <<= flat_d << compressed_texts;

  g <<= decompress << flat_d("out");
  g <<= match << decompress;
  g <<= seq_m("in") << match;
  g <<= seq_m("size") << flat_d("size");

  g <<= split << seq_m;
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
