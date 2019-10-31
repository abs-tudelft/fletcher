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
#include <cerata/api.h>
#include <memory>
#include <string>

#include "fletcher/test_schemas.h"

#include "fletchgen/mantle.h"
#include "fletchgen/schema.h"
#include "fletchgen/design.h"
#include "fletchgen/profiler.h"

#include "fletchgen/test_utils.h"

namespace fletchgen {

static void TestNucleus(const std::string &test_name, const std::shared_ptr<arrow::Schema> &schema) {
  cerata::default_component_pool()->Clear();
  auto fs = std::make_shared<FletcherSchema>(schema, "TestSchema");
  fletcher::RecordBatchDescription rbd;
  fletcher::SchemaAnalyzer sa(&rbd);
  sa.Analyze(*schema);
  std::vector<fletcher::RecordBatchDescription> rbds = {rbd};
  auto rb_regs = Design::GetRecordBatchRegs(rbds);
  auto r = record_batch("Test_" + rbd.name, fs, rbd);
  auto pr_regs = GetProfilingRegs({r});
  std::vector<MmioReg> regs;
  regs.insert(regs.end(), rb_regs.begin(), rb_regs.end());
  regs.insert(regs.end(), pr_regs.begin(), pr_regs.end());
  auto m = mmio({rbd}, regs);
  auto k = kernel("Test_Kernel", {r}, m);
  auto n = nucleus("Test_Nucleus", {r}, k, m);
  GenerateTestAll(n);
}

TEST(Nucleus, PrimRead) {
  TestNucleus("TestNucleus", fletcher::GetPrimReadSchema());
}

TEST(Nucleus, TwoPrimRead) {
  TestNucleus("TestNucleus", fletcher::GetTwoPrimReadSchema());
}

}  // namespace fletchgen
