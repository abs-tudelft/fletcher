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

#include "test_schemas.h"

#include "test_recordbatches.h"

namespace fletchgen {
namespace test {

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
  };

  // Array to hold Arrow formatted string data
  std::shared_ptr<arrow::Array> data_array;

  // Finish building and create a new data array around the data
  if (!string_builder.Finish(&data_array).ok()) {
    throw std::runtime_error("Could not finalize string builder.");
  };

  // Create the Record Batch
  std::shared_ptr<arrow::RecordBatch>
      record_batch = arrow::RecordBatch::Make(genStringSchema(), names.size(), {data_array});

  return record_batch;
}

std::shared_ptr<arrow::RecordBatch> getUint8RB() {

  std::vector<uint8_t> numbers = {1, 3, 3, 7};

  // Make a string builder
  arrow::UInt8Builder int_builder;

  int_builder.AppendValues(numbers);

  // Array to hold Arrow formatted string data
  std::shared_ptr<arrow::Array> data_array;

  // Finish building and create a new data array around the data
  if (!int_builder.Finish(&data_array).ok()) {
    throw std::runtime_error("Could not finalize string builder.");
  };

  // Create the Record Batch
  std::shared_ptr<arrow::RecordBatch>
      record_batch = arrow::RecordBatch::Make(genPrimReadSchema(), numbers.size(), {data_array});

  return record_batch;
}

}
}