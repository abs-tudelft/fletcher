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

#include <vector>
#include <string>
#include <iostream>
#include <gtest/gtest.h>
#include <fletcher/common.h>
#include <arrow/api.h>

#include "fletcher/test_schemas.h"
#include "fletcher/test_recordbatches.h"

TEST(Common, AppendExpectedBuffersFromField) {
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
  auto wrb = fletcher::GetStringRB();
  fletcher::WriteRecordBatchToFile(wrb, "test-common.rb");
  auto rrb = fletcher::ReadRecordBatchFromFile("test-common.rb", wrb->schema());
  ASSERT_TRUE(wrb->Equals(*rrb));
}

TEST(Common, FlattenArrayBuffers_string) {
// Test flattening of array buffers with field
  auto rb = fletcher::GetStringRB();
  auto sa = std::dynamic_pointer_cast<arrow::StringArray>(rb->column(0));

  std::vector<arrow::Buffer *> buffers;
  fletcher::FlattenArrayBuffers(&buffers, rb->column(0), rb->schema()->field(0));
// First buffer should be offsets buffer
  ASSERT_EQ(buffers[0], sa->value_offsets().get());
// Second buffer should be values buffer
  ASSERT_EQ(buffers[1], sa->value_data().get());
}

TEST(Common, FlattenArrayBuffers_string_noField) {
// Test flattening of array buffers without field
  auto rb = fletcher::GetStringRB();
  auto sa = std::dynamic_pointer_cast<arrow::StringArray>(rb->column(0));

  std::vector<arrow::Buffer *> buffers;
  fletcher::FlattenArrayBuffers(&buffers, rb->column(0));
// First buffer should be offsets buffer
  ASSERT_EQ(buffers[0], sa->value_offsets().get());
// Second buffer should be values buffer
  ASSERT_EQ(buffers[1], sa->value_data().get());
}

TEST(Common, FlattenArrayBuffers_list) {
// Test flattening of array buffers without field
  auto rb = fletcher::GetListUint8RB();
  auto la = std::dynamic_pointer_cast<arrow::ListArray>(rb->column(0));
  auto va = std::dynamic_pointer_cast<arrow::UInt8Array>(la->values());

  std::vector<arrow::Buffer *> buffers;
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

// RecordBatchDescriptor tests:

TEST(RecordBatchDescriptor, VisitPrimitive) {
  auto rb = fletcher::GetIntRB();
  fletcher::RecordBatchDescription rbd;
  fletcher::RecordBatchAnalyzer rba(&rbd);
  rba.Analyze(*rb);
  ASSERT_EQ(rbd.fields[0].length_, 4);
  ASSERT_TRUE(rbd.fields[0].type_->Equals(arrow::int8()));
  ASSERT_EQ(rbd.fields[0].null_count_, 0);
  ASSERT_EQ(rbd.buffers[0].level_, 0);
  ASSERT_EQ(rbd.buffers[0].desc_, "int8 (empty null bitmap)");
  ASSERT_EQ(rbd.buffers[1].level_, 0);
  ASSERT_EQ(rbd.buffers[1].desc_, "int8 (values)");
}

TEST(RecordBatchDescriptor, VisitString) {
  auto rb = fletcher::GetStringRB();
  fletcher::RecordBatchDescription rbd;
  fletcher::RecordBatchAnalyzer rba(&rbd);
  rba.Analyze(*rb);
  ASSERT_EQ(rbd.fields[0].length_, 26);
  ASSERT_TRUE(rbd.fields[0].type_->Equals(arrow::utf8()));
  ASSERT_EQ(rbd.fields[0].null_count_, 0);
  ASSERT_EQ(rbd.buffers[0].level_, 0);
  ASSERT_EQ(rbd.buffers[0].desc_, "string (empty null bitmap)");
  ASSERT_EQ(rbd.buffers[1].level_, 0);
  ASSERT_EQ(rbd.buffers[1].desc_, "string (offsets)");
  ASSERT_EQ(rbd.buffers[2].level_, 0);
  ASSERT_EQ(rbd.buffers[2].desc_, "string (values)");
}

TEST(RecordBatchDescriptor, VisitList) {
  auto rb = fletcher::GetListUint8RB();
  fletcher::RecordBatchDescription rbd;
  fletcher::RecordBatchAnalyzer rba(&rbd);
  rba.Analyze(*rb);
  ASSERT_EQ(rbd.fields[0].length_, 3);
  ASSERT_TRUE(rbd.fields[0].type_->Equals(arrow::list(arrow::uint8())));
  ASSERT_EQ(rbd.fields[0].null_count_, 0);
  ASSERT_EQ(rbd.buffers[0].level_, 0);
  ASSERT_EQ(rbd.buffers[0].desc_, "list<item: uint8> (empty null bitmap)");
  ASSERT_EQ(rbd.buffers[1].level_, 0);
  ASSERT_EQ(rbd.buffers[1].desc_, "list<item: uint8> (offsets)");
  ASSERT_EQ(rbd.buffers[2].level_, 1);
  ASSERT_EQ(rbd.buffers[2].desc_, "uint8 (empty null bitmap)");
  ASSERT_EQ(rbd.buffers[3].level_, 1);
  ASSERT_EQ(rbd.buffers[3].desc_, "uint8 (values)");
}

TEST(RecordBatchDescriptor, VisitStruct) {
  auto rb = fletcher::GetStructRB();
  fletcher::RecordBatchDescription rbd;
  fletcher::RecordBatchAnalyzer rba(&rbd);
  rba.Analyze(*rb);
  std::vector<std::shared_ptr<arrow::Field>> struct_fields = {
      arrow::field("A", arrow::uint16(), false),
      arrow::field("B", arrow::uint32(), false),
  };
  ASSERT_EQ(rbd.fields[0].length_, 4);
  ASSERT_TRUE(rbd.fields[0].type_->Equals(arrow::struct_(struct_fields)));
  ASSERT_EQ(rbd.fields[0].null_count_, 0);
  ASSERT_EQ(rbd.buffers[0].level_, 0);
  ASSERT_EQ(rbd.buffers[0].desc_, "struct<A: uint16, B: uint32> (empty null bitmap)");
  ASSERT_EQ(rbd.buffers[1].level_, 1);
  ASSERT_EQ(rbd.buffers[1].desc_, "uint16 (empty null bitmap)");
  ASSERT_EQ(rbd.buffers[2].level_, 1);
  ASSERT_EQ(rbd.buffers[2].desc_, "uint16 (values)");
  ASSERT_EQ(rbd.buffers[3].level_, 1);
  ASSERT_EQ(rbd.buffers[3].desc_, "uint32 (empty null bitmap)");
  ASSERT_EQ(rbd.buffers[4].level_, 1);
  ASSERT_EQ(rbd.buffers[4].desc_, "uint32 (values)");
}

