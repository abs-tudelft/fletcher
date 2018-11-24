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

/**
 * Example for summing a list with FPGA acceleration
 *
 */
#include <chrono>
#include <cstdint>
#include <memory>
#include <vector>
#include <numeric>
#include <iostream>
#include <iomanip>
#include <fstream>
#include <random>
#include <stdlib.h>
#include <stdint.h>
#include <limits.h>

// Apache Arrow
#include <arrow/api.h>

// Fletcher
#include "fletcher/api.h"

using std::shared_ptr;
using std::numeric_limits;
using std::vector;
using std::static_pointer_cast;

/**
 * Create an Arrow table containing one column of random 64-bit numbers.
 */
shared_ptr<arrow::RecordBatch> createRecordBatch(int num_rows) {
  // Set up random number generator
  std::mt19937 rng;
  rng.seed(0);

  // Uniformly distributed numbers between 0 and 1
  std::uniform_int_distribution<int64_t> int_dist(0, 1);

  // Create arrow builder for appending numbers
  arrow::Int64Builder int_builder(arrow::default_memory_pool());

  // Generate all rows and fill with random numbers
  for (int i = 0; i < num_rows; i++) {
    int64_t rnd_num = int_dist(rng);
    int_builder.Append(rnd_num);
  }

  // Define the schema
  auto column_field = arrow::field("weight", arrow::int64(), false);
  vector<shared_ptr<arrow::Field>> fields = {column_field};
  shared_ptr<arrow::Schema> schema = std::make_shared<arrow::Schema>(fields);

  // Create an array and finish the builder
  shared_ptr<arrow::Array> num_array;
  int_builder.Finish(&num_array);

  // Create and return the table
  return arrow::RecordBatch::Make(schema, num_rows, {num_array});
}

/**
 * Calculate the sum of all numbers in the arrow column using the CPU.
 */
int64_t sumCPU(const shared_ptr<arrow::RecordBatch> &recordbatch) {
  // Get data pointer
  auto num_array = static_pointer_cast<arrow::Int64Array>(recordbatch->column(0));
  const int64_t *data = num_array->raw_values();
  // Sum loop
  int64_t sum = 0;
  for (int i = 0; i < num_array->length(); i++) {
    sum += data[i];
  }
  return sum;
}

/**
 * Calculate the sum of all numbers in the arrow column using an FPGA.
 */
int64_t sumFPGA(const shared_ptr<arrow::RecordBatch> &recordbatch) {
  fletcher::Timer t;
  std::shared_ptr<fletcher::Platform> platform;
  std::shared_ptr<fletcher::Context> context;
  dau_t ret;

  // Create a platform
  fletcher::Platform::Make(&platform).ewf();

  // Create a context
  fletcher::Context::Make(&context, platform);

  // Create a UserCore
  fletcher::UserCore uc(context);

  // Initialize the platform.
  platform->init().ewf();

  // Reset it
  uc.reset();

  // Prepare the RecordBatch
  t.start();
  context->queueRecordBatch(recordbatch);
  context->enable();
  t.stop();
  std::cout << "FPGA dataset prepare time (s): " << t.seconds() << std::endl;


  // Determine size of table
  auto last_index = (int32_t) recordbatch->num_rows();
  uc.setRange(0, last_index);

  // Start the FPGA user function
  t.start();
  uc.start();
  uc.waitForFinish(1000);  // Poll every 1 ms
  uc.getReturn(&ret.lo, &ret.hi);  // Get the sum from the UserCore
  t.stop();

  std::cout << "Sum FPGA time (s): " << t.seconds() << " seconds" << std::endl;
  std::cout << "Result: " << ret.full << std::endl;

  return ret.full;
}

/**
 * Main function for the summing example.
 * Generates list of numbers, sums them on CPU and on FPGA.
 * Finally compares the results.
 */
int main(int argc, char **argv) {
  fletcher::Timer t;
  uint32_t num_rows = 1024;

  if (argc >= 2) {
    num_rows = (uint32_t)std::strtoul(argv[1], nullptr, 10);
  }
  if (num_rows > INT_MAX) {
    std::cout << "Too many rows" << std::endl;
    return EXIT_FAILURE;
  }

  // Create table of random numbers
  shared_ptr<arrow::RecordBatch> recordbatch = createRecordBatch(num_rows);

  // Sum on CPU
  t.start();
  int64_t sum_cpu = sumCPU(recordbatch);
  t.stop();
  std::cout << "CPU run time (s): " << t.seconds() << std::endl;
  std::cout << "CPU sum : " << sum_cpu << std::endl;

  // Sum on FPGA
  int64_t sum_fpga = sumFPGA(recordbatch);

  // Check whether sums are the same
  int exit_status;
  if ((uintmax_t) sum_fpga == (uintmax_t) sum_cpu) {
    std::cout << "PASS" << std::endl;
    exit_status = EXIT_SUCCESS;
  } else {
    std::cout << "ERROR" << std::endl;
    exit_status = EXIT_FAILURE;
  }
  return exit_status;
}
