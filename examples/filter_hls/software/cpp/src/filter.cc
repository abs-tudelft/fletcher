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

#include <arrow/api.h>
#include "fletcher/api.h"

#include "person.h"

std::shared_ptr<arrow::RecordBatch> getSimRB() {
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
      arrow::RecordBatch::Make(getReadSchema(), fn_array->length(), {fn_array, ln_array, zip_array});

  return record_batch;
}

std::shared_ptr<arrow::RecordBatch> getOutputRB(int32_t num_entries, int32_t num_chars) {
  std::shared_ptr<arrow::MutableBuffer> offsets;
  std::shared_ptr<arrow::MutableBuffer> values;

  std::shared_ptr<arrow::Buffer> off_b = std::dynamic_pointer_cast<arrow::Buffer>(offsets);
  std::shared_ptr<arrow::Buffer> val_b = std::dynamic_pointer_cast<arrow::Buffer>(values);

  arrow::AllocateBuffer(sizeof(int32_t) * (num_entries + 1), &off_b);
  arrow::AllocateBuffer(num_chars, &val_b);
  auto sa = std::make_shared<arrow::StringArray>(2, off_b, val_b);
  std::shared_ptr<arrow::RecordBatch> record_batch = arrow::RecordBatch::Make(getWriteSchema(), 2, {sa});
  return record_batch;
}

std::shared_ptr<std::vector<std::string>> filterVec(std::shared_ptr<std::vector<Person>> dataset,
                                                    const std::string &last_name,
                                                    zip_t zip) {
  auto ret = std::make_shared<std::vector<std::string>>();
  ret->reserve(dataset->size());

  for (const auto &person : *dataset) {
    if ((person.last_name == last_name) && (person.zip_code == zip)) {
      ret->push_back(person.first_name);
    }
  }

  return ret;
}

std::shared_ptr<arrow::StringArray> filterArrow(std::shared_ptr<arrow::RecordBatch> dataset,
                                                const std::string &last_name,
                                                zip_t zip) {

  std::shared_ptr<arrow::Array> result;

  arrow::StringBuilder sb;
  sb.Reserve(dataset->num_rows());

  auto fna = std::dynamic_pointer_cast<arrow::StringArray>(dataset->column(0));
  auto lna = std::dynamic_pointer_cast<arrow::StringArray>(dataset->column(1));
  auto zipa = std::dynamic_pointer_cast<arrow::UInt32Array>(dataset->column(2));

  arrow::util::string_view sv(last_name);

  for (int32_t i = 0; i < dataset->num_rows(); i++) {
    if ((lna->GetView(i) == sv) && (zipa->Value(i) == zip)) {
      sb.Append(fna->GetView(i));
    }
  }

  sb.Finish(&result);

  return std::dynamic_pointer_cast<arrow::StringArray>(result);
}

