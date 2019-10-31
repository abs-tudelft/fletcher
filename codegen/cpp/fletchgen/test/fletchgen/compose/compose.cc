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

#include <arrow/api.h>
#include <gtest/gtest.h>
#include <vector>
#include <memory>
#include <iostream>

#include "fletchgen/compose/compose.h"

namespace fletchgen::compose {

TEST(Compose, SchemaCompat) {
  auto a = arrow::schema({arrow::field("x", arrow::int64(), false)});
  auto b = arrow::schema({arrow::field("y", arrow::int64(), false)});

  ASSERT_TRUE(HaveSameFieldType(*a, *b));

  auto c = arrow::schema({arrow::field("x", arrow::int64(), false)});
  auto d = arrow::schema({arrow::field("y", arrow::uint64(), false)});

  ASSERT_FALSE(HaveSameFieldType(*c, *d));
}

TEST(Compose, DAG) {
  auto tweet = arrow::field("tweet", arrow::utf8());
  auto word = arrow::field("word", arrow::utf8());
  auto count = arrow::field("count", arrow::int32());

  auto g = Graph();

  auto scnd = g <<= Literal(Constant("1"));
  auto expr = g <<= Literal(Constant("\\s"));
  auto src = g <<= Source(tweet);
  auto a = g <<= SplitByRegex();
  auto b = g <<= TuplicateWithConst(tweet, count);
  auto snk = g <<= Sink(arrow::schema({word, count}));

  g <<= a("in") << src;
  g <<= a("expr") << expr;
  g <<= b("first") << a;
  g <<= b("second") << scnd;
  g <<= snk("in") << b;

  std::cout << std::endl << g.ToDot() << std::endl;
  std::ofstream("dag.dot") << g.ToDot();

}

}  // namespace fletchgen::compose
