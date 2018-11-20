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

#include "randomizer.h"

std::shared_ptr<std::vector<int32_t>> genRandomLengths(int32_t amount, uint32_t min, uint32_t mask, int32_t *total) {
  LFSRRandomizer lfsr;
  auto lengths = std::make_shared<std::vector<int32_t>>();
  lengths->reserve(static_cast<unsigned long>(amount));

  int total_length = 0;

  for (int32_t i = 0; i < amount; i++) {
    int len = min + (lfsr.next() & mask);
    total_length += len;
    lengths->push_back(len);
  }

  *total = total_length;

  return lengths;
}

std::shared_ptr<std::vector<char>> genRandomValues(const std::shared_ptr<std::vector<int32_t>>& lengths, int32_t amount, char min=32, char max=127) {
  std::array<LFSRRandomizer,64> lfsrs;

  // initialize the lfsrs as in hardware
  for (int i=0;i<64;i++) {
    lfsrs[i].lfsr = (uint8_t)i;
  }

  // reserve all characters in a vector
  auto values = std::make_shared<std::vector<char>>();
  values->reserve(static_cast<unsigned long>(amount));

  // based on the lenghts,
  for (const auto& len : *lengths) {
    uint32_t strpos = 0;
    do {
      uint32_t bufpos = 0;
      // Generate a new "cacheline" of random characters
      char buffer[64] = {0};
      for (int c = 0; c < 64; c++) {
        auto val = lfsrs[c].next() & 127;
        if (val < 32) val = '.';
        if (val == 127) val = '.';
        buffer[c] = val;
      }
      // Fill the cacheline
      for (bufpos = 0; bufpos < 64 && strpos < (uint32_t)len;bufpos++) {
        values->push_back(buffer[bufpos]);
        strpos++;
      }
    } while(strpos < (uint32_t)len);
  }

  return values;
}

std::shared_ptr<std::vector<std::string>> deserializeToVector(const std::shared_ptr<std::vector<int32_t>>& lengths,
                                                              const std::shared_ptr<std::vector<char>>& values) {
  auto vec = std::make_shared<std::vector<std::string>>();
  vec->reserve(lengths->size());

  int32_t pos = 0;

  for (int len : *lengths) {
    auto str = std::string(values->data() + pos, static_cast<unsigned long>(len));
    vec->push_back(str);
    pos += len;
  }

  return vec;
}

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
  constexpr int32_t min_str = 0;
  constexpr int32_t len_msk = 255;

  int32_t num_values = 0;
  auto rand_lens = genRandomLengths(num_str, min_str, len_msk, &num_values);
  auto rand_vals = genRandomValues(rand_lens, num_values, ' ', '~');
  auto dataset_stl = deserializeToVector(rand_lens, rand_vals);

  std::cout << "Data size: " << num_str * sizeof(int32_t) + num_values << std::endl;

  for (size_t i=0;i<num_str;i++) {
    std::cout << std::setw(3) << dataset_stl->at(i).size() << " : " << dataset_stl->at(i) << std::endl;
  }

  auto rb = getRecordBatch(num_str, num_values);

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

  if (argc > 2) {
    uc->setArguments({(uint32_t) std::strtoul(argv[1], NULL, 10),   // Minimum string length
                      (uint32_t) std::strtoul(argv[2], NULL, 10)}); // PRNG mask
  } else {
    std::cerr << "Usage: stringwrite <min str len> <prng mask>" << std::endl;
    exit(-1);
  }

  uc->start();

  usleep(100000);
  //uc->waitForFinish(1000000);

  // Get raw pointers to host-side Arrow buffers
  auto sa = std::dynamic_pointer_cast<arrow::StringArray>(rb->column(0));

  auto raw_offsets = sa->value_offsets()->mutable_data();
  auto raw_values = sa->value_data()->mutable_data();

  platform->copyDeviceToHost(context->device_arrays[0]->buffers[0].device_address,
                             raw_offsets,
                             sizeof(int32_t) * (num_str + 1));
  platform->copyDeviceToHost(context->device_arrays[0]->buffers[1].device_address, raw_values, (uint64_t) num_values);

  //fletcher::HexView hv(0);
  //hv.addData(raw_offsets, sizeof(int32_t) * (num_str+1));
  //hv.addData(raw_values, num_chars);
  //std::cout << hv.toString() << std::endl;
  std::cout << "Recordbatch:" << std::endl;
  std::cout << sa->ToString() << std::endl;

}
