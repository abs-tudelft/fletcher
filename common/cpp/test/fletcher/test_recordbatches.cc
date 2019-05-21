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

#include <arrow/record_batch.h>
#include <arrow/builder.h>

#include "fletcher/test_schemas.h"
#include "fletcher/test_recordbatches.h"

namespace fletcher {

std::shared_ptr<arrow::RecordBatch> getStringRB() {
  // Some names
  std::vector<std::string> names = {"Alice", "Bob", "Carol", "David",
                                    "Eve", "Frank", "Grace", "Harry",
                                    "Isolde", "Jack", "Karen", "Leonard",
                                    "Mary", "Nick", "Olivia", "Peter",
                                    "Quinn", "Robert", "Sarah", "Travis",
                                    "Uma", "Victor", "Wendy", "Xavier",
                                    "Yasmine", "Zachary"
  };

  // Make a string builder
  arrow::StringBuilder string_builder;

  // Append the strings in the string builder
  if (!string_builder.AppendValues(names).ok()) {
    throw std::runtime_error("Could not append strings to string builder.");
  }

  // Array to hold Arrow formatted string data
  std::shared_ptr<arrow::Array> data_array;

  // Finish building and create a new data array around the data
  if (!string_builder.Finish(&data_array).ok()) {
    throw std::runtime_error("Could not finalize string builder.");
  }

  // Create the Record Batch
  std::shared_ptr<arrow::RecordBatch>
      record_batch = arrow::RecordBatch::Make(GetStringReadSchema(), names.size(), {data_array});

  return record_batch;
}

std::shared_ptr<arrow::RecordBatch> getInt8RB() {
  std::vector<int8_t> numbers = {-1, 3, -3, 7};

  // Make a string builder
  arrow::Int8Builder int_builder;

  int_builder.AppendValues(numbers);

  // Array to hold Arrow formatted string data
  std::shared_ptr<arrow::Array> data_array;

  // Finish building and create a new data array around the data
  if (!int_builder.Finish(&data_array).ok()) {
    throw std::runtime_error("Could not finalize string builder.");
  }

  // Create the Record Batch
  std::shared_ptr<arrow::RecordBatch>
      record_batch = arrow::RecordBatch::Make(GetPrimReadSchema(), numbers.size(), {data_array});

  return record_batch;
}

std::shared_ptr<arrow::RecordBatch> getListUint8RB() {

  std::vector<std::vector<uint8_t>> numbers = {{1, 3, 3, 7}, {3, 1, 4, 1, 5, 9, 2}, {4, 2}};

  auto vb = std::make_shared<arrow::UInt8Builder>();
  auto lb = std::make_shared<arrow::ListBuilder>(arrow::default_memory_pool(), vb);

  for (const auto &number : numbers) {
    if (!lb->Append().ok()) {
      throw std::runtime_error("Could not append to offsets buffer.");
    }
    if (!vb->AppendValues(number).ok()) {
      throw std::runtime_error("Could not append to values buffer.");
    }
  }

  // Array to hold Arrow formatted string data
  std::shared_ptr<arrow::Array> a;

  // Finish building and create a new data array around the data
  if (!lb->Finish(&a).ok()) {
    throw std::runtime_error("Could not finalize list<uint8> builder.");
  };

  // Create the Record Batch
  std::shared_ptr<arrow::RecordBatch>
      record_batch = arrow::RecordBatch::Make(GetListUint8Schema(), numbers.size(), {a});

  return record_batch;
}

std::shared_ptr<arrow::RecordBatch> getFloat64ListRB() {
  std::vector<double> numbers = {
      1.2, 0.6,
      1.4, 0.3,
      4.5, -1.2,
      5.1, -1.3,
    };

  // Make a float builder
  auto float_builder = std::make_shared<arrow::DoubleBuilder> ();

  // Make a list builder
  arrow::ListBuilder list_builder(
      arrow::default_memory_pool(),
      float_builder);

  // Create individual lists of this length
  const unsigned int list_length = 2;
  for (unsigned int list_start = 0; list_start < numbers.size(); list_start += list_length) {
    // Append single list
    list_builder.Append();
    for (unsigned int index = list_start; index < list_start + list_length; index++) {
      // Append number to current list
      float_builder->Append(numbers[index]);
    }
  }

  // Array to hold Arrow formatted data
  std::shared_ptr<arrow::Array> data_array;

  // Finish building and create a new data array around the data
  if (!list_builder.Finish(&data_array).ok()) {
    throw std::runtime_error("Could not finalize list builder.");
  }

  // Create the Record Batch
  std::shared_ptr<arrow::RecordBatch>
      record_batch = arrow::RecordBatch::Make(
      GetListFloatSchema(),
          numbers.size() / list_length,
          {data_array});

  // Check whether the Record Batch is alright
  if (!record_batch->Validate().ok()) {
    throw std::runtime_error("Could not create Record Batch.");
  }

  return record_batch;
}

std::shared_ptr<arrow::RecordBatch> getInt64ListRB() {
  std::vector<int64_t> numbers = {
      12, 6,
      14, 3,
      13, 0,
      45, -500,
      51, -520,
  };

  // Make an int builder
  auto int_builder = std::make_shared<arrow::Int64Builder> ();

  // Make a list builder
  arrow::ListBuilder list_builder(
      arrow::default_memory_pool(),
      int_builder);

  // Create individual lists of this length
  const unsigned int list_length = 2;
  for (unsigned int list_start = 0; list_start < numbers.size(); list_start += list_length) {
    // Append single list
    list_builder.Append();
    for (unsigned int index = list_start; index < list_start + list_length; index++) {
      // Append number to current list
      int_builder->Append(numbers[index]);
    }
  }

  // Array to hold Arrow formatted data
  std::shared_ptr<arrow::Array> data_array;

  // Finish building and create a new data array around the data
  if (!list_builder.Finish(&data_array).ok()) {
    throw std::runtime_error("Could not finalize list builder.");
  }

  // Create the Record Batch
  std::shared_ptr<arrow::RecordBatch>
      record_batch = arrow::RecordBatch::Make(
      GetListIntSchema(),
      numbers.size() / list_length,
      {data_array});

  // Check whether the Record Batch is alright
  if (!record_batch->Validate().ok()) {
    throw std::runtime_error("Could not create Record Batch.");
  }

  return record_batch;
}

std::shared_ptr<arrow::RecordBatch> getInt64ListWideRB() {
  std::vector<int64_t> numbers = {
      12,    6, 110, 120, 130, 140, 150, -160,
      14,    3, 111, 121, 131, 141, 151, -161,
      13,    0, 112, 122, 132, 142, 152, -162,
      45, -500, 210, 220, 230, 240, 250, -260,
      51, -520, 211, 221, 231, 241, 151, -261,
  };

  // Make an int builder
  auto int_builder = std::make_shared<arrow::Int64Builder> ();

  // Make a list builder
  arrow::ListBuilder list_builder(
      arrow::default_memory_pool(),
      int_builder);

  // Create individual lists of this length
  const unsigned int list_length = 8;
  for (unsigned int list_start = 0; list_start < numbers.size(); list_start += list_length) {
    // Append single list
    list_builder.Append();
    for (unsigned int index = list_start; index < list_start + list_length; index++) {
      // Append number to current list
      int_builder->Append(numbers[index]);
    }
  }

  // Array to hold Arrow formatted data
  std::shared_ptr<arrow::Array> data_array;

  // Finish building and create a new data array around the data
  if (!list_builder.Finish(&data_array).ok()) {
    throw std::runtime_error("Could not finalize list builder.");
  }

  // Create the Record Batch
  std::shared_ptr<arrow::RecordBatch>
      record_batch = arrow::RecordBatch::Make(
      GetListIntSchema(),
      numbers.size() / list_length,
      {data_array});

  // Check whether the Record Batch is alright
  if (!record_batch->Validate().ok()) {
    throw std::runtime_error("Could not create Record Batch.");
  }

  return record_batch;
}

std::shared_ptr<arrow::RecordBatch> getFilterRB() {
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
  std::shared_ptr<arrow::RecordBatch>
      record_batch = arrow::RecordBatch::Make(GetFilterReadSchema(), fn_array->length(), {fn_array, ln_array, zip_array});

  return record_batch;
}

}  // namespace fletcher
