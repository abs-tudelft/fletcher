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
#include <fletcher/fletcher.h>

// Default to `echo' platform
#ifndef PLATFORM
  #define PLATFORM 0
#endif

using namespace std;

intmax_t sum_check = 0;

/**
 * Create an Arrow table containing one column of random 64-bit numbers.
 */
shared_ptr<arrow::Table> create_table(int num_rows)
{
  // Set up random number generator
  std::mt19937 rng;
  rng.seed(0);
  // Ensure the sum fits in the return types used by all summing methods
  int64_t element_max = min(
    (uintmax_t) numeric_limits<int64_t>::max() / num_rows, // arrow data type,
    min(
      (uintmax_t) numeric_limits<long long int>::max() / num_rows, // return type on CPU
      (uintmax_t) numeric_limits<fletcher::fa_t>::max() / num_rows // return type on FPGA
    )
  );
  std::uniform_int_distribution<int64_t> int_dist(0, element_max);

  // Create arrow builder for appending numbers
  arrow::Int64Builder int_builder(arrow::default_memory_pool());

  // Generate all rows and fill with random numbers
  for (int i = 0; i < num_rows; i++) {
    int64_t rnd_num = int_dist(rng);
    sum_check += rnd_num;
    int_builder.Append(rnd_num);
  }

  // Define the schema
  auto column_field = arrow::field("weight", arrow::int64(), false);
  vector<shared_ptr<arrow::Field>> fields = { column_field };
  shared_ptr<arrow::Schema> schema = make_shared<arrow::Schema>(fields);

  // Create an array and finish the builder
  shared_ptr<arrow::Array> num_array;
  int_builder.Finish(&num_array);

  // Create and return the table
  return move(arrow::Table::Make(schema, { num_array }));
}


/**
 * Calculate the sum of all numbers in the arrow column using the CPU.
 */
long long int arrow_column_sum_cpu(shared_ptr<arrow::Table> table)
{
  auto num_array = static_pointer_cast<arrow::Int64Array>(table->column(0)->data()->chunk(0));
  const int64_t *data = num_array->raw_values();
  long long int sum = 0;
  for (int i = 0; i < num_array->length(); i++) {
    sum += data[i];
  }
  return sum;
}


/**
 * Calculate the sum of all numbers in the arrow column using an FPGA.
 */
fletcher::fa_t arrow_column_sum_fpga(shared_ptr<arrow::Table> table)
{
  // Create a platform
#if(PLATFORM == 0)
  shared_ptr<fletcher::EchoPlatform> platform(new fletcher::EchoPlatform());
#elif(PLATFORM == 1)
  shared_ptr<fletcher::AWSPlatform> platform(new fletcher::AWSPlatform());
#elif(PLATFORM == 2)
  shared_ptr<fletcher::SNAPPlatform> platform(new fletcher::SNAPPlatform());
#else
  #error "PLATFORM must be 0, 1 or 2"
#endif

  // Prepare the colummn buffers
  platform->prepare_column_chunks(table->column(0));

  // Create a UserCore
  fletcher::UserCore uc(static_pointer_cast<fletcher::FPGAPlatform>(platform));

  // Reset it
  uc.reset();

  // Determine size of table
  fletcher::fr_t last_index = table->num_rows();
  uc.set_range(0, last_index);

  // Read back
  for (int i = 0; i < 6; i++)
  {
    fletcher::fr_t reg;
    platform->read_mmio(i, &reg);
    cout << "fpga register " << i << ": " << std::hex << reg << endl;
  }

  // Start the FPGA user function
  uc.start();
  uc.wait_for_finish(10000); // Poll every 10 ms

  // Get the sum from the UserCore
  fletcher::fa_t sum_fpga = uc.get_return();

  return sum_fpga;
}


/**
 * Main function for the summing example.
 * Generates list of numbers, sums them on CPU and on FPGA.
 * Finally compares the results.
 */
int main(int argc, char ** argv)
{
  unsigned int num_rows = 1024;

  if (argc >= 2) {
    sscanf(argv[1], "%u", &num_rows);
  }
  if (num_rows > INT_MAX) {
    cout << "Too many rows" << endl;
    return EXIT_FAILURE;
  }

  // Create table of random numbers
  shared_ptr<arrow::Table> table = create_table(num_rows);

  // Sum on CPU
  long long int sum_cpu = arrow_column_sum_cpu(table);

  // Sum on FPGA
  fletcher::fa_t sum_fpga = arrow_column_sum_fpga(table);

  cout << "expected sum: " << sum_cpu << endl;
  cout << "fpga sum: " << sum_fpga << endl;
  // Check whether sums are the same
  int exit_status;
  if ((uintmax_t) sum_fpga == (uintmax_t) sum_cpu) {
    cout << "PASS" << endl;
    exit_status = EXIT_SUCCESS;
  } else {
    cout << "ERROR" << endl;
    exit_status = EXIT_FAILURE;
  }
  return exit_status;
}

