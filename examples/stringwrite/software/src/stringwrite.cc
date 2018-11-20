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

#include <chrono>
#include <memory>
#include <vector>
#include <iostream>
#include <iomanip>
#include <random>
#include <stdlib.h>
#include <unistd.h>

// Apache Arrow
#include <arrow/api.h>

// Fletcher
#include "fletcher/api.h"

std::shared_ptr<arrow::Schema> getSchema() {
  std::vector<std::shared_ptr<arrow::Field>> schema_fields = {arrow::field("str", arrow::utf8(), false)};
  auto schema_meta = metaMode(fletcher::Mode::WRITE);
  auto schema = std::make_shared<arrow::Schema>(schema_fields, schema_meta);
  return schema;
}

std::shared_ptr<arrow::RecordBatch> getRecordBatch(int32_t num_strings, int32_t num_chars) {
  std::shared_ptr<arrow::Buffer> offsets;
  std::shared_ptr<arrow::Buffer> values;

  if (!arrow::AllocateBuffer(arrow::default_memory_pool(), sizeof(int32_t) * (num_strings + 1), &offsets).ok()) {
    std::cerr << "Could not allocate offsets buffer." << std::endl;
    std::exit(-1);
  }
  if (!arrow::AllocateBuffer(arrow::default_memory_pool(), num_chars, &values).ok()) {
    std::cerr << "Could not allocate offsets buffer." << std::endl;
    std::exit(-1);
  }

  auto array = std::make_shared<arrow::StringArray>(num_strings, offsets, values);

  auto rb = arrow::RecordBatch::Make(getSchema(), num_strings, {array});

  return rb;
}

int main(int argc, char **argv) {

  constexpr int32_t num_str = 32;
  constexpr int32_t num_chars = num_str * 256;

  auto rb = getRecordBatch(num_str, num_chars);

  std::shared_ptr<fletcher::Platform> platform;
  std::shared_ptr<fletcher::Context> context;
  std::shared_ptr<fletcher::UserCore> uc;

  fletcher::Platform::Make(&platform);

  platform->init();

  fletcher::Context::Make(&context, platform);

  uc = std::make_shared<fletcher::UserCore>(context);

  context->queueRecordBatch(rb);

  uc->reset();

  context->enable();

  uc->setRange(0, num_str);

  uc->setArguments({ (uint32_t)std::strtoul(argv[1], NULL, 10),   // Minimum string length
                     (uint32_t)std::strtoul(argv[2], NULL, 10)}); // PRNG mask

  uc->start();
  platform->writeMMIO(0,0);
  
  usleep(100);
  //uc->waitForFinish(1000000);

  // Get raw pointers to host-side Arrow buffers
  auto sa = std::dynamic_pointer_cast<arrow::StringArray>(rb->column(0));

  auto raw_offsets = sa->value_offsets()->mutable_data();
  auto raw_values = sa->value_data()->mutable_data();

  platform->copyDeviceToHost(context->device_arrays[0]->buffers[0].device_address, raw_offsets, sizeof(int32_t) * (num_str+1));
  platform->copyDeviceToHost(context->device_arrays[0]->buffers[1].device_address, raw_values, (uint64_t) num_chars);

  //fletcher::HexView hv(0);
  //hv.addData(raw_offsets, sizeof(int32_t) * (num_str+1));
  //hv.addData(raw_values, num_chars);
  //std::cout << hv.toString() << std::endl;
  std::cout << "Recordbatch:" << std::endl;
  std::cout << sa->ToString() << std::endl;
}
