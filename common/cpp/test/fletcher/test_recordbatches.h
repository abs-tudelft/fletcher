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

#pragma once

#include <arrow/api.h>
#include <string>
#include <memory>
#include <vector>

#include "fletcher/test_schemas.h"

#define THROW_NOT_OK(status) if (!status.ok()) throw std::runtime_error(status.ToString())

namespace fletcher {

inline std::shared_ptr<arrow::RecordBatch> GetStringRB() {
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
  THROW_NOT_OK(string_builder.AppendValues(names));
  // Array to hold Arrow formatted string data
  std::shared_ptr<arrow::Array> data_array;
  // Finish building and create a new data array around the data
  THROW_NOT_OK(string_builder.Finish(&data_array));
  // Create the Record Batch
  std::shared_ptr<arrow::RecordBatch>
      record_batch = arrow::RecordBatch::Make(GetStringReadSchema(), names.size(), {data_array});
  return record_batch;
}

inline std::shared_ptr<arrow::RecordBatch> GetTwoPrimReadRB() {
  std::vector<int8_t> a = {-1, 3, -3, 7};
  std::vector<uint16_t> b = {6, 1, 7, 4};
  // Make a string builder
  arrow::Int8Builder a_builder;
  arrow::UInt16Builder b_builder;
  THROW_NOT_OK(a_builder.AppendValues(a));
  THROW_NOT_OK(b_builder.AppendValues(b));
  std::shared_ptr<arrow::Array> a_array;
  std::shared_ptr<arrow::Array> b_array;
  THROW_NOT_OK(a_builder.Finish(&a_array));
  THROW_NOT_OK(b_builder.Finish(&b_array));
  // Create the Record Batch
  auto record_batch = arrow::RecordBatch::Make(GetTwoPrimReadSchema(), 4, {a_array, b_array});
  return record_batch;
}

inline std::shared_ptr<arrow::RecordBatch> GetIntRB() {
  std::vector<int8_t> numbers = {-1, 3, -3, 7};
  // Make a string builder
  arrow::Int8Builder int_builder;
  THROW_NOT_OK(int_builder.AppendValues(numbers));

  std::shared_ptr<arrow::Array> data_array;
  // Finish building and create a new data array around the data
  THROW_NOT_OK(int_builder.Finish(&data_array));
  // Create the Record Batch
  std::shared_ptr<arrow::RecordBatch>
      record_batch = arrow::RecordBatch::Make(GetPrimReadSchema(), numbers.size(), {data_array});
  return record_batch;
}

inline std::shared_ptr<arrow::RecordBatch> GetListUint8RB() {
  std::vector<std::vector<uint8_t>> numbers = {{1, 3, 3, 7}, {3, 1, 4, 1, 5, 9, 2}, {4, 2}};

  auto vb = std::make_shared<arrow::UInt8Builder>();
  auto lb = std::make_shared<arrow::ListBuilder>(arrow::default_memory_pool(), vb);

  for (const auto &number : numbers) {
    THROW_NOT_OK(lb->Append());
    THROW_NOT_OK(vb->AppendValues(number));
  }
  // Array to hold Arrow formatted string data
  std::shared_ptr<arrow::Array> a;
  // Finish building and create a new data array around the data
  THROW_NOT_OK(lb->Finish(&a));
  // Create the Record Batch
  std::shared_ptr<arrow::RecordBatch>
      record_batch = arrow::RecordBatch::Make(GetListUint8Schema(), numbers.size(), {a});

  return record_batch;
}

inline std::shared_ptr<arrow::RecordBatch> GetFloat64RB() {
  std::vector<double> numbers = {1.2, 0.6, 1.4, 0.3, 4.5, -1.2, 5.1, -1.3};
  // Make a float builder
  auto float_builder = std::make_shared<arrow::DoubleBuilder>();
  // Make a list builder
  arrow::ListBuilder list_builder(
      arrow::default_memory_pool(),
      float_builder);
  // Create individual lists of this length
  const unsigned int list_length = 2;
  for (size_t list_start = 0; list_start < numbers.size(); list_start += list_length) {
    // Append single list
    THROW_NOT_OK(list_builder.Append());
    for (size_t index = list_start; index < list_start + list_length; index++) {
      // Append number to current list
      THROW_NOT_OK(float_builder->Append(numbers[index]));
    }
  }
  // Array to hold Arrow formatted data
  std::shared_ptr<arrow::Array> data_array;
  // Finish building and create a new data array around the data
  THROW_NOT_OK(list_builder.Finish(&data_array));
  // Create the Record Batch
  auto record_batch = arrow::RecordBatch::Make(GetListFloatSchema(), numbers.size() / list_length, {data_array});
  // Check whether the Record Batch is alright
  THROW_NOT_OK(record_batch->Validate());
  return record_batch;
}

inline std::shared_ptr<arrow::RecordBatch> GetInt64RB() {
  std::vector<int64_t> numbers = {12, 6, 14, 3, 13, 0, 45, -500, 51, -520};
  // Make an int builder
  auto int_builder = std::make_shared<arrow::Int64Builder>();
  // Make a list builder
  arrow::ListBuilder list_builder(
      arrow::default_memory_pool(),
      int_builder);
  // Create individual lists of this length
  const unsigned int list_length = 2;
  for (size_t list_start = 0; list_start < numbers.size(); list_start += list_length) {
    // Append single list
    THROW_NOT_OK(list_builder.Append());
    for (size_t index = list_start; index < list_start + list_length; index++) {
      // Append number to current list
      THROW_NOT_OK(int_builder->Append(numbers[index]));
    }
  }
  // Array to hold Arrow formatted data
  std::shared_ptr<arrow::Array> data_array;
  // Finish building and create a new data array around the data
  THROW_NOT_OK(list_builder.Finish(&data_array));
  // Create the Record Batch
  auto record_batch = arrow::RecordBatch::Make(GetListIntSchema(), numbers.size() / list_length, {data_array});
  // Check whether the RecordBatch is alright
  THROW_NOT_OK(record_batch->Validate());
  return record_batch;
}

inline std::shared_ptr<arrow::RecordBatch> GetInt64ListWideRB() {
  std::vector<int64_t> numbers = {12, 6, 110, 120, 130, 140, 150, -160,
                                  14, 3, 111, 121, 131, 141, 151, -161,
                                  13, 0, 112, 122, 132, 142, 152, -162,
                                  45, -500, 210, 220, 230, 240, 250, -260,
                                  51, -520, 211, 221, 231, 241, 151, -261};
  // Make an int builder
  auto int_builder = std::make_shared<arrow::Int64Builder>();
  // Make a list builder
  arrow::ListBuilder list_builder(arrow::default_memory_pool(), int_builder);
  // Create individual lists of this length
  const unsigned int list_length = 8;
  for (size_t list_start = 0; list_start < numbers.size(); list_start += list_length) {
    // Append single list
    THROW_NOT_OK(list_builder.Append());
    for (size_t index = list_start; index < list_start + list_length; index++) {
      // Append number to current list
      THROW_NOT_OK(int_builder->Append(numbers[index]));
    }
  }
  // Array to hold Arrow formatted data
  std::shared_ptr<arrow::Array> data_array;
  // Finish building and create a new data array around the data
  THROW_NOT_OK(list_builder.Finish(&data_array));
  // Create the Record Batch
  auto record_batch = arrow::RecordBatch::Make(GetListIntSchema(), numbers.size() / list_length, {data_array});
  // Check whether the Record Batch is alright
  THROW_NOT_OK(record_batch->Validate());
  return record_batch;
}

inline std::shared_ptr<arrow::RecordBatch> GetStructRB() {
  auto schema = fletcher::GetStructSchema();
  auto ab = std::make_shared<arrow::UInt16Builder>();
  auto bb = std::make_shared<arrow::UInt32Builder>();
  arrow::StructBuilder sb(schema->field(0)->type(), arrow::default_memory_pool(), {ab, bb});
  THROW_NOT_OK(ab->AppendValues({1, 3, 3, 7}));
  THROW_NOT_OK(bb->AppendValues({3, 1, 4, 1}));
  const uint8_t valid_bytes[4] = {1, 1, 1, 1};
  THROW_NOT_OK(sb.AppendValues(4, valid_bytes));
  std::shared_ptr<arrow::Array> arr;
  THROW_NOT_OK(sb.Finish(&arr));
  auto record_batch = arrow::RecordBatch::Make(schema, 4, {arr});
  THROW_NOT_OK(record_batch->Validate());
  return record_batch;
}

inline std::shared_ptr<arrow::RecordBatch> GetFilterRB() {
  // Some first names
  std::vector<std::string> first_names = {"Alice", "Bob", "Carol", "David"};
  std::vector<std::string> last_names = {"Cooper", "Smith", "Smith", "Smith"};
  std::vector<uint32_t> zip_codes = {1337, 4242, 1337, 1337};
  // Make a string builder
  arrow::StringBuilder fn_builder;
  arrow::StringBuilder ln_builder;
  arrow::UInt32Builder zip_builder;
  // Append the strings in the string builder
  THROW_NOT_OK(fn_builder.AppendValues(first_names));
  THROW_NOT_OK(ln_builder.AppendValues(last_names));
  THROW_NOT_OK(zip_builder.AppendValues(zip_codes));
  // Array to hold Arrow formatted string data
  std::shared_ptr<arrow::Array> fn_array;
  std::shared_ptr<arrow::Array> ln_array;
  std::shared_ptr<arrow::Array> zip_array;
  // Finish building and create a new data arr1ay around the data
  THROW_NOT_OK(fn_builder.Finish(&fn_array));
  THROW_NOT_OK(ln_builder.Finish(&ln_array));
  THROW_NOT_OK(zip_builder.Finish(&zip_array));
  // Create the Record Batch
  auto record_batch =
      arrow::RecordBatch::Make(GetFilterReadSchema(), fn_array->length(), {fn_array, ln_array, zip_array});
  return record_batch;
}

inline std::shared_ptr<arrow::RecordBatch> GetSodaBeerRB(
    const std::shared_ptr<arrow::Schema> &schema,
    const std::vector<std::string> &names,
    const std::vector<uint8_t> &ages) {
  if (names.size() != ages.size()) {
    throw std::runtime_error("Names and ages must be same size.");
  }
  // Make a string builder
  arrow::StringBuilder name_builder;
  arrow::UInt8Builder age_builder;
  // Append the strings in the string builder
  THROW_NOT_OK(name_builder.AppendValues(names));
  THROW_NOT_OK(age_builder.AppendValues(ages));
  // Array to hold Arrow formatted string data
  std::shared_ptr<arrow::Array> name_array;
  std::shared_ptr<arrow::Array> age_array;
  // Finish building and create a new data array around the data
  THROW_NOT_OK(name_builder.Finish(&name_array));
  THROW_NOT_OK(age_builder.Finish(&age_array));
  // Create the Record Batch
  auto record_batch = arrow::RecordBatch::Make(schema, name_array->length(), {name_array, age_array});
  return record_batch;
}

}  // namespace fletcher
