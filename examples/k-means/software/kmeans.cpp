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
 * Example for k-means with FPGA acceleration
 *
 */
#include <stdlib.h>
#include <stdint.h>
#include <limits>
#include <chrono>
#include <cstdint>
#include <memory>
#include <vector>
#include <utility>
#include <numeric>
#include <iostream>
#include <iomanip>
#include <fstream>
#include <random>

// Apache Arrow
#include <arrow/api.h>

// Fletcher
#include <fletcher/fletcher.h>

// Default to `echo' platform
#ifndef PLATFORM
  #define PLATFORM 0
#endif


namespace chrono = std::chrono;
typedef chrono::high_resolution_clock perf_clock;

using fletcher::fr_t;


void print_centroids(std::vector<std::vector<int64_t>> centroids_position) {
  for (auto const &centroid : centroids_position) {
    std::cout << " (";
    for (int64_t const &dim : centroid) {
      std::cout << dim << "; ";
    }
    std::cout << ")" << std::endl;
  }
}

/**
 * Create an Arrow table containing n columns of random 64-bit numbers.
 */
std::shared_ptr<arrow::Table> create_table(int num_rows, int num_columns) {
  // Set up random number generator
  std::mt19937 rng;
  rng.seed(31415926535);

  // Ensure the sum fits in the return types used by all summing methods.
  // Sum type on FPGA is configurable, sum type on CPU is set as int64_t
  int64_t element_max = 99;  // std::numeric_limits<int64_t>::max() / num_rows;
  std::uniform_int_distribution<int64_t> int_dist(-element_max, element_max);

  // Create arrow builder for appending numbers
  auto int_builder = std::make_shared<arrow::Int64Builder> ();

  // Make a list builder
  arrow::ListBuilder list_builder(
      arrow::default_memory_pool(),
      int_builder);

  std::vector<int64_t> numbers = {
      12, 6,
      14, 3,
      13, 0,
      45, -500,
      51, -520,
  };

  // Create individual lists of given length
  std::cout << "rnd: ";
  for (int row = 0; row < num_rows; row++) {
    // Append single list
    list_builder.Append();
    for (int col = 0; col < num_columns; col++) {
      // Append number to current list
      int64_t rnd_num = int_dist(rng);
      //std::cout << rnd_num << ", ";
      int_builder->Append(numbers[row * num_columns + col]);
    }
  }
  std::cout << std::endl;

  // Define the schema
  std::vector<std::shared_ptr<arrow::Field>> schema_fields = {
      arrow::field("ListOfNumber", arrow::list(arrow::int64()), false),
  };
  auto schema = std::make_shared<arrow::Schema>(schema_fields);

  // Create an array and finish the builder
  std::shared_ptr<arrow::Array> num_array;
  list_builder.Finish(&num_array);

  // Create and return the table
  return std::move(arrow::Table::Make(schema, { num_array }));
}


/**
 * Run k-means on the CPU.
 */
std::vector<std::vector<int64_t>> arrow_kmeans_cpu(std::shared_ptr<arrow::Table> table,
                             std::vector<std::vector<int64_t>> centroids_position,
                             int iteration_limit) {
  // Performance timer open
  auto t1 = perf_clock::now();

  // Probe into the Arrow data structures to extract a pointer to the raw data
  auto points_list = std::static_pointer_cast<arrow::ListArray>(
      table->column(0)->data()->chunk(0));
  auto points = std::static_pointer_cast<arrow::Int64Array>(
      points_list->values());
  const int64_t * data = points->raw_values();

  const size_t num_centroids = centroids_position.size();
  const size_t dimensionality = centroids_position[0].size();
  const int64_t num_rows = table->num_rows();

  auto centroids_position_old = centroids_position;
  int iteration = 0;
  do {
    // Initialize accumulators
    std::vector<int64_t> centroid_accumulator(dimensionality, 0);
    std::vector<std::vector<int64_t>> accumulators(num_centroids, centroid_accumulator);
    std::vector<int64_t> counters(num_centroids, 0);

    // For each point
    for (int64_t n = 0; n < num_rows; n++) {
      // Determine closest centroid for point
      size_t closest = 0;
      int64_t min_distance = std::numeric_limits<int64_t>::max();
      for (size_t c = 0; c < num_centroids; c++) {
        // Get distance to current centroid
        int64_t distance = 0;
        for (size_t d = 0; d < dimensionality; d++) {
          int64_t dim_distance = data[n * dimensionality + d] - centroids_position[c][d];
          distance += dim_distance * dim_distance;
        }
        // Store minimum distance
        if (distance < min_distance) {
          closest = c;
          min_distance = distance;
        }
      }
      // Update counters of closest centroid
      counters[closest]++;
      for (size_t d = 0; d < dimensionality; d++) {
        accumulators[closest][d] += data[n * dimensionality + d];
      }
    }

    centroids_position_old = centroids_position;
    // Calculate new centroid positions
    for (size_t c = 0; c < num_centroids; c++) {
      for (size_t d = 0; d < dimensionality; d++) {
        centroids_position[c][d] = accumulators[c][d] / counters[c];
      }
    }

    iteration++;
  } while (centroids_position != centroids_position_old && iteration < iteration_limit);

  // Performance timer close
  auto t2 = perf_clock::now();
  chrono::duration<double> time_span = chrono::duration_cast<chrono::duration<double> >(t2 - t1);
  std::cout << "CPU algorithm time: " << time_span.count() << " seconds" << std::endl;
  return centroids_position;
}


/**
 * Run k-means on an FPGA.
 */
