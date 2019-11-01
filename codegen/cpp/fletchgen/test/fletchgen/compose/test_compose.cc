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

TEST(Compose, Sum) {
  auto num_scalar = arrow::int32();
  auto num_array = arrow::field("number", num_scalar);

  auto g = Graph();

  auto source = g <<= Source(num_array);
  auto sum = g <<= Sum(num_array);
  auto sink = g <<= Sink(num_scalar);

  g <<= sum << source;
  g <<= sink << sum;

  std::cout << std::endl << g.ToDot() << std::endl;
  std::ofstream("dag.dot") << g.ToDot();
}

TEST(Compose, WhereSelect) {
  auto name = arrow::field("name", arrow::utf8());
  auto age = arrow::field("age", arrow::uint8());
  auto table = arrow::schema({name, age});
  auto g = Graph();

  auto age_limit = g <<= Literal(Constant("21"));
  auto source = g <<= Source(table);
  auto where = g <<= WhereGT(age, arrow::uint8());
  auto select = g <<= Select(table, "name");
  auto sink = g <<= Sink(name);

  g <<= where("in") << source;
  g <<= where("val") << age_limit;
  g <<= select("in") << source;
  g <<= select("index") << where;
  g <<= sink << select;

  std::cout << std::endl << g.ToDot() << std::endl;
  std::ofstream("dag.dot") << g.ToDot();
}

TEST(Compose, WordCount) {
  auto tweet = arrow::field("tweet", arrow::utf8());
  auto word = arrow::field("word", arrow::utf8());
  auto count = arrow::field("count", arrow::int32());

  auto g = Graph();

  auto second = g <<= Literal(Constant("1"));
  auto expr = g <<= Literal(Constant("\\s"));
  auto source = g <<= Source(tweet);
  auto first = g <<= SplitByRegex();
  auto tuple = g <<= TuplicateWithConst(word, count);
  auto sink = g <<= Sink(arrow::schema({word, count}));

  g <<= first("in") << source;
  g <<= first("expr") << expr;
  g <<= tuple("first") << first;
  g <<= tuple("second") << second;
  g <<= sink << tuple;

  std::cout << std::endl << g.ToDot() << std::endl;
  std::ofstream("dag.dot") << g.ToDot();

}

}  // namespace fletchgen::compose
