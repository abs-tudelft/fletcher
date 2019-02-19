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

#include "./test_schemas.h"

#include "cerata/vhdl/vhdl.h"
#include "cerata/dot/dot.h"

#include "fletchgen/basic_types.h"
#include "fletchgen/mantle.h"
#include "fletchgen/bus.h"
#include "fletchgen/schema.h"

#include "test_designs.h"

namespace fletchgen {

TEST(Hardware, BusReadArbiter) {
  auto brav = BusReadArbiter();

  auto source = cerata::vhdl::Decl::Generate(brav);
  std::cout << source.ToString();
}

TEST(Hardware, Core_CR_BRA) {
  // Get component
  auto top = GetColumnReadersAndArbiter();
  // Generate graph
  cerata::dot::Grapher dot;
  std::cout << dot.GenFile(top, "graph.dot");
}

TEST(Hardware, Core_PrimRead) {
  auto schema = fletcher::test::GetPrimReadSchema();
  auto set = SchemaSet::Make("PrimRead", {schema});
  auto top = Core::Make(set);

  std::cout << cerata::vhdl::Design::Generate(top).ToString();
  cerata::dot::Grapher dot;
  std::cout << dot.GenFile(top, "graph.dot");
}

TEST(Hardware, Core_StringRead) {
  auto schema = fletcher::test::GetStringReadSchema();
  auto set = SchemaSet::Make("StringRead", {schema});
  auto top = Core::Make(set);

  std::cout << cerata::vhdl::Design::Generate(top).ToString();
  cerata::dot::Grapher dot;
  std::cout << dot.GenFile(top, "graph.dot");
}

TEST(Hardware, Core_ListPrim) {
  auto schema = fletcher::test::GetListUint8Schema();
  auto set = SchemaSet::Make("ListUint8", {schema});
  auto top = Core::Make(set);

  std::cout << cerata::vhdl::Design::Generate(top).ToString();
  cerata::dot::Grapher dot;
  std::cout << dot.GenFile(top, "graph.dot");
}

TEST(Hardware, Core_BigSchema) {
  auto schema = fletcher::test::GetBigSchema();
  auto set = SchemaSet::Make("Big", {schema});
  auto top = Core::Make(set);

  std::cout << cerata::vhdl::Design::Generate(top).ToString();
  cerata::dot::Grapher dot;
  std::cout << dot.GenFile(top, "graph.dot");
}

TEST(Hardware, Mantle_Big) {
  auto schema = fletcher::test::GetBigSchema();
  auto set = SchemaSet::Make("Big", {schema});
  auto top = Mantle::Make(set);

  std::cout << cerata::vhdl::Design::Generate(top).ToString();
  cerata::dot::Grapher dot;
  std::cout << dot.GenFile(top, "graph.dot");
}

TEST(Hardware, Mantle_StringRead) {
  auto schema = fletcher::test::GetStringReadSchema();
  auto set = SchemaSet::Make("StringRead", {schema});
  auto top = Mantle::Make(set);

  std::cout << cerata::vhdl::Design::Generate(top).ToString();
  cerata::dot::Grapher dot;
  std::cout << dot.GenFile(top, "graph.dot");
}

}
