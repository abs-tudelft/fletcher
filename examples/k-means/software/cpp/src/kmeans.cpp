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


#define PRINT_TIME(X, S) std::cout << std::setprecision(10) << (X) << " " << (S) << std::endl << std::flush
#define PRINT_INT(X, S) std::cout << std::dec << (X) << " " << (S) << std::endl << std::flush

using fletcher::Timer;

typedef int32_t kmeans_t;
typedef arrow::Int32Type arrow_t;


/**
 * Print the given centroid positions to stdout.
 */
void print_centroids(const std::vector<std::vector<kmeans_t>> &centroids_position) {
  for (auto const &centroid : centroids_position) {
    std::cerr << " (";
    for (kmeans_t const &dim : centroid) {
      std::cerr << dim << "; ";
    }
    std::cerr << ")" << std::endl;
  }
}


/**
 * Create an example dataset from a random number generator.
 */
std::vector<std::vector<kmeans_t>> create_data(int num_rows, int num_columns, std::mt19937 rng) {
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
 * Create an example dataset from a CSV stream.
 */
std::vector<std::vector<kmeans_t>> create_data(std::istream& input) {
  std::vector<std::vector<kmeans_t>> dataset;

  long line_num = 0;
  std::string line;
  while (std::getline(input, line)) {
    std::stringstream lines(line);
    std::vector<kmeans_t> row;
    std::string element;
    while (std::getline(lines, element, ',')) {
      kmeans_t num = std::stoll(element);
      row.push_back(num);
    }
    dataset.push_back(row);
    
    if (line_num % 1000000 == 0) {
      std::cerr << ".";
      line_num = 0;
    }
    line_num++;
  }
  std::cerr << std::endl;
  return dataset;
}


/**
 * Convert the dataset into Arrow format.
 * Uses a list to represent the different dimensions in the data.
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


/**
 * Returns a pointer to the start of the raw Arrow data in the givven array.
 */
const kmeans_t * get_arrow_pointer(const std::shared_ptr<arrow::Array> &array) {
  // Probe into the Arrow data structures to extract a pointer to the raw data
  auto points_list = std::static_pointer_cast<arrow::ListArray>(array);
  auto points = std::static_pointer_cast<arrow::NumericArray<arrow_t>>(
      points_list->values());
  const kmeans_t * data = points->raw_values();
  return data;
}


/**
 * Run k-means on the CPU. (Arrow version)
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
 * Run k-means on the CPU. (Arrow version, multithreaded)
 */
std::vector<std::vector<kmeans_t>> kmeans_cpu_omp(const std::shared_ptr<arrow::RecordBatch> &rb,
                                              std::vector<std::vector<kmeans_t>> centroids_position,
                                              int iteration_limit) {
  const kmeans_t * data = get_arrow_pointer(rb->column(0));
  size_t num_centroids = centroids_position.size();
  size_t dimensionality = centroids_position[0].size();
  int64_t num_rows = rb->num_rows();

  auto centroids_position_old = centroids_position;
  int iteration = 0;

  // Initialize accumulators
  std::vector<kmeans_t> centroid_accumulator(dimensionality, 0);
  std::vector<std::vector<kmeans_t>> accumulators(num_centroids, centroid_accumulator);
  std::vector<kmeans_t> counters(num_centroids, 0);

  #pragma omp parallel default(shared)
  {
    auto accumulators_l = accumulators;
    auto counters_l = counters;

    // Make sure accumulators is not changed before copying to local variable
    #pragma omp barrier

    do { // k-means iteration

      // For each point
      #pragma omp for nowait,schedule(static)
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
        counters_l[closest]++;
        for (size_t d = 0; d < dimensionality; d++) {
          accumulators_l[closest][d] += data[n * dimensionality + d];
        }
      }  // omp for

      // Update global counters
      for (size_t c = 0; c < num_centroids; c++) {
        #pragma omp atomic
        counters[c] += counters_l[c];
        counters_l[c] = 0;
        for (size_t d = 0; d < dimensionality; d++) {
          #pragma omp atomic
          accumulators[c][d] += accumulators_l[c][d];
          accumulators_l[c][d] = 0;
        }
      }

      // Calculate new centroid positions
      // Barrier, so that all threads are finished adding their counts
      #pragma omp barrier
      #pragma omp single
      {
        centroids_position_old = centroids_position;
        for (size_t c = 0; c < num_centroids; c++) {
          for (size_t d = 0; d < dimensionality; d++) {
            centroids_position[c][d] = accumulators[c][d] / counters[c];
            accumulators[c][d] = 0;
          }
          counters[c] = 0;
        }
        iteration++;
      } // omp single
      // implicit barrier

    } while (centroids_position != centroids_position_old && iteration < iteration_limit);

  }  // omp parallel

  return centroids_position;
}


