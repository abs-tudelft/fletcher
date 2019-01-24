// Copyright 2018 Delft University of Technology
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

#pragma once

#include <arrow/api.h>
#include <gtest/gtest.h>
#include <deque>
#include <memory>
#include <vector>

#include "test_schemas.h"

#include "../../src/vhdl/vhdl.h"
#include "../../src/dot/dot.h"

#include "../../src/fletcher_types.h"
#include "../../src/fletcher_components.h"

#include "./test_fletcher_designs.h"

namespace fletchgen {

TEST(Fletcher, BusReadArbiter) {
  auto brav = BusReadArbiter();

  auto source = vhdl::Declarator::Generate(brav);
  std::cout << source.str();
}

TEST(Fletcher, UserCore_CR_BRA) {
  // Get component
  auto top = GetColumnReadersAndArbiter();
  // Generate graph
  dot::Grapher dot;
  std::cout << dot.GenFile(top, "graph.dot");
}

TEST(Fletcher, UserCore_PrimRead) {
  auto schema = fletcher::test::GetPrimReadSchema();
  auto set = SchemaSet::Make("PrimRead", {schema});
  auto uc = UserCore::Make(set);

  dot::Grapher dot;
  std::cout << dot.GenFile(uc, "graph.dot");
}

TEST(Fletcher, UserCore_StringRead) {
  auto schema = fletcher::test::GetStringReadSchema();
  auto set = SchemaSet::Make("StringRead", {schema});
  auto uc = UserCore::Make(set);

  auto code = vhdl::Declarator::Generate(std::dynamic_pointer_cast<Graph>(uc));
  std::cout << code.str();

  dot::Grapher dot;
  std::cout << dot.GenFile(uc, "graph.dot");
}

TEST(Fletcher, UserCore_ListPrim) {
  auto schema = fletcher::test::GetListUint8Schema();
  auto set = SchemaSet::Make("ListUint8", {schema});
  auto uc = UserCore::Make(set);

  auto code = vhdl::Declarator::Generate(std::dynamic_pointer_cast<Graph>(uc));
  std::cout << code.str();

  dot::Grapher dot;
  std::cout << dot.GenFile(uc, "graph.dot");
}

TEST(Fletcher, UserCore_BigSchema) {
  auto schema = fletcher::test::GetBigSchema();
  auto set = SchemaSet::Make("Big", {schema});
  auto uc = UserCore::Make(set);

  auto code = vhdl::Declarator::Generate(std::dynamic_pointer_cast<Graph>(uc));
  std::cout << code.str();

  dot::Grapher dot;
  std::cout << dot.GenFile(uc, "graph.dot");
}

TEST(Fletcher, FletcherCore_Big) {
  auto schema = fletcher::test::GetBigSchema();
  auto set = SchemaSet::Make("Big", {schema});
  auto top = FletcherCore::Make(set);

  dot::Grapher dot;
  std::cout << dot.GenFile(Cast<Graph>(top), "graph.dot");
}

TEST(Fletcher, FletcherCore_StringRead) {
  auto schema = fletcher::test::GetStringReadSchema();
  auto set = SchemaSet::Make("StringRead", {schema});
  auto top = FletcherCore::Make(set);

  dot::Grapher dot;
  std::cout << dot.GenFile(Cast<Graph>(top), "graph.dot");
}

}