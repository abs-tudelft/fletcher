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

#include "gtest/gtest.h"

#include "fletcher/common/arrow-utils.h"

#include "./test_schemas.h"
#include "./test_recordbatches.h"

TEST(common_arrow_utils, appendExpectedBuffersFromField) {
  // List of uint8's
  auto schema = fletcher::test::genListUint8Schema();
  std::vector<std::string> bufs;
  fletcher::appendExpectedBuffersFromField(&bufs, schema->field(0));
  ASSERT_EQ(bufs[0], "list_offsets");
  ASSERT_EQ(bufs[1], "uint8_values");

  schema = fletcher::test::genStringSchema();
  // String is essentially a list of non-nullable utf8 bytes
  std::vector<std::string> bufs2;
  fletcher::appendExpectedBuffersFromField(&bufs2, schema->field(0));
  ASSERT_EQ(bufs2[0], "Name_offsets");
  ASSERT_EQ(bufs2[1], "Name_values");
}

TEST(common_arrow_utils, RecordBatchFileRoundTrip) {
  auto wrb = fletcher::test::getStringRB();
  fletcher::writeRecordBatchToFile(wrb, "test-common.rb");
  auto rrb = fletcher::readRecordBatchFromFile("test-common.rb", wrb->schema());
  ASSERT_TRUE(wrb->Equals(*rrb));
}

TEST(common_arrow_utils, flattenArrayBuffers_string) {
  // Test flattening of array buffers with field
  auto rb = fletcher::test::getStringRB();
  auto sa = std::dynamic_pointer_cast<arrow::StringArray>(rb->column(0));

  std::vector<arrow::Buffer*> buffers;
  fletcher::flattenArrayBuffers(&buffers, rb->column(0), rb->schema()->field(0));
  // First buffer should be offsets buffer
  ASSERT_EQ(buffers[0], sa->value_offsets().get());
  // Second buffer should be values buffer
  ASSERT_EQ(buffers[1], sa->value_data().get());
}

TEST(common_arrow_utils, flattenArrayBuffers_string_noField) {
  // Test flattening of array buffers without field
  auto rb = fletcher::test::getStringRB();
  auto sa = std::dynamic_pointer_cast<arrow::StringArray>(rb->column(0));

  std::vector<arrow::Buffer*> buffers;
  fletcher::flattenArrayBuffers(&buffers, rb->column(0));
  // First buffer should be offsets buffer
  ASSERT_EQ(buffers[0], sa->value_offsets().get());
  // Second buffer should be values buffer
  ASSERT_EQ(buffers[1], sa->value_data().get());
}

TEST(common_arrow_utils, flattenArrayBuffers_list) {
  // Test flattening of array buffers without field
  auto rb = fletcher::test::getListUint8RB();
  auto la = std::dynamic_pointer_cast<arrow::ListArray>(rb->column(0));
  auto va = std::dynamic_pointer_cast<arrow::UInt8Array>(la->values());

  std::vector<arrow::Buffer*> buffers;
  fletcher::flattenArrayBuffers(&buffers, rb->column(0), rb->schema()->field(0));
  // First buffer should be offsets buffer
  ASSERT_EQ(buffers[0], la->value_offsets().get());
  // Second buffer should be values buffer
  ASSERT_EQ(buffers[1], va->values().get());
}

int main(int argc, char **argv) {
  ::testing::InitGoogleTest(&argc, argv);
  return RUN_ALL_TESTS();
}
