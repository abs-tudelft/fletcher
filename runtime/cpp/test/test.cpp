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
#include <memory>

#include <arrow/api.h>
#include <arrow/builder.h>
#include <arrow/record_batch.h>

#include "common/arrow-utils.h"
#include "common/status.h"

#include "../src/fletcher/platform.h"
#include "../src/fletcher/context.h"

bool test_platform() {
  std::shared_ptr<fletcher::Platform> platform;

  // Create
  fletcher::Platform::Make(&platform).ewf();

  // Init
  platform->init().ewf();

  // Info:
  std::cout << "Platform name: " << platform->getName() << std::endl;

  // Malloc / free
  da_t a;
  platform->deviceMalloc(&a, 1024);
  platform->deviceFree(a);

  // MMIO:
  platform->writeMMIO(0, 0).ewf();
  uint32_t val;
  platform->readMMIO(0, &val).ewf();

  // Buffers:
  char buffer[128];
  platform->copyHostToDevice(reinterpret_cast<uint8_t *>(buffer), 0, sizeof(buffer)).ewf();
  platform->copyDeviceToHost(0, reinterpret_cast<uint8_t *>(buffer), sizeof(buffer)).ewf();

  // Terminate:
  platform->terminate().ewf();

  return true;
}

bool test_context() {

  std::shared_ptr<fletcher::Platform> platform;

  // Create
  fletcher::Platform::Make(&platform).ewf();

  // Init
  platform->init().ewf();

  // Create a schema with some stuff
  std::vector<std::shared_ptr<arrow::Field>> schema_fields;
  schema_fields.push_back(std::make_shared<arrow::Field>("a", arrow::uint64(), false));
  schema_fields.push_back(std::make_shared<arrow::Field>("b", arrow::utf8(), false));
  schema_fields.push_back(std::make_shared<arrow::Field>("c", arrow::uint64(), true));
  schema_fields.push_back(std::make_shared<arrow::Field>("d", arrow::list(
      std::make_shared<arrow::Field>("e", arrow::uint32(), true)), false));

  auto schema = std::make_shared<arrow::Schema>(schema_fields);

  arrow::UInt64Builder ba;
  arrow::StringBuilder bb;
  arrow::UInt64Builder bc;
  auto be = std::make_shared<arrow::UInt32Builder>();
  arrow::ListBuilder bd(arrow::default_memory_pool(), be);

  // A builder not part of the recordbatch; it has no schema
  arrow::UInt32Builder bf;

  ba.AppendValues({1, 2, 3, 4});

  bb.AppendValues({"hello", "world", "fletcher", "arrow"});

  bc.AppendValues({5, 6, 7, 8}, {true, false, true, true});

  bd.Append();
  be->AppendValues({9, 10, 11, 12});
  bd.Append();
  be->AppendValues({13, 14});
  bd.Append();
  be->AppendValues({15, 16, 17});
  bd.Append();
  be->AppendValues({18});

  bf.AppendValues({19,20,21,22});

  std::shared_ptr<arrow::Array> a;
  std::shared_ptr<arrow::Array> b;
  std::shared_ptr<arrow::Array> c;
  std::shared_ptr<arrow::Array> d;
  std::shared_ptr<arrow::Array> f;

  ba.Finish(&a);
  bb.Finish(&b);
  bc.Finish(&c);
  bd.Finish(&d);
  bf.Finish(&f);

  auto rb = arrow::RecordBatch::Make(schema, 4, {a, b, c, d});

  std::shared_ptr<fletcher::Context> context;
  fletcher::Context::Make(&context, platform).ewf();

  context->queueRecordBatch(rb).ewf();

  //context->queueArray(f).ewf();

  // Write buffers
  context->enable().ewf();

  // Terminate:
  platform->terminate().ewf();

  return true;
}

int main() {
  //test_platform();
  test_context();
  return EXIT_SUCCESS;
}
