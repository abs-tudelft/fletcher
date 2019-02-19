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

#include <gtest/gtest.h>

#include "test_schemas.h"

#include "cerata/vhdl/vhdl.h"
#include "cerata/dot/dot.h"

#include "fletchgen/basic_types.h"
#include "fletchgen/mantle.h"
#include "fletchgen/bus.h"
#include "fletchgen/schema.h"

namespace fletchgen {

TEST(Core, PrimRead) {
  auto schema = fletcher::test::GetPrimReadSchema();
  auto set = SchemaSet::Make("PrimRead", {schema});
  auto top = Core::Make(set);

  auto design = cerata::vhdl::Design(top);
  std::cout << design.Generate().ToString();
  cerata::dot::Grapher dot;
  std::cout << dot.GenFile(top, "graph.dot");
}

TEST(Core, StringRead) {
  auto schema = fletcher::test::GetStringReadSchema();
  auto set = SchemaSet::Make("StringRead", {schema});
  auto top = Core::Make(set);

  auto design = cerata::vhdl::Design(top);
  std::cout << design.Generate().ToString();
  cerata::dot::Grapher dot;
  std::cout << dot.GenFile(top, "graph.dot");
}

TEST(Core, ListPrim) {
  auto schema = fletcher::test::GetListUint8Schema();
  auto set = SchemaSet::Make("ListUint8", {schema});
  auto top = Core::Make(set);

  auto design = cerata::vhdl::Design(top);
  std::cout << design.Generate().ToString();
  cerata::dot::Grapher dot;
  std::cout << dot.GenFile(top, "graph.dot");
}

TEST(Core, BigSchema) {
  auto schema = fletcher::test::GetBigSchema();
  auto set = SchemaSet::Make("Big", {schema});
  auto top = Core::Make(set);

  auto design = cerata::vhdl::Design(top);
  std::cout << design.Generate().ToString();
  cerata::dot::Grapher dot;
  std::cout << dot.GenFile(top, "graph.dot");
}

}
