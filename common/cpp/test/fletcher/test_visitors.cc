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
#include <iostream>

#include "fletcher/test_schemas.h"
#include "fletcher/test_recordbatches.h"

using vs = std::vector<std::string>;

// ArrayVisistor tests
TEST(RecordBatchAnalyzer, VisitPrimitive) {
  auto rb = fletcher::GetIntRB();
  fletcher::RecordBatchDescription rbd;
  fletcher::RecordBatchAnalyzer rba(&rbd);
  rba.Analyze(*rb);
  ASSERT_FALSE(rbd.is_virtual);
  ASSERT_EQ(rbd.name, "PrimRead");
  ASSERT_EQ(rbd.fields[0].length, 4);
  ASSERT_TRUE(rbd.fields[0].type_->Equals(arrow::int8()));
  ASSERT_EQ(rbd.fields[0].null_count, 0);
  ASSERT_EQ(rbd.fields[0].buffers[0].level_, 0);
  ASSERT_EQ(rbd.fields[0].buffers[0].desc_, vs({"number", "values"}));
  ASSERT_EQ(rbd.fields[0].buffers[0].size_, 4);
}

TEST(RecordBatchAnalyzer, VisitString) {
  auto rb = fletcher::GetStringRB();
  fletcher::RecordBatchDescription rbd;
  fletcher::RecordBatchAnalyzer rba(&rbd);
  rba.Analyze(*rb);
  ASSERT_FALSE(rbd.is_virtual);
  ASSERT_EQ(rbd.name, "StringRead");
  ASSERT_EQ(rbd.fields[0].length, 26);
  ASSERT_TRUE(rbd.fields[0].type_->Equals(arrow::utf8()));
  ASSERT_EQ(rbd.fields[0].null_count, 0);
  ASSERT_EQ(rbd.fields[0].buffers[0].level_, 0);
  ASSERT_EQ(rbd.fields[0].buffers[0].desc_, vs({"Name", "offsets"}));
  ASSERT_EQ(rbd.fields[0].buffers[0].size_, 27 * sizeof(int32_t));
  ASSERT_EQ(rbd.fields[0].buffers[1].level_, 0);
  ASSERT_EQ(rbd.fields[0].buffers[1].desc_, vs({"Name", "values"}));
  ASSERT_EQ(rbd.fields[0].buffers[1].size_, 133);
}

TEST(RecordBatchAnalyzer, VisitList) {
  auto rb = fletcher::GetListUint8RB();
  fletcher::RecordBatchDescription rbd;
  fletcher::RecordBatchAnalyzer rba(&rbd);
  rba.Analyze(*rb);
  ASSERT_FALSE(rbd.is_virtual);
  ASSERT_EQ(rbd.name, "ListUint8");
  ASSERT_EQ(rbd.fields[0].length, 3);
  ASSERT_TRUE(rbd.fields[0].type_->Equals(arrow::list(arrow::uint8())));
  ASSERT_EQ(rbd.fields[0].null_count, 0);
  ASSERT_EQ(rbd.fields[0].buffers[0].level_, 0);
  ASSERT_EQ(rbd.fields[0].buffers[0].desc_, vs({"L", "offsets"}));
  ASSERT_EQ(rbd.fields[0].buffers[0].size_, 4 * sizeof(int32_t));
  ASSERT_EQ(rbd.fields[0].buffers[1].level_, 1);
  ASSERT_EQ(rbd.fields[0].buffers[1].desc_, vs({"L", "values"}));
  ASSERT_EQ(rbd.fields[0].buffers[1].size_, 13);
}

