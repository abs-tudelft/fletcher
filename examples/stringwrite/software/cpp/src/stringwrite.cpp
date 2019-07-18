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

#include <arrow/api.h>
#include <fletcher/api.h>
#include <cstdlib>
#include <vector>
#include <memory>

#include "./lfsr_model.h"

/// @brief Generate random lengths similar to the LFSR hardware model.
std::shared_ptr<std::vector<int32_t>> GenerateRandomLengths(int32_t amount,
                                                            uint32_t min,
                                                            uint32_t mask,
                                                            int32_t *total) {
  LFSRRandomizer lfsr;
  auto lengths = std::make_shared<std::vector<int32_t>>();
  lengths->reserve(static_cast<uint64_t>(amount));

  int total_length = 0;

  for (int32_t i = 0; i < amount; i++) {
    int len = min + (lfsr.next() & mask);
    total_length += len;
    lengths->push_back(len);
  }

  *total = total_length;

  return lengths;
}

/// @brief Mimic the behaviour of the LFSR generating utf8 values stream in hardware
std::shared_ptr<std::vector<char>> GenerateRandomValues(const std::shared_ptr<std::vector<int32_t>> &lengths,
                                                        int32_t amount) {
  std::array<LFSRRandomizer, 64> lfsrs;

  // initialize the lfsrs as in hardware
  for (int i = 0; i < 64; i++) {
    lfsrs[i].lfsr = (uint8_t) i;
  }

  // reserve all characters in a vector
  auto values = std::make_shared<std::vector<char>>();
  values->reserve(static_cast<uint64_t>(amount));

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

/// @brief Deserialize a lengths and values buffer into a C++ vector of strings on CPU.
std::shared_ptr<std::vector<std::string>> DeserializeToVector(const std::shared_ptr<std::vector<int32_t>> &lengths,
                                                              const std::shared_ptr<std::vector<char>> &values) {
  auto vec = std::make_shared<std::vector<std::string>>();
  vec->reserve(lengths->size());

  int32_t pos = 0;

  for (int len : *lengths) {
    auto str = std::string(values->data() + pos, len);
    vec->push_back(str);
    pos += len;
  }

  return vec;
}

/// @brief Deserialize a lengths and values buffer to an Arrow StringArray on CPU.
std::shared_ptr<arrow::StringArray> DeserializeToArrow(const std::shared_ptr<std::vector<int32_t>> &lengths,
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
  auto raw_ints = reinterpret_cast<int32_t *>(off_buffer->mutable_data());
  int32_t offset = 0;

  for (size_t i = 0; i < lengths->size(); i++) {
    raw_ints[i] = offset;
    offset += lengths->at(i);
  }

  // Fill in last offset
  raw_ints[lengths->size()] = offset;

  return std::make_shared<arrow::StringArray>(lengths->size(), off_buffer, val_buffer);
}

/// @brief Prepare a RecordBatch to hold the output data.
std::shared_ptr<arrow::RecordBatch> PrepareRecordBatch(const std::shared_ptr<arrow::Schema> &schema,
                                                       int32_t num_strings,
                                                       int32_t num_chars) {
  std::shared_ptr<arrow::Buffer> offsets;
  std::shared_ptr<arrow::Buffer> values;

  if (!arrow::AllocateBuffer(arrow::default_memory_pool(), sizeof(int32_t) * (num_strings + 1), &offsets).ok()) {
    throw std::runtime_error("Could not allocate offsets buffer.");
  }
  if (!arrow::AllocateBuffer(arrow::default_memory_pool(), num_chars, &values).ok()) {
    throw std::runtime_error("Could not allocate values buffer.");
  }

  auto array = std::make_shared<arrow::StringArray>(num_strings, offsets, values);

  auto rb = arrow::RecordBatch::Make(schema, num_strings, {array});

  return rb;
}

int main(int argc, char **argv) {
  // Check number of arguments.
  if (argc < 2) {
    std::cerr << "Incorrect number of arguments. "
                 "Usage: stringwrite path/to/schema.as <num_strings> <str_len_min> <str_len_prng_mask>" << std::endl;
    return -1;
  }

  std::shared_ptr<arrow::Schema> schema;
  fletcher::ReadSchemaFromFile(argv[1], &schema);

  fletcher::Timer t;

  int32_t num_str = 16;
  uint32_t min_len = 0;
  uint32_t len_msk = 255;

  if (argc > 2) num_str = (uint32_t) std::strtoul(argv[2], nullptr, 10);
  if (argc > 3) min_len = (uint32_t) std::strtoul(argv[3], nullptr, 10);
  if (argc > 4) len_msk = (uint32_t) std::strtoul(argv[4], nullptr, 10);

  int32_t num_values = 0;

  std::cout << "Number of strings                : " << num_str << std::endl;

  t.start();
  auto rand_lens = GenerateRandomLengths(num_str, min_len, len_msk, &num_values);
  auto rand_vals = GenerateRandomValues(rand_lens, num_values);
  t.stop();
  std::cout << "Generate                         : " << t.seconds() << std::endl;
  std::cout << "Dataset size                     : " << num_str * sizeof(int32_t) + num_values << std::endl;

  t.start();
  auto dataset_stl = DeserializeToVector(rand_lens, rand_vals);
  t.stop();
  std::cout << "Deserialize to C++ STL Vector    : " << t.seconds() << std::endl;

  t.start();
  auto dataset_arrow = DeserializeToArrow(rand_lens, rand_vals);
  t.stop();
  std::cout << "Deserialize to Arrow StringArray : " << t.seconds() << std::endl;

  t.start();
  auto dataset_fpga = PrepareRecordBatch(schema, num_str, num_values);
  t.stop();
  std::cout << "Prepare FPGA RecordBatch         : " << t.seconds() << std::endl;

  t.start();
  std::shared_ptr<fletcher::Platform> platform;
  std::shared_ptr<fletcher::Context> context;

  // Set up platform
  fletcher::Platform::Make(&platform).ewf("Could not create platform.");
  platform->Init();

  // Set up context
  fletcher::Context::Make(&context, platform);
  context->QueueRecordBatch(dataset_fpga);
  context->Enable();

  // Set up kernel
  fletcher::Kernel kernel(context);
  kernel.SetRange(0, 0, num_str);
  kernel.SetArguments({min_len, len_msk});
  t.stop();
  std::cout << "FPGA Initialize                  : " << t.seconds() << std::endl;

  t.start();
  kernel.Start();
  kernel.WaitForFinish(100);
  t.stop();
  std::cout << "FPGA Process stream              : " << t.seconds() << std::endl;

  t.start();
  // Get raw pointers to host-side Arrow buffers and reconstruct
  auto sa = std::dynamic_pointer_cast<arrow::StringArray>(dataset_fpga->column(0));
  auto raw_offsets = sa->value_offsets()->mutable_data();
  auto raw_values = sa->value_data()->mutable_data();
  platform->CopyDeviceToHost(context->device_buffer(0).device_address, raw_offsets, sizeof(int32_t) * (num_str + 1));
  platform->CopyDeviceToHost(context->device_buffer(1).device_address, raw_values, (uint64_t) num_values);
  t.stop();
  std::cout << "FPGA Device-to-Host              : " << t.seconds() << std::endl;

  std::cout << sa->ToString() << std::endl;
  std::cout << dataset_arrow->ToString() << std::endl;

  return 0;

}
