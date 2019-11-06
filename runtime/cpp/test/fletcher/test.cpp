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

#include <fletcher/fletcher.h>
#include <arrow/api.h>
#include <arrow/builder.h>
#include <arrow/record_batch.h>
#include <fletcher_echo.h>
#include <gtest/gtest.h>

#include <string>
#include <vector>
#include <memory>

#include "fletcher/platform.h"
#include "fletcher/context.h"

TEST(Platform, NoPlatform) {
  std::shared_ptr<fletcher::Platform> platform;
  ASSERT_EQ(fletcher::Platform::Make("DEADBEEF", &platform), fletcher::Status::NO_PLATFORM());
}

TEST(Platform, EchoPlatform) {
  std::shared_ptr<fletcher::Platform> platform;

  // Create
  ASSERT_TRUE(fletcher::Platform::Make("echo", &platform, false).ok());
  ASSERT_EQ(platform->name(), "echo");

  // Init
  // Make echo quiet
  auto opts = std::make_shared<InitOptions>();
  opts->quiet = 0;
  platform->init_data = opts.get();
  ASSERT_TRUE(platform->Init().ok());

  // Malloc / free
  da_t a;
  ASSERT_TRUE(platform->DeviceMalloc(&a, 1024).ok());
  ASSERT_TRUE(platform->DeviceFree(a).ok());

  // MMIO:
  ASSERT_TRUE(platform->WriteMMIO(0, 0).ok());
  uint32_t val;
  ASSERT_TRUE(platform->ReadMMIO(0, &val).ok());
  uint64_t val64;
  ASSERT_TRUE(platform->ReadMMIO64(0, &val64).ok());

  // Buffers:
  char buffer[128];
  char device_mock_buffer[128];
  da_t device_buf_addr = (uint64_t)device_mock_buffer;
  ASSERT_TRUE(platform->CopyHostToDevice(reinterpret_cast<uint8_t *>(buffer), device_buf_addr, sizeof(buffer)).ok());
  ASSERT_TRUE(platform->CopyDeviceToHost(device_buf_addr, reinterpret_cast<uint8_t *>(buffer), sizeof(buffer)).ok());

  // Terminate:
  ASSERT_TRUE(platform->Terminate().ok());

}

TEST(Context, ContextFunctions) {
  std::shared_ptr<fletcher::Platform> platform;
  ASSERT_TRUE(fletcher::Platform::Make(&platform, false).ok());
  ASSERT_TRUE(platform->Init().ok());

  // Create a schema with some stuff
  std::vector<std::shared_ptr<arrow::Field>> schema_fields;
  schema_fields.push_back(std::make_shared<arrow::Field>("a", arrow::uint64(), false));  // 1
  schema_fields.push_back(std::make_shared<arrow::Field>("b", arrow::utf8(), false));  // 3
  schema_fields.push_back(std::make_shared<arrow::Field>("c", arrow::uint64(), true));  // 1
  schema_fields.push_back(std::make_shared<arrow::Field>("d", arrow::list(  // 1
      std::make_shared<arrow::Field>("e", arrow::uint32(), true)), false));  // 2

  // Should produce 8 arrow buffers

  auto schema = std::make_shared<arrow::Schema>(schema_fields);

  arrow::UInt64Builder ba;
  arrow::StringBuilder bb;
  arrow::UInt64Builder bc;
  auto be = std::make_shared<arrow::UInt32Builder>();
  arrow::ListBuilder bd(arrow::default_memory_pool(), be);

  // A builder not part of the RecordBatch; it has no schema
  arrow::UInt32Builder bf;

  ASSERT_TRUE(ba.AppendValues({1, 2, 3, 4}).ok());
  ASSERT_TRUE(bb.AppendValues({"hello", "world", "fletcher", "arrow"}).ok());
  ASSERT_TRUE(bc.AppendValues({5, 6, 7, 8}, {true, false, true, true}).ok());
  ASSERT_TRUE(bd.Append().ok());
  ASSERT_TRUE(be->AppendValues({9, 10, 11, 12}).ok());
  ASSERT_TRUE(bd.Append().ok());
  ASSERT_TRUE(be->AppendValues({13, 14}).ok());
  ASSERT_TRUE(bd.Append().ok());
  ASSERT_TRUE(be->AppendValues({15, 16, 17}).ok());
  ASSERT_TRUE(bd.Append().ok());
  ASSERT_TRUE(be->AppendValues({18}).ok());
  ASSERT_TRUE(bf.AppendValues({19, 20, 21, 22}).ok());

  std::shared_ptr<arrow::Array> a;
  std::shared_ptr<arrow::Array> b;
  std::shared_ptr<arrow::Array> c;
  std::shared_ptr<arrow::Array> d;
  std::shared_ptr<arrow::Array> f;

  ASSERT_TRUE(ba.Finish(&a).ok());
  ASSERT_TRUE(bb.Finish(&b).ok());
  ASSERT_TRUE(bc.Finish(&c).ok());
  ASSERT_TRUE(bd.Finish(&d).ok());
  ASSERT_TRUE(bf.Finish(&f).ok());

  auto rb = arrow::RecordBatch::Make(schema, 4, {a, b, c, d});

  // Test context functions
  std::shared_ptr<fletcher::Context> context;
  ASSERT_TRUE(fletcher::Context::Make(&context, platform).ok());
  ASSERT_TRUE(context->QueueRecordBatch(rb).ok());
  ASSERT_EQ(context->GetQueueSize(), 168);
  ASSERT_EQ(context->num_buffers(), 8);
  ASSERT_TRUE(context->Enable().ok());
  ASSERT_TRUE(platform->Terminate().ok());
}
