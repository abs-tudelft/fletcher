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

static void TestReadKernel(const std::string& test_name, const std::shared_ptr<arrow::Schema>& schema) {
  auto fs = FletcherSchema::Make(schema);
  auto rbr = RecordBatchReader::Make(fs);
  auto top = Kernel::Make("Test" + test_name, {rbr});
  auto design = cerata::vhdl::Design(top);
  std::cout << design.Generate().ToString();
  cerata::dot::Grapher dot;
  std::cout << dot.GenFile(top, "graph.dot");
}

TEST(Kernel, PrimRead) {
  TestReadKernel("PrimRead", fletcher::test::GetPrimReadSchema());
}

TEST(Kernel, StringRead) {
  TestReadKernel("StringRead", fletcher::test::GetStringReadSchema());
}

TEST(Kernel, ListPrim) {
  TestReadKernel("ListUint8", fletcher::test::GetListUint8Schema());
}

TEST(Kernel, BigSchema) {
  TestReadKernel("Big", fletcher::test::GetBigSchema());
}

}
