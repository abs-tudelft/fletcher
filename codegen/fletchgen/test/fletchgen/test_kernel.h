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

#include "fletcher/test_schemas.h"

#include "cerata/vhdl/vhdl.h"
#include "cerata/dot/dot.h"

#include "fletchgen/basic_types.h"
#include "fletchgen/mantle.h"
#include "fletchgen/bus.h"
#include "fletchgen/schema.h"

#include "fletchgen/test_utils.h"

namespace fletchgen {

static void TestReadKernel(const std::string& test_name, const std::shared_ptr<arrow::Schema>& schema) {
  cerata::default_component_pool()->Clear();
  auto fs = FletcherSchema::Make(schema);
  auto rbr = RecordBatch::Make(fs);
  auto top = Kernel::Make("Test" + test_name, {rbr.get()});
  auto design = cerata::vhdl::Design(top);
  auto code = design.Generate().ToString();
  std::cerr.flush();
  std::cout << code << std::endl;
  VHDL_DUMP_TEST(code);
}

TEST(Kernel, PrimRead) {
  TestReadKernel("PrimRead", fletcher::GetPrimReadSchema());
}

TEST(Kernel, StringRead) {
  TestReadKernel("StringRead", fletcher::GetStringReadSchema());
}

TEST(Kernel, ListPrim) {
  TestReadKernel("ListUint8", fletcher::GetListUint8Schema());
}

TEST(Kernel, BigSchema) {
  TestReadKernel("Big", fletcher::GetBigSchema());
}

}