TEST(RecordBatchAnalyzer, VisitStruct) {
  auto rb = fletcher::GetStructRB();
  fletcher::RecordBatchDescription rbd;
  fletcher::RecordBatchAnalyzer rba(&rbd);
  rba.Analyze(*rb);
  std::vector<std::shared_ptr<arrow::Field>> struct_fields = {
      arrow::field("A", arrow::uint16(), false),
      arrow::field("B", arrow::uint32(), false),
  };
  ASSERT_FALSE(rbd.is_virtual);
  ASSERT_EQ(rbd.name, "StructBatch");
  ASSERT_EQ(rbd.fields[0].length, 4);
  ASSERT_TRUE(rbd.fields[0].type_->Equals(arrow::struct_(struct_fields)));
  ASSERT_EQ(rbd.fields[0].null_count, 0);
  ASSERT_EQ(rbd.fields[0].buffers[0].level_, 1);
  ASSERT_EQ(rbd.fields[0].buffers[0].desc_, vs({"S", "A", "values"}));
  ASSERT_EQ(rbd.fields[0].buffers[0].size_, 4 * sizeof(uint16_t));
  ASSERT_EQ(rbd.fields[0].buffers[1].level_, 1);
  ASSERT_EQ(rbd.fields[0].buffers[1].desc_, vs({"S", "B", "values"}));
  ASSERT_EQ(rbd.fields[0].buffers[1].size_, 4 * sizeof(uint32_t));
}

// TypeVisitor tests
TEST(SchemaAnalyzer, VisitPrimitive) {
  auto schema = fletcher::GetPrimReadSchema();
  fletcher::RecordBatchDescription rbd;
  fletcher::SchemaAnalyzer sa(&rbd);
  sa.Analyze(*schema);
  ASSERT_TRUE(rbd.is_virtual);
  ASSERT_EQ(rbd.name, "PrimRead");
  ASSERT_EQ(rbd.fields[0].length, 0);
  ASSERT_TRUE(rbd.fields[0].type_->Equals(arrow::int8()));
  ASSERT_EQ(rbd.fields[0].null_count, 0);
  ASSERT_GT(rbd.fields[0].buffers.size(), 0);
  ASSERT_EQ(rbd.fields[0].buffers[0].level_, 0);
  ASSERT_EQ(rbd.fields[0].buffers[0].desc_, vs({"number", "values"}));
  ASSERT_EQ(rbd.fields[0].buffers[0].size_, 0);
}

TEST(SchemaAnalyzer, VisitString) {
  auto schema = fletcher::GetStringReadSchema();
  fletcher::RecordBatchDescription rbd;
  fletcher::SchemaAnalyzer sa(&rbd);
  sa.Analyze(*schema);
  ASSERT_TRUE(rbd.is_virtual);
  ASSERT_EQ(rbd.name, "StringRead");
  ASSERT_EQ(rbd.fields[0].length, 0);
  ASSERT_TRUE(rbd.fields[0].type_->Equals(arrow::utf8()));
  ASSERT_EQ(rbd.fields[0].null_count, 0);
  ASSERT_EQ(rbd.fields[0].buffers[0].level_, 0);
  ASSERT_EQ(rbd.fields[0].buffers[0].desc_, vs({"Name", "offsets"}));
  ASSERT_EQ(rbd.fields[0].buffers[0].size_, 0);
  ASSERT_EQ(rbd.fields[0].buffers[1].level_, 0);
  ASSERT_EQ(rbd.fields[0].buffers[1].desc_, vs({"Name", "values"}));
  ASSERT_EQ(rbd.fields[0].buffers[1].size_, 0);
}

TEST(SchemaAnalyzer, VisitStruct) {
  auto schema = fletcher::GetStructSchema();
  fletcher::RecordBatchDescription rbd;
  fletcher::SchemaAnalyzer sa(&rbd);
  sa.Analyze(*schema);

  std::vector<std::shared_ptr<arrow::Field>> struct_fields = {
      arrow::field("A", arrow::uint16(), false),
      arrow::field("B", arrow::uint32(), false),
  };

  ASSERT_TRUE(rbd.is_virtual);
  ASSERT_EQ(rbd.name, "StructBatch");
  ASSERT_EQ(rbd.fields[0].length, 0);
  ASSERT_TRUE(rbd.fields[0].type_->Equals(arrow::struct_(struct_fields)));
  ASSERT_EQ(rbd.fields[0].null_count, 0);
  ASSERT_EQ(rbd.fields[0].buffers[0].level_, 1);
  ASSERT_EQ(rbd.fields[0].buffers[0].desc_, vs({"S", "A", "values"}));
  ASSERT_EQ(rbd.fields[0].buffers[0].size_, 0);
  ASSERT_EQ(rbd.fields[0].buffers[1].level_, 1);
  ASSERT_EQ(rbd.fields[0].buffers[1].desc_, vs({"S", "B", "values"}));
  ASSERT_EQ(rbd.fields[0].buffers[1].size_, 0);
}
