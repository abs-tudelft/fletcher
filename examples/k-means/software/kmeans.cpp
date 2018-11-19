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
#include <fletcher/platform.h>
#include <fletcher/context.h>
#include <fletcher/usercore.h>
#include <fletcher/common/timer.h>


using fletcher::Timer;

typedef int64_t kmeans_t;
typedef arrow::Int64Type arrow_t;


void print_centroids(const std::vector<std::vector<kmeans_t>> &centroids_position) {
  for (auto const &centroid : centroids_position) {
    std::cout << " (";
    for (kmeans_t const &dim : centroid) {
      std::cout << dim << "; ";
    }
    std::cout << ")" << std::endl;
  }
}


std::vector<std::vector<kmeans_t>> create_data(int num_rows, int num_columns) {
  // Set up random number generator
  std::mt19937 rng;
  rng.seed(31415926535);

  // Ensure the sum fits in the return types used by all summing methods.
  // Sum type on FPGA is configurable, sum type on CPU is set as int64_t
  kmeans_t element_max = 99;  // std::numeric_limits<int64_t>::max() / num_rows;
  std::uniform_int_distribution<kmeans_t> int_dist(-element_max, element_max);

  std::vector<std::vector<kmeans_t>> dataset;

  for (int row_idx = 0; row_idx < num_rows; row_idx++) {
    std::vector<kmeans_t> row;
    for (int col_idx = 0; col_idx < num_columns; col_idx++) {
      // Append number to current list
      kmeans_t rnd_num = int_dist(rng);
      row.push_back(rnd_num);
    }
    dataset.push_back(std::move(row));
  }

  return dataset;
}


/**
 * Convert the dataset into Arrow format.
 */
std::shared_ptr<arrow::RecordBatch> create_recordbatch(const std::vector<std::vector<kmeans_t>> &dataset) {
  // Create arrow builder for appending numbers
  auto int_builder = std::make_shared<arrow::NumericBuilder<arrow_t>> ();

  // Make a list builder
  arrow::ListBuilder list_builder(
      arrow::default_memory_pool(),
      int_builder);

  for (auto const &row : dataset) {
    // Append single list
    list_builder.Append();
    for (kmeans_t const &dim : row) {
      int_builder->Append(dim);
    }
  }

  // Define the schema
  std::vector<std::shared_ptr<arrow::Field>> schema_fields = {
      arrow::field("ListOfNumber", arrow::list(
          std::make_shared<arrow::Field>("Numbers", std::make_shared<arrow_t>(), false)), false),
  };
  auto schema = std::make_shared<arrow::Schema>(schema_fields);

  // Create an array and finish the builder
  std::shared_ptr<arrow::Array> num_array;
  list_builder.Finish(&num_array);

  // Create and return the table
  return arrow::RecordBatch::Make(schema, dataset.size(), { num_array });
}


const kmeans_t * get_arrow_pointer(const std::shared_ptr<arrow::Array> &array) {
  // Probe into the Arrow data structures to extract a pointer to the raw data
  auto points_list = std::static_pointer_cast<arrow::ListArray>(array);
  auto points = std::static_pointer_cast<arrow::NumericArray<arrow_t>>(
      points_list->values());
  const kmeans_t * data = points->raw_values();
  return data;
}


/**
 * Run k-means on the CPU.
 */
