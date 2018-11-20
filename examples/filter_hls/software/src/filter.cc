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

std::shared_ptr<arrow::Schema> getFilterReadSchema() {
  std::vector<std::shared_ptr<arrow::Field>> schema_fields = {
      arrow::field("first", arrow::utf8(), false),
      arrow::field("last", arrow::utf8(), false),
      arrow::field("zip", arrow::uint32(), false)
  };
  auto schema = std::make_shared<arrow::Schema>(schema_fields, metaMode(fletcher::Mode::READ));
  return schema;
}

std::shared_ptr<arrow::Schema> getFilterWriteSchema() {
  std::vector<std::shared_ptr<arrow::Field>> schema_fields = {
      arrow::field("first", arrow::utf8(), false),
  };
  auto schema = std::make_shared<arrow::Schema>(schema_fields, metaMode(fletcher::Mode::WRITE));
  return schema;
}

std::shared_ptr<arrow::RecordBatch> getFilterInputRB(int32_t num_entries) {
  // Some first names
  std::vector<std::string> first_names = {"Alice", "Bob", "Carol", "David"};
  std::vector<std::string> last_names = {"Cooper", "Smith", "Smith", "Smith"};
  std::vector<uint32_t> zip_codes = {1337, 4242, 1337, 1337};

  // Make a string builder
  arrow::StringBuilder fn_builder;
  arrow::StringBuilder ln_builder;
  arrow::UInt32Builder zip_builder;

  // Append the strings in the string builder
  if (!fn_builder.AppendValues(first_names).ok()) {
    throw std::runtime_error("Could not append to first name builder.");
  };
  if (!ln_builder.AppendValues(last_names).ok()) {
    throw std::runtime_error("Could not append to last name builder.");
  };
  if (!zip_builder.AppendValues(zip_codes).ok()) {
    throw std::runtime_error("Could not append zip codes to builder.");
  };

  // Array to hold Arrow formatted string data
  std::shared_ptr<arrow::Array> fn_array;
  std::shared_ptr<arrow::Array> ln_array;
  std::shared_ptr<arrow::Array> zip_array;

  // Finish building and create a new data array around the data
  if (!fn_builder.Finish(&fn_array).ok()) {
    throw std::runtime_error("Could not finalize first name builder.");
  };
  if (!ln_builder.Finish(&ln_array).ok()) {
    throw std::runtime_error("Could not finalize last name builder.");
  };
  if (!zip_builder.Finish(&zip_array).ok()) {
    throw std::runtime_error("Could not finalize zip code builder.");
  };

  // Create the Record Batch
  std::shared_ptr<arrow::RecordBatch> record_batch =
      arrow::RecordBatch::Make(getFilterReadSchema(), fn_array->length(), {fn_array, ln_array, zip_array});

  return record_batch;
}

std::shared_ptr<arrow::RecordBatch> getFilterOutputRB(int32_t num_entries, int32_t num_chars) {
  std::shared_ptr<arrow::Buffer> offsets;
  std::shared_ptr<arrow::Buffer> values;
  arrow::AllocateBuffer(num_entries + 1, &offsets);
  arrow::AllocateBuffer(num_chars, &values);
  auto sa = std::make_shared<arrow::StringArray>(2, offsets, values);
  std::shared_ptr<arrow::RecordBatch> record_batch = arrow::RecordBatch::Make(getFilterWriteSchema(), 2, {sa});
  return record_batch;
}

int main(int argc, char **argv) {

  constexpr int32_t num_entries = 4;

  auto rb_in = getFilterInputRB(num_entries);
  auto rb_out = getFilterOutputRB(4096, 4096);

  std::cout << "RecordBatch in: " << std::endl;
  for (int i = 0; i < rb_in->num_columns(); i++) {
    std::cout << rb_in->column(i)->ToString() << std::endl;
  }

  std::shared_ptr<fletcher::Platform> platform;
  std::shared_ptr<fletcher::Context> context;
  std::shared_ptr<fletcher::UserCore> uc;

  fletcher::Platform::Make(&platform);

  platform->init();

  fletcher::Context::Make(&context, platform);

  uc = std::make_shared<fletcher::UserCore>(context);

  context->queueRecordBatch(rb_in);
  context->queueRecordBatch(rb_out);

  uc->reset();

  context->enable();

  uc->setRange(0, num_entries);
  uc->setArguments({1337}); // zip code

  uc->start();

  uc->waitForFinish(10);

  // Get raw pointers to host-side Arrow buffers
  auto sa = std::dynamic_pointer_cast<arrow::StringArray>(rb_out->column(0));

  auto raw_offsets = sa->value_offsets()->mutable_data();
  auto raw_values = sa->value_data()->mutable_data();

  platform->copyDeviceToHost(context->device_arrays[5]->buffers[0].device_address, raw_offsets, 4096);
  platform->copyDeviceToHost(context->device_arrays[5]->buffers[1].device_address, raw_values, 4096);

  //fletcher::HexView hv(0);
  //hv.addData(raw_offsets, sizeof(int32_t) * (num_str+1));
  //hv.addData(raw_values, num_chars);
  //std::cout << hv.toString() << std::endl;
  std::cout << "RecordBatch out:" << std::endl;
  std::cout << sa->ToString() << std::endl;
}
