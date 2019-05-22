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

#include <vector>
#include <string>
#include <iostream>
#include <gtest/gtest.h>
#include <fletcher/common.h>

#include "fletcher/test_schemas.h"
#include "fletcher/test_recordbatches.h"

TEST(Common, appendExpectedBuffersFromField) {
  // List of uint8's
  auto schema = fletcher::GetListUint8Schema();
  std::vector<std::string> bufs;
  fletcher::AppendExpectedBuffersFromField(&bufs, schema->field(0));
  ASSERT_EQ(bufs[0], "list_offsets");
  ASSERT_EQ(bufs[1], "number_values");

  schema = fletcher::GetStringReadSchema();
  // String is essentially a list of non-nullable utf8 bytes
  std::vector<std::string> bufs2;
  fletcher::AppendExpectedBuffersFromField(&bufs2, schema->field(0));
  ASSERT_EQ(bufs2[0], "Name_offsets");
  ASSERT_EQ(bufs2[1], "Name_values");
}

TEST(Common, RecordBatchFileRoundTrip) {
  auto wrb = fletcher::getStringRB();
  fletcher::WriteRecordBatchToFile(wrb, "test-common.rb");
  auto rrb = fletcher::ReadRecordBatchFromFile("test-common.rb", wrb->schema());
  ASSERT_TRUE(wrb->Equals(*rrb));
}

TEST(Common, flattenArrayBuffers_string) {
  // Test flattening of array buffers with field
  auto rb = fletcher::getStringRB();
  auto sa = std::dynamic_pointer_cast<arrow::StringArray>(rb->column(0));

  std::vector<arrow::Buffer*> buffers;
  fletcher::FlattenArrayBuffers(&buffers, rb->column(0), rb->schema()->field(0));
  // First buffer should be offsets buffer
  ASSERT_EQ(buffers[0], sa->value_offsets().get());
  // Second buffer should be values buffer
  ASSERT_EQ(buffers[1], sa->value_data().get());
}

TEST(Common, flattenArrayBuffers_string_noField) {
  // Test flattening of array buffers without field
  auto rb = fletcher::getStringRB();
  auto sa = std::dynamic_pointer_cast<arrow::StringArray>(rb->column(0));

  std::vector<arrow::Buffer*> buffers;
  fletcher::FlattenArrayBuffers(&buffers, rb->column(0));
  // First buffer should be offsets buffer
  ASSERT_EQ(buffers[0], sa->value_offsets().get());
  // Second buffer should be values buffer
  ASSERT_EQ(buffers[1], sa->value_data().get());
}

TEST(Common, flattenArrayBuffers_list) {
  // Test flattening of array buffers without field
  auto rb = fletcher::getListUint8RB();
  auto la = std::dynamic_pointer_cast<arrow::ListArray>(rb->column(0));
  auto va = std::dynamic_pointer_cast<arrow::UInt8Array>(la->values());

  std::vector<arrow::Buffer*> buffers;
  fletcher::FlattenArrayBuffers(&buffers, rb->column(0), rb->schema()->field(0));
  // First buffer should be offsets buffer
  ASSERT_EQ(buffers[0], la->value_offsets().get());
  // Second buffer should be values buffer
  ASSERT_EQ(buffers[1], va->values().get());
}

TEST(Common, AppendMetaRequired) {
  auto schema = fletcher::GetPrimReadSchema();
  ASSERT_NE(schema->metadata(), nullptr);
  std::unordered_map<std::string, std::string> map;
  schema->metadata()->ToUnorderedMap(&map);
  ASSERT_TRUE(map.count("fletcher_name") > 0);
  ASSERT_TRUE(map.count("fletcher_mode") > 0);
  ASSERT_TRUE(map.at("fletcher_name") == "PrimRead");
  ASSERT_TRUE(map.at("fletcher_mode") == "read");
}

int main(int argc, char **argv) {
  ::testing::InitGoogleTest(&argc, argv);
  return RUN_ALL_TESTS();
}