std::vector<std::vector<kmeans_t>> kmeans_cpu(const std::shared_ptr<arrow::RecordBatch> &rb,
                                              std::vector<std::vector<kmeans_t>> centroids_position,
                                              int iteration_limit) {
  const kmeans_t * data = get_arrow_pointer(rb->column(0));
  size_t num_centroids = centroids_position.size();
  size_t dimensionality = centroids_position[0].size();
  int64_t num_rows = rb->num_rows();

  auto centroids_position_old = centroids_position;
  int iteration = 0;
  do {
    // Initialize accumulators
    std::vector<kmeans_t> centroid_accumulator(dimensionality, 0);
    std::vector<std::vector<kmeans_t>> accumulators(num_centroids, centroid_accumulator);
    std::vector<kmeans_t> counters(num_centroids, 0);

    // For each point
    for (int64_t n = 0; n < num_rows; n++) {
      // Determine closest centroid for point
      size_t closest = 0;
      kmeans_t min_distance = std::numeric_limits<kmeans_t>::max();
      for (size_t c = 0; c < num_centroids; c++) {
        // Get distance to current centroid
        kmeans_t distance = 0;
        for (size_t d = 0; d < dimensionality; d++) {
          kmeans_t dim_distance = data[n * dimensionality + d] - centroids_position[c][d];
          distance += dim_distance * dim_distance;
        }
        // Store minimum distance
        if (distance <= min_distance) {
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

  return centroids_position;
}


/**
 * Push as many FPGA register values as the argument is wide.
 */
template <typename T> void fpga_push_arg(std::vector<freg_t> *args, T arg) {
  T mask = 0;
  for (size_t byte = 0; byte < sizeof(freg_t); byte++) {
    mask = (mask << 8) | 0xff;
  }
  for (size_t arg_num = 0; arg_num < sizeof(T) / sizeof(freg_t); arg_num++) {
    // Mask out LSBs
    freg_t fletcher_arg = (freg_t) (arg & mask);
    args->push_back(fletcher_arg);
    // Shift argument
    arg >>= sizeof(freg_t) * 8;
  }
}


/**
 * Read an integer that may be wider that one FPGA register.
 */
template <typename T> void fpga_read_mmio(std::shared_ptr<fletcher::Platform> platform, int reg_idx, T *arg) {
  const int regs_num = sizeof(T) / sizeof(freg_t);
  for (size_t arg_idx = 0; arg_idx < regs_num; arg_idx++) {
    freg_t reg;
    platform->readMMIO(reg_idx + regs_num - 1 - arg_idx, &reg);
    *arg <<= sizeof(freg_t) * 8;
    *arg |= (T) reg;
  }
}


/**
 * Run k-means on an FPGA.
 */
std::vector<std::vector<kmeans_t>> kmeans_fpga(std::shared_ptr<arrow::RecordBatch> rb,
                                               std::vector<std::vector<kmeans_t>> centroids_position,
                                               int iteration_limit,
                                               int fpga_dim,
                                               int fpga_centroids) {
  std::shared_ptr<fletcher::Platform> platform;
  std::shared_ptr<fletcher::Context> context;
  std::shared_ptr<fletcher::UserCore> uc;

  // Create a platform
  fletcher::Platform::Make(&platform);
  // Create a context
  fletcher::Context::Make(&context, platform);
  // Create the UserCore
  uc = std::make_shared<fletcher::UserCore>(context);

  // Initialize the platform
  platform->init();

  // Reset the UserCore
  uc->reset();

  // Prepare the column buffers
  context->queueRecordBatch(rb).ewf("Error queuing RecordBatch");
  context->enable().ewf("Error preparing data");

  // Determine size of table
  freg_t last_index = rb->num_rows();
  uc->setRange(0, last_index).ewf("Error setting range");

  // Set UserCore arguments
  std::vector<freg_t> args;
  for (auto const & centroid : centroids_position) {
    for (kmeans_t const & dim : centroid) {
      fpga_push_arg(&args, dim);
    }
    for (int d = centroid.size(); d < fpga_dim; d++) {
      // Unused dimensions
      fpga_push_arg(&args, (kmeans_t) 0);
    }
  }
  // Unused centroids; set to magic number to disable on FPGA
  for (int c = centroids_position.size(); c < fpga_centroids; c++) {
    for (int d = 0; d < fpga_dim - 1; d++) {
      fpga_push_arg(&args, (kmeans_t) 0);
    }
    fpga_push_arg(&args, (kmeans_t) std::numeric_limits<kmeans_t>::min());
  }
  args.push_back(iteration_limit);

  uc->setArguments(args);

  // Start the FPGA user function
  uc->start();
  uc->waitForFinish(1000);  // Poll every 1 ms

  // Read result
  const int centroids = centroids_position.size();
  const int dimensionality = centroids_position[0].size();
  const int regs_per_dim = sizeof(kmeans_t) / sizeof(freg_t);
  const int regs_offset = 10;
  freg_t reg;
  for (int c = 0; c < centroids; c++) {
    for (int d = 0; d < dimensionality; d++) {
      kmeans_t dim_value;
      const int reg_num = (c * fpga_dim + d) * regs_per_dim + regs_offset;
      fpga_read_mmio(platform, reg_num, &dim_value);
      centroids_position[c][d] = dim_value;
    }
  }

  platform->readMMIO((fpga_dim * fpga_centroids) * regs_per_dim + regs_offset, &reg);
  std::cout << "Iterations: " << (iteration_limit - reg) << std::endl;

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
  int fpga_dim = 8;
  int fpga_centroids = 2;

  std::cout << "Usage: kmeans [num_rows [centroids [dimensionality [iteration_limit "
               "[fpga_dimensionality [fpga_centroids]]]]]]" << std::endl;

  if (argc >= 2) {
    sscanf(argv[1], "%i", &num_rows);
  }
  if (argc > 3) {
    sscanf(argv[2], "%i", &centroids);
  }
  if (argc >= 4) {
    sscanf(argv[3], "%i", &dimensionality);
  }
  if (argc >= 5) {
    sscanf(argv[4], "%i", &iteration_limit);
  }
  if (argc >= 6) {
    sscanf(argv[5], "%i", &fpga_dim);
  }
  if (argc >= 7) {
    sscanf(argv[6], "%i", &fpga_centroids);
  }

  // Create table of random numbers
  auto dataset = create_data(num_rows, dimensionality);
  auto rb = create_recordbatch(dataset);

  // Pick starting centroids
  std::vector<std::vector<kmeans_t>> centroids_position;
  const kmeans_t * points_ptr = get_arrow_pointer(rb->column(0));
  for (int n = 0; n < centroids; n++) {
    std::vector<kmeans_t> centroid_position;
    for (int col = 0; col < dimensionality; col++) {
      centroid_position.push_back(points_ptr[n * dimensionality + col]);
    }
    centroids_position.push_back(centroid_position);
  }

  // Run on CPU
  auto result_cpu = kmeans_cpu(
      rb, centroids_position, iteration_limit);

  // Run on FPGA
  auto result_fpga = kmeans_fpga(
      rb, centroids_position, iteration_limit, fpga_dim, fpga_centroids);

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
