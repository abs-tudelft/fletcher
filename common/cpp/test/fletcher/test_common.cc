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

#include <gtest/gtest.h>
#include <fletcher/common.h>
#include <arrow/api.h>

#include <vector>
#include <string>

#include "fletcher/test_schemas.h"
#include "fletcher/test_recordbatches.h"

TEST(Common, AppendMetaRequired) {
  auto schema = fletcher::GetPrimReadSchema();
  ASSERT_NE(schema->metadata(), nullptr);
  std::unordered_map<std::string, std::string> map;
  schema->metadata()->ToUnorderedMap(&map);
  ASSERT_GT(map.count("fletcher_name"), 0);
  ASSERT_GT(map.count("fletcher_mode"), 0);
  ASSERT_EQ(map.at("fletcher_name"), "PrimRead");
  ASSERT_EQ(map.at("fletcher_mode"), "read");
}

TEST(Common, RecordBatchFileRoundTrip) {
  auto rb_out = fletcher::GetStringRB();
  std::vector<std::shared_ptr<arrow::RecordBatch>> rbs_in;
  fletcher::WriteRecordBatchesToFile("test-common.rb", {rb_out});
  fletcher::ReadRecordBatchesFromFile("test-common.rb", &rbs_in);
  ASSERT_TRUE(rb_out->schema()->Equals(*rbs_in[0]->schema(), true));
  ASSERT_TRUE(rb_out->Equals(*rbs_in[0]));
}

TEST(Common, HexView) {
  fletcher::HexView hv0(0, 8);
  fletcher::HexView hv1(3, 16);
  uint8_t data[] = {0x1, 0x2, 0x3, 0x4};
  hv0.AddData(data, 4);
  hv1.AddData(data, 4);
  // Test with header
  ASSERT_EQ(hv0.ToString(true), "                 00 01 02 03 04 05 06 07\n"
                                "0000000000000000 01 02 03 04             ....    ");
  // Test without header and offset
  ASSERT_EQ(hv1.ToString(false), "0000000000000000          01 02 03 04                               ....         ");
}