/**
 * Run k-means on the CPU. (std::vector version)
 */
std::vector<std::vector<kmeans_t>> kmeans_cpu(const std::vector<std::vector<kmeans_t>> &dataset,
                                              std::vector<std::vector<kmeans_t>> centroids_position,
                                              int iteration_limit) {
  size_t num_centroids = centroids_position.size();
  size_t dimensionality = centroids_position[0].size();

  auto centroids_position_old = centroids_position;
  int iteration = 0;
  do {
    // Initialize accumulators
    std::vector<kmeans_t> centroid_accumulator(dimensionality, 0);
    std::vector<std::vector<kmeans_t>> accumulators(num_centroids, centroid_accumulator);
    std::vector<kmeans_t> counters(num_centroids, 0);

    // For each point
    for (auto row : dataset) {
      // Determine closest centroid for point
      size_t closest = 0;
      kmeans_t min_distance = std::numeric_limits<kmeans_t>::max();
      for (size_t c = 0; c < num_centroids; c++) {
        // Get distance to current centroid
        kmeans_t distance = 0;
        for (size_t d = 0; d < dimensionality; d++) {
          kmeans_t dim_distance = row[d] - centroids_position[c][d];
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
        accumulators[closest][d] += row[d];
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
 * Run k-means on the CPU. (std::vector version, multithreaded)
 */
std::vector<std::vector<kmeans_t>> kmeans_cpu_omp(const std::vector<std::vector<kmeans_t>> &dataset,
                                              std::vector<std::vector<kmeans_t>> centroids_position,
                                              int iteration_limit) {
  size_t num_centroids = centroids_position.size();
  size_t dimensionality = centroids_position[0].size();
  size_t num_rows = dataset.size();

  auto centroids_position_old = centroids_position;
  int iteration = 0;

  // Initialize accumulators
  std::vector<kmeans_t> centroid_accumulator(dimensionality, 0);
  std::vector<std::vector<kmeans_t>> accumulators(num_centroids, centroid_accumulator);
  std::vector<kmeans_t> counters(num_centroids, 0);

  #pragma omp parallel default(shared)
  {
    auto accumulators_l = accumulators;
    auto counters_l = counters;

    // Make sure accumulators is not changed before copying to local variable
    #pragma omp barrier

    do { // k-means iteration

      // For each point
      #pragma omp for nowait,schedule(static)
      for (size_t n = 0; n < num_rows; n++) {
        // Determine closest centroid for point
        size_t closest = 0;
        kmeans_t min_distance = std::numeric_limits<kmeans_t>::max();
        for (size_t c = 0; c < num_centroids; c++) {
          // Get distance to current centroid
          kmeans_t distance = 0;
          for (size_t d = 0; d < dimensionality; d++) {
            kmeans_t dim_distance = dataset[n][d] - centroids_position[c][d];
            distance += dim_distance * dim_distance;
          }
          // Store minimum distance
          if (distance <= min_distance) {
            closest = c;
            min_distance = distance;
          }
        }
        // Update counters of closest centroid
        counters_l[closest]++;
        for (size_t d = 0; d < dimensionality; d++) {
          accumulators_l[closest][d] += dataset[n][d];
        }
      } // omp for

      // Update global counters
      for (size_t c = 0; c < num_centroids; c++) {
        #pragma omp atomic
        counters[c] += counters_l[c];
        counters_l[c] = 0;
        for (size_t d = 0; d < dimensionality; d++) {
          #pragma omp atomic
          accumulators[c][d] += accumulators_l[c][d];
          accumulators_l[c][d] = 0;
        }
      }

      // Calculate new centroid positions
      // Barrier, so that all threads are finished adding their counts
      #pragma omp barrier
      #pragma omp single
      {
        centroids_position_old = centroids_position;
        for (size_t c = 0; c < num_centroids; c++) {
          for (size_t d = 0; d < dimensionality; d++) {
            centroids_position[c][d] = accumulators[c][d] / counters[c];
            accumulators[c][d] = 0;
          }
          counters[c] = 0;
        }
        iteration++;
      } // omp single
      // implicit barrier

    } while (centroids_position != centroids_position_old && iteration < iteration_limit);

  }  // omp parallel

  return centroids_position;
}


/**
 * Push as many FPGA register values as the argument is wide.
 * Use this function to set 64-bit arguments for the FPGA.
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
 * Use this to read 64-bit values from the FPGA.
 */
template <typename T> void fpga_read_mmio(std::shared_ptr<fletcher::Platform> platform, int reg_idx, T *arg) {
  *arg = 0;
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
                                               int fpga_centroids,
                                               double *copy_time,
                                               double *run_time,
                                               long *bytes_copied) {
  Timer t;

  std::shared_ptr<fletcher::Platform> platform;
  std::shared_ptr<fletcher::Context> context;
  std::shared_ptr<fletcher::UserCore> uc;

  fletcher::Platform::Make(&platform);
  fletcher::Context::Make(&context, platform);
  uc = std::make_shared<fletcher::UserCore>(context);

  // Initialize the platform
  platform->init();

  // Reset the UserCore
  uc->reset();

  // Prepare the column buffers
  t.start();
  context->queueRecordBatch(rb).ewf("Error queuing RecordBatch");
  *bytes_copied += context->getQueueSize();
  context->enable().ewf("Error preparing data");
  t.stop();
  *copy_time = t.seconds();

  // Determine size of table
  t.start();
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
  uc->waitForFinish(10);

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
  t.stop();
  *run_time = t.seconds();

  std::cout << "FPGA Iterations: " << (iteration_limit - reg) << std::endl;
  return centroids_position;
}


double calc_sum(const std::vector<double> &values) {
  return accumulate(values.begin(), values.end(), 0.0);
}

uint32_t calc_sum(const std::vector<uint32_t> &values) {
  return static_cast<uint32_t>(accumulate(values.begin(), values.end(), 0.0));
}


/**
 * Main function for the example.
 * Generates list of numbers, runs k-means on CPU and on FPGA.
 * Finally compares the results.
 */
int main(int argc, char ** argv) {
  int num_rows = 32;
  int centroids = 4;
  int dimensionality = 16;
  int iteration_limit = 1;
  int fpga_dim = 16;
  int fpga_centroids = 4;
  // Number of experiments
  int ne = 1;

  std::cerr << "Usage: kmeans [num_rows [centroids [dimensionality [iteration_limit "
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

  Timer t;

  long bytes_copied = 0;

  // Times
  std::vector<double> t_ser(ne, 0.0);
  std::vector<double> t_vcpu(ne, 0.0);
  std::vector<double> t_vomp(ne, 0.0);
  std::vector<double> t_acpu(ne, 0.0);
  std::vector<double> t_aomp(ne, 0.0);
  std::vector<double> t_copy(ne, 0.0);
  std::vector<double> t_fpga(ne, 0.0);

  // Set up random number generator
  std::mt19937 rng;
  rng.seed(31415926535);

  // Create table of random numbers
  t.start();
  std::vector<std::vector<kmeans_t>> dataset;
  if (num_rows > 0) {
    std::cerr << "Generating dataset" << std::endl;
    dataset = create_data(num_rows, dimensionality, rng);
  } else {
    std::cerr << "Reading dataset from stdin" << std::endl;
    dataset = create_data(std::cin);
    num_rows = dataset.size();
    dimensionality = dataset.at(0).size();
  }
  t.stop();
  PRINT_TIME(t.seconds(), "create");

  // Pick starting centroids
  std::vector<std::vector<kmeans_t>> centroids_position;
  for (int n = 0; n < centroids; n++) {
    std::vector<kmeans_t> centroid_position;
    for (int col = 0; col < dimensionality; col++) {
      centroid_position.push_back(dataset[n][col]);
    }
    centroids_position.push_back(centroid_position);
  }

  // Run the mesurements
  int status = EXIT_SUCCESS;
  for (int e = 0; e < ne; e++) {
    std::cerr << "Running iteration " << (e+1) << " of " << ne << std::endl;

    // Serialize to RecordBatch
    t.start();
    auto rb = create_recordbatch(dataset);
    t.stop();
    t_ser[e] = t.seconds();

    // Run on CPU (vector)
    t.start();
    auto result_vcpu = kmeans_cpu(
        dataset, centroids_position, iteration_limit);
    t.stop();
    t_vcpu[e] = t.seconds();

    // Print the clusters
    if (e == 0) {
      std::cerr << "vCPU clusters: " << std::endl;
      print_centroids(result_vcpu);
    }

    // Run on CPU (Arrow)
    t.start();
    auto result_acpu = kmeans_cpu(
        rb, centroids_position, iteration_limit);
    t.stop();
    t_acpu[e] = t.seconds();

    // Run on CPU (vector, OpenMP)
    t.start();
    auto result_vomp = kmeans_cpu_omp(
        dataset, centroids_position, iteration_limit);
    t.stop();
    t_vomp[e] = t.seconds();

    // Run on CPU (Arrow, OpenMP)
    t.start();
    auto result_aomp = kmeans_cpu_omp(
        rb, centroids_position, iteration_limit);
    t.stop();
    t_aomp[e] = t.seconds();
    
    // Run on FPGA
    std::cerr << "Starting FPGA" << std::endl;
    auto result_fpga = kmeans_fpga(
        rb, centroids_position, iteration_limit, fpga_dim, fpga_centroids,
        &t_copy[e], &t_fpga[e], &bytes_copied);


    // Check whether results are the same
    if (result_vcpu != result_acpu) {
      std::cerr << "aCPU clusters: " << std::endl;
      print_centroids(result_acpu);
      std::cout << "ERROR Arrow single" << std::endl;
      status = EXIT_FAILURE;
    }
    if (result_vcpu != result_vomp) {
      std::cerr << "vOMP clusters: " << std::endl;
      print_centroids(result_vomp);
      std::cout << "ERROR vector OpenMP" << std::endl;
      status = EXIT_FAILURE;
    }
    if (result_vcpu != result_aomp) {
      std::cerr << "aOMP clusters: " << std::endl;
      print_centroids(result_aomp);
      std::cout << "ERROR Arrow OpenMP" << std::endl;
      status = EXIT_FAILURE;
    }

    if (result_vcpu != result_fpga) {
      std::cerr << "FPGA clusters: " << std::endl;
      print_centroids(result_fpga);
      std::cout << "ERROR FPGA" << std::endl;
      status = EXIT_FAILURE;
    }
  }

  // Report the run times:
  PRINT_TIME(calc_sum(t_ser), "serialization");
  PRINT_TIME(calc_sum(t_vcpu), "vCPU");
  PRINT_TIME(calc_sum(t_vomp), "vOMP");
  PRINT_TIME(calc_sum(t_acpu), "aCPU");
  PRINT_TIME(calc_sum(t_aomp), "aOMP");
  PRINT_TIME(calc_sum(t_copy), "copy");
  PRINT_TIME(calc_sum(t_fpga), "FPGA");
  PRINT_INT(bytes_copied, "bytes copied");

  if (status == EXIT_SUCCESS) {
    std::cout << "PASS" << std::endl;
  } else {
    std::cout << "ERROR" << std::endl;
  }
  return status;
}

