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

#include <cassert>
#include <arrow/api.h>

#include "fletcher/test_schemas.h"

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
  assert(string_builder.AppendValues(names).ok());
  // Array to hold Arrow formatted string data
  std::shared_ptr<arrow::Array> data_array;
  // Finish building and create a new data array around the data
  assert(string_builder.Finish(&data_array).ok());
  // Create the Record Batch
  std::shared_ptr<arrow::RecordBatch>
      record_batch = arrow::RecordBatch::Make(GetStringReadSchema(), names.size(), {data_array});
  return record_batch;
}

inline std::shared_ptr<arrow::RecordBatch> GetIntRB() {
  std::vector<int8_t> numbers = {-1, 3, -3, 7};
  // Make a string builder
  arrow::Int8Builder int_builder;
  assert(int_builder.AppendValues(numbers).ok());
  // Array to hold Arrow formatted string data
  std::shared_ptr<arrow::Array> data_array;
  // Finish building and create a new data array around the data
  assert(int_builder.Finish(&data_array).ok());
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
    assert(lb->Append().ok());
    assert(vb->AppendValues(number).ok());
  }
  // Array to hold Arrow formatted string data
  std::shared_ptr<arrow::Array> a;
  // Finish building and create a new data array around the data
  assert(lb->Finish(&a).ok());
  // Create the Record Batch
  std::shared_ptr<arrow::RecordBatch>
      record_batch = arrow::RecordBatch::Make(GetListUint8Schema(), numbers.size(), {a});

  return record_batch;
}

inline std::shared_ptr<arrow::RecordBatch> GetFloat64RB() {
  std::vector<double> numbers = {1.2, 0.6, 1.4, 0.3, 4.5, -1.2, 5.1, -1.3,};
  // Make a float builder
  auto float_builder = std::make_shared<arrow::DoubleBuilder>();
  // Make a list builder
  arrow::ListBuilder list_builder(
      arrow::default_memory_pool(),
      float_builder);
  // Create individual lists of this length
  const unsigned int list_length = 2;
  for (unsigned int list_start = 0; list_start < numbers.size(); list_start += list_length) {
    // Append single list
    assert(list_builder.Append().ok());
    for (unsigned int index = list_start; index < list_start + list_length; index++) {
      // Append number to current list
      assert(float_builder->Append(numbers[index]).ok());
    }
  }
  // Array to hold Arrow formatted data
  std::shared_ptr<arrow::Array> data_array;
  // Finish building and create a new data array around the data
  assert(list_builder.Finish(&data_array).ok());
  // Create the Record Batch
  auto record_batch = arrow::RecordBatch::Make(GetListFloatSchema(), numbers.size() / list_length, {data_array});
  // Check whether the Record Batch is alright
  assert(record_batch->Validate().ok());
  return record_batch;
}

inline std::shared_ptr<arrow::RecordBatch> GetInt64RB() {
  std::vector<int64_t> numbers = {12, 6, 14, 3, 13, 0, 45, -500, 51, -520,};
  // Make an int builder
  auto int_builder = std::make_shared<arrow::Int64Builder>();
  // Make a list builder
  arrow::ListBuilder list_builder(
      arrow::default_memory_pool(),
      int_builder);
  // Create individual lists of this length
  const unsigned int list_length = 2;
  for (unsigned int list_start = 0; list_start < numbers.size(); list_start += list_length) {
    // Append single list
    assert(list_builder.Append().ok());
    for (unsigned int index = list_start; index < list_start + list_length; index++) {
      // Append number to current list
      assert(int_builder->Append(numbers[index]).ok());
    }
  }
  // Array to hold Arrow formatted data
  std::shared_ptr<arrow::Array> data_array;
  // Finish building and create a new data array around the data
  assert(list_builder.Finish(&data_array).ok());
  // Create the Record Batch
  auto record_batch = arrow::RecordBatch::Make(GetListIntSchema(), numbers.size() / list_length, {data_array});
  // Check whether the RecordBatch is alright
  assert(record_batch->Validate().ok());
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
  for (unsigned int list_start = 0; list_start < numbers.size(); list_start += list_length) {
    // Append single list
    assert(list_builder.Append().ok());
    for (unsigned int index = list_start; index < list_start + list_length; index++) {
      // Append number to current list
      assert(int_builder->Append(numbers[index]).ok());
    }
  }
  // Array to hold Arrow formatted data
  std::shared_ptr<arrow::Array> data_array;
  // Finish building and create a new data array around the data
  assert(list_builder.Finish(&data_array).ok());
  // Create the Record Batch
  auto record_batch = arrow::RecordBatch::Make(GetListIntSchema(), numbers.size() / list_length, {data_array});
  // Check whether the Record Batch is alright
  assert(record_batch->Validate().ok());
  return record_batch;
}

inline std::shared_ptr<arrow::RecordBatch> GetStructRB() {
  auto schema = fletcher::GetStructSchema();
  auto ab = std::make_shared<arrow::UInt16Builder>();
  auto bb = std::make_shared<arrow::UInt32Builder>();
  arrow::StructBuilder sb(schema->field(0)->type(), arrow::default_memory_pool(), {ab, bb});
  assert(ab->AppendValues({1, 3, 3, 7}).ok());
  assert(bb->AppendValues({3, 1, 4, 1}).ok());
  const uint8_t valid_bytes[4] = {1, 1, 1, 1};
  assert(sb.AppendValues(4, valid_bytes).ok());
  std::shared_ptr<arrow::Array> arr;
  assert(sb.Finish(&arr).ok());
  auto record_batch = arrow::RecordBatch::Make(schema, 4, {arr});
  assert(record_batch->Validate().ok());
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
  assert(fn_builder.AppendValues(first_names).ok());
  assert(ln_builder.AppendValues(last_names).ok());
  assert(zip_builder.AppendValues(zip_codes).ok());
  // Array to hold Arrow formatted string data
  std::shared_ptr<arrow::Array> fn_array;
  std::shared_ptr<arrow::Array> ln_array;
  std::shared_ptr<arrow::Array> zip_array;
  // Finish building and create a new data arr1ay around the data
  assert(fn_builder.Finish(&fn_array).ok());
  assert(ln_builder.Finish(&ln_array).ok());
  assert(zip_builder.Finish(&zip_array).ok());
  // Create the Record Batch
  auto record_batch =
      arrow::RecordBatch::Make(GetFilterReadSchema(), fn_array->length(), {fn_array, ln_array, zip_array});
  return record_batch;
}

inline std::shared_ptr<arrow::RecordBatch> GetSodaBeerRB(
    const std::shared_ptr<arrow::Schema>& schema,
    const std::vector<std::string> &names,
    const std::vector<uint8_t> &ages) {
  assert(names.size() == ages.size());
  // Make a string builder
  arrow::StringBuilder name_builder;
  arrow::UInt8Builder age_builder;
  // Append the strings in the string builder
  assert(name_builder.AppendValues(names).ok());
  assert(age_builder.AppendValues(ages).ok());
  // Array to hold Arrow formatted string data
  std::shared_ptr<arrow::Array> name_array;
  std::shared_ptr<arrow::Array> age_array;
  // Finish building and create a new data array around the data
  assert(name_builder.Finish(&name_array).ok());
  assert(age_builder.Finish(&age_array).ok());
  // Create the Record Batch
  auto record_batch = arrow::RecordBatch::Make(schema, name_array->length(), {name_array, age_array});
  return record_batch;
}

}  // namespace fletcher
