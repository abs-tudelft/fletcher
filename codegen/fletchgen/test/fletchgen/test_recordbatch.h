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
#include <fstream>

#include "test_schemas.h"

#include "cerata/vhdl/vhdl.h"
#include "cerata/dot/dot.h"

#include "fletchgen/basic_types.h"
#include "fletchgen/mantle.h"
#include "fletchgen/bus.h"
#include "fletchgen/schema.h"
#include "fletchgen/recordbatch.h"

// Macro to save the test to some VHDL files that can be used to syntax check the tests with e.g. GHDL
// At some point the reverse might be more interesting - load the test cases from file into the test.
#define VHDL_DUMP_TEST(str) \
  std::ofstream(std::string(::testing::UnitTest::GetInstance()->current_test_info()->test_suite_name()) \
  + "_" + ::testing::UnitTest::GetInstance()->current_test_info()->name() + ".vhd") << str

namespace fletchgen {

static void TestRecordBatchReader(const std::shared_ptr<arrow::Schema>& schema) {
  auto fs = FletcherSchema::Make(schema);
  auto rbr = RecordBatchReader::Make(fs);
  auto design = cerata::vhdl::Design(rbr);
  auto code = design.Generate().ToString();
  std::cerr.flush();
  std::cout << code << std::endl;
  VHDL_DUMP_TEST(code);
  cerata::dot::Grapher dot;
  std::cout << dot.GenFile(rbr, "graph.dot");
}

TEST(RecordBatch, StringRead) {
  TestRecordBatchReader(fletcher::test::GetStringReadSchema());
}

}
