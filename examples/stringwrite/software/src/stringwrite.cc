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

std::shared_ptr<std::vector<char>> genRandomValues(const std::shared_ptr<std::vector<int32_t>> &lengths,
                                                   int32_t amount) {
  std::array<LFSRRandomizer, 64> lfsrs;

  // initialize the lfsrs as in hardware
  for (int i = 0; i < 64; i++) {
    lfsrs[i].lfsr = (uint8_t) i;
  }

  // reserve all characters in a vector
  auto values = std::make_shared<std::vector<char>>();
  values->reserve(static_cast<unsigned long>(amount));

  // For every string length
  for (const auto &len : *lengths) {
    uint32_t strpos = 0;
    // First generate a new "line" of random characters, even if it's zero length
    do {
      uint32_t bufpos = 0;
      char buffer[64] = {0};
      for (int c = 0; c < 64; c++) {
        auto val = lfsrs[c].next() & (uint8_t) 127;
        if (val < 32) val = '.';
        if (val == 127) val = '.';
        buffer[c] = val;
      }
      // Fill the cacheline
      for (bufpos = 0; bufpos < 64 && strpos < (uint32_t) len; bufpos++) {
        values->push_back(buffer[bufpos]);
        strpos++;
      }
    } while (strpos < (uint32_t) len);
  }

  return values;
}

std::shared_ptr<std::vector<std::string>> deserializeToVector(const std::shared_ptr<std::vector<int32_t>> &lengths,
                                                              const std::shared_ptr<std::vector<char>> &values) {
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

std::shared_ptr<arrow::StringArray> deserializeToArrow(const std::shared_ptr<std::vector<int32_t>> &lengths,
                                                       const std::shared_ptr<std::vector<char>> &values) {

  // Allocate space for values buffer
  std::shared_ptr<arrow::Buffer> val_buffer;
  if (!arrow::AllocateBuffer(values->size(), &val_buffer).ok()) {
    throw std::runtime_error("Could not allocate values buffer.");
  }

  // Copy the values buffer
  memcpy(val_buffer->mutable_data(), values->data(), values->size());

  // Allocate space for offsets buffer
  std::shared_ptr<arrow::Buffer> off_buffer;
  if (!arrow::AllocateBuffer((lengths->size() + 1) * sizeof(int32_t), &off_buffer).ok()) {
    throw std::runtime_error("Could not allocate offsets buffer.");
  }

  // Lengths need to be converted into offsets

  // Get the raw mutable buffer
  auto raw_ints = (int32_t *) off_buffer->mutable_data();
  int32_t offset = 0;

  for (size_t i = 0; i < lengths->size(); i++) {
    raw_ints[i] = offset;
    offset += lengths->at(i);
  }

  // Fill in last offset
  raw_ints[lengths->size()] = offset;

  return std::make_shared<arrow::StringArray>(lengths->size(), off_buffer, val_buffer);
}

std::shared_ptr<arrow::Schema> getSchema() {
  std::vector<std::shared_ptr<arrow::Field>> schema_fields = {arrow::field("str", arrow::utf8(), false)};
  auto schema_meta = metaMode(fletcher::Mode::WRITE);
  auto schema = std::make_shared<arrow::Schema>(schema_fields, schema_meta);
  return schema;
}

std::shared_ptr<arrow::RecordBatch> prepareRecordBatch(int32_t num_strings, int32_t num_chars) {
  std::shared_ptr<arrow::Buffer> offsets;
  std::shared_ptr<arrow::Buffer> values;

  if (!arrow::AllocateBuffer(arrow::default_memory_pool(), sizeof(int32_t) * (num_strings + 1), &offsets).ok()) {
    throw std::runtime_error("Could not allocate offsets buffer.");
  }
  if (!arrow::AllocateBuffer(arrow::default_memory_pool(), num_chars, &values).ok()) {
    throw std::runtime_error("Could not allocate values buffer.");
  }

  auto array = std::make_shared<arrow::StringArray>(num_strings, offsets, values);

  auto rb = arrow::RecordBatch::Make(getSchema(), num_strings, {array});

  return rb;
}

int main(int argc, char **argv) {

  std::shared_ptr<fletcher::Platform> platform;
  std::shared_ptr<fletcher::Context> context;
  std::shared_ptr<fletcher::UserCore> uc;

  fletcher::Timer t;

  int32_t num_str = 4;
  uint32_t min_len = 0;
  uint32_t len_msk = 255;

  if (argc > 3) {
    num_str = (uint32_t) std::strtoul(argv[1], nullptr, 10);
    min_len = (uint32_t) std::strtoul(argv[2], nullptr, 10);
    len_msk = (uint32_t) std::strtoul(argv[3], nullptr, 10);
  } else {
    std::cerr << "Usage: stringwrite <min str len> <prng mask>" << std::endl;
    exit(-1);
  }

  int32_t num_values = 0;

  std::cout << std::setw(10) << num_str << ", ";

  t.start();
  auto rand_lens = genRandomLengths(num_str, min_len, len_msk, &num_values);
  t.stop();
  t.report();

  t.start();
  auto rand_vals = genRandomValues(rand_lens, num_values);
  t.stop();
  t.report();

  std::cout << std::setw(10) << num_str * sizeof(int32_t) + num_values << ", ";

  t.start();
  auto dataset_stl = deserializeToVector(rand_lens, rand_vals);
  t.stop();
  t.report();

  t.start();
  auto dataset_arrow = deserializeToArrow(rand_lens, rand_vals);
  t.stop();
  t.report();

  t.start();
  auto rb = prepareRecordBatch(num_str, num_values);
  t.stop();
  t.report();

  t.start();
  fletcher::Platform::Make(&platform);
  platform->init();
  fletcher::Context::Make(&context, platform);
  uc = std::make_shared<fletcher::UserCore>(context);
  uc->reset();
  context->queueRecordBatch(rb);
  context->enable();
  uc->setRange(0, num_str);
  uc->setArguments({min_len, len_msk});
  t.stop();
  t.report();

  t.start();
  uc->start();
  uc->waitForFinish(100);
  t.stop();
  t.report();

  t.start();
  // Get raw pointers to host-side Arrow buffers
  auto sa = std::dynamic_pointer_cast<arrow::StringArray>(rb->column(0));

  auto raw_offsets = sa->value_offsets()->mutable_data();
  auto raw_values = sa->value_data()->mutable_data();

  platform->copyDeviceToHost(context->device_arrays[0]->buffers[0].device_address,
                             raw_offsets,
                             sizeof(int32_t) * (num_str + 1));
  platform->copyDeviceToHost(context->device_arrays[0]->buffers[1].device_address, raw_values, (uint64_t) num_values);
  t.stop();
  t.report();

}