std::vector<std::vector<int64_t>> arrow_kmeans_fpga(std::shared_ptr<arrow::Table> table,
                                                    std::vector<std::vector<int64_t>> centroids_position,
                                                    int iteration_limit) {
  // Create a platform
#if(PLATFORM == 0)
  std::shared_ptr<fletcher::EchoPlatform> platform(new fletcher::EchoPlatform());
#elif(PLATFORM == 1)
  std::shared_ptr<fletcher::AWSPlatform> platform(new fletcher::AWSPlatform());
#elif(PLATFORM == 2)
  std::shared_ptr<fletcher::SNAPPlatform> platform(new fletcher::SNAPPlatform());
#else
  #error "PLATFORM must be 0, 1 or 2"
#endif

  // Performance time open
  auto t1 = perf_clock::now();

  // Prepare the column buffers
  platform->prepare_column_chunks(table->column(0));

  // Performance timer close
  auto t2 = perf_clock::now();
  chrono::duration<double> time_span = chrono::duration_cast<
                                          chrono::duration<double> >(t2 - t1);
  std::cout << "FPGA copy time: " << time_span.count() << " seconds" << std::endl;


  // Create a UserCore
  fletcher::UserCore uc(std::static_pointer_cast<fletcher::FPGAPlatform>(platform));

  // Reset it
  uc.reset();

  // Determine size of table
  fletcher::fr_t last_index = table->num_rows();
  uc.set_range(0, last_index);

  // Set UserCore arguments
  std::vector<fr_t> args;
  for (auto const & centroid : centroids_position) {
    for (int64_t const & dim : centroid) {
      fr_t lo = (uint32_t) (dim & 0xffffffff);
      fr_t hi = (uint32_t) (dim >> 32);
      args.push_back(lo);
      args.push_back(hi);
    }
  }
  args.push_back(iteration_limit);
  uc.set_arguments(args);

  // Read back registers for debugging
  for (int i = 0; i < 19; i++) {
    fletcher::fr_t reg;
    platform->read_mmio(i, &reg);
    std::cout << "FPGA register " << i << ": " << std::hex << reg << std::dec << std::endl;
  }

  // Performance timer open
  t1 = perf_clock::now();

  // Start the FPGA user function
  uc.start();
  uc.wait_for_finish(1000);  // Poll every 1 ms

  // Performance timer close
  t2 = perf_clock::now();
  time_span = chrono::duration_cast<chrono::duration<double>>(t2 - t1);
  std::cout << "FPGA algorithm time: " << time_span.count() << " seconds" << std::endl;

  // Read result
  const int centroids = centroids_position.size();
  const int dimensionality = centroids_position[0].size();
  const int regs_per_dim = 2;
  const int regs_offset = 10;
  for (int c = 0; c < centroids; c++) {
    for (int d = 0; d < dimensionality; d++) {
      const int reg_num = (c * dimensionality + d) * regs_per_dim + regs_offset;
      fletcher::fr_t reg;
      // Read high bits
      platform->read_mmio(reg_num+1, &reg);
      std::cout << "FPGA register " << reg_num+1 << ": " << std::hex << reg << std::dec << std::endl;
      int64_t dim_value = ( (int64_t) reg ) << 32;
      // Read low bits
      platform->read_mmio(reg_num, &reg);
      std::cout << "FPGA register " << reg_num << ": " << std::hex << reg << std::dec << std::endl;
      dim_value |= reg;
      // Save position
      centroids_position[c][d] = dim_value;
    }
  }

  return centroids_position;
}


/**
 * Main function for the example.
 * Generates list of numbers, runs k-means on CPU and on FPGA.
 * Finally compares the results.
 */
int main(int argc, char ** argv) {
  int num_rows = 5;
  int centroids = 2;
  int dimensionality = 2;
  int iteration_limit = 10;

  if (argc >= 2) {
    sscanf(argv[1], "%i", &num_rows);
  }
  if (argc > 3) {
    sscanf(argv[2], "%i", &centroids);
  }
  if (argc >= 4) {
    sscanf(argv[2], "%i", &dimensionality);
  }
  if (argc >= 5) {
    sscanf(argv[2], "%i", &iteration_limit);
  }

  // Create table of random numbers
  std::shared_ptr<arrow::Table> table = create_table(num_rows, dimensionality);

  // Pick starting centroids
  std::vector<std::vector<int64_t>> centroids_position;
  // Probe into the Arrow data structures to extract a pointer to the raw data
  auto points_list = std::static_pointer_cast<arrow::ListArray>(
      table->column(0)->data()->chunk(0));
  auto points = std::static_pointer_cast<arrow::Int64Array>(
      points_list->values());
  const int64_t * points_ptr = points->raw_values();

  for (int n = 0; n < centroids; n++) {
    std::vector<int64_t> centroid_position;
    for (int col = 0; col < dimensionality; col++) {
      centroid_position.push_back(points_ptr[n * dimensionality + col]);
    }
    centroids_position.push_back(centroid_position);
  }

  // Run on CPU
  std::vector<std::vector<int64_t>> result_cpu = arrow_kmeans_cpu(table, centroids_position, iteration_limit);

  // Run on FPGA
  std::vector<std::vector<int64_t>> result_fpga = arrow_kmeans_fpga(table, centroids_position, iteration_limit);

  std::cout << "CPU clusters: " << std::endl;
  print_centroids(result_cpu);
  std::cout << "FPGA clusters: " << std::endl;
  print_centroids(result_fpga);

  // Check whether sums are the same
  int exit_status;
  if (result_fpga == result_cpu) {
    std::cout << "PASS" << std::endl;
    exit_status = EXIT_SUCCESS;
  } else {
    std::cout << "ERROR" << std::endl;
    exit_status = EXIT_FAILURE;
  }
  return exit_status;
}
