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
#include <iostream>
#include <stdint.h>
#include <cstring>
#include <limits>
#include <cstdint>
#include <memory>
#include <vector>
#include <utility>
#include <numeric>
#include <omp.h>

// Apache Arrow
#include <arrow/api.h>

int64_t* numpy_kmeans_cpu_omp(int64_t* data, 
                                int64_t* centroids_position, 
                                int iteration_limit, 
                                size_t num_centroids, 
                                size_t dimensionality, 
                                int64_t num_rows) {
  size_t centroids_num_bytes = sizeof(int64_t) * dimensionality * num_centroids;

  int64_t *centroids_position_old = (int64_t*) std::malloc(centroids_num_bytes);
  int iteration = 0;

  // Initialize accumulators
  std::vector<int64_t> centroid_accumulator(dimensionality, 0);
  std::vector<std::vector<int64_t>> accumulators(num_centroids, centroid_accumulator);
  std::vector<int64_t> counters(num_centroids, 0);

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
        int64_t min_distance = std::numeric_limits<int64_t>::max();
        for (size_t c = 0; c < num_centroids; c++) {
          // Get distance to current centroid
          int64_t distance = 0;
          for (size_t d = 0; d < dimensionality; d++) {
            int64_t dim_distance = data[n * dimensionality + d] - centroids_position[c * dimensionality + d];
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
        std::memcpy((void*) centroids_position_old, (void*) centroids_position, centroids_num_bytes);
        for (size_t c = 0; c < num_centroids; c++) {
          for (size_t d = 0; d < dimensionality; d++) {
            centroids_position[c * dimensionality + d] = accumulators[c][d] / counters[c];
            accumulators[c][d] = 0;
          }
          counters[c] = 0;
        }
        iteration++;
      } // omp single
      // implicit barrier

    } while (std::memcmp((void*) centroids_position, (void*) centroids_position_old, centroids_num_bytes) != 0 && iteration < iteration_limit);

  }  // omp parallel

  return centroids_position;
}


int64_t* arrow_kmeans_cpu_omp(std::shared_ptr<arrow::RecordBatch> rb,
                                              int64_t* centroids_position,
                                              int iteration_limit,
                                              size_t num_centroids,
                                              size_t dimensionality,
                                              int64_t num_rows) {
    // Probe into the Arrow data structures to extract a pointer to the raw data
  auto points_list = std::static_pointer_cast<arrow::ListArray>(
      rb->column(0));
  auto points = std::static_pointer_cast<arrow::Int64Array>(
      points_list->values());
  const int64_t * data = points->raw_values();

  size_t centroids_num_bytes = sizeof(int64_t) * dimensionality * num_centroids;

  int64_t *centroids_position_old = (int64_t*) std::malloc(centroids_num_bytes);
  int iteration = 0;

  // Initialize accumulators
  std::vector<int64_t> centroid_accumulator(dimensionality, 0);
  std::vector<std::vector<int64_t>> accumulators(num_centroids, centroid_accumulator);
  std::vector<int64_t> counters(num_centroids, 0);

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
        int64_t min_distance = std::numeric_limits<int64_t>::max();
        for (size_t c = 0; c < num_centroids; c++) {
          // Get distance to current centroid
          int64_t distance = 0;
          for (size_t d = 0; d < dimensionality; d++) {
            int64_t dim_distance = data[n * dimensionality + d] - centroids_position[c * dimensionality + d];
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
        std::memcpy((void*) centroids_position_old, (void*) centroids_position, centroids_num_bytes);
        for (size_t c = 0; c < num_centroids; c++) {
          for (size_t d = 0; d < dimensionality; d++) {
            centroids_position[c * dimensionality + d] = accumulators[c][d] / counters[c];
            accumulators[c][d] = 0;
          }
          counters[c] = 0;
        }
        iteration++;
      } // omp single
      // implicit barrier

    } while (std::memcmp((void*) centroids_position, (void*) centroids_position_old, centroids_num_bytes) != 0 && iteration < iteration_limit);

  }  // omp parallel

  return centroids_position;
}

int64_t* arrow_kmeans_cpu(std::shared_ptr<arrow::RecordBatch> batch,
                             int64_t* centroids_position,
                             int iteration_limit, size_t num_centroids, size_t dimensionality, int64_t num_rows) {

  // Probe into the Arrow data structures to extract a pointer to the raw data
  auto points_list = std::static_pointer_cast<arrow::ListArray>(
      batch->column(0));
  auto points = std::static_pointer_cast<arrow::Int64Array>(
      points_list->values());
  const int64_t * data = points->raw_values();

  size_t centroids_num_bytes = sizeof(int64_t) * dimensionality * num_centroids;

  int64_t *centroids_position_old = (int64_t*) std::malloc(centroids_num_bytes);
  int64_t *accumulators = (int64_t*) std::malloc(centroids_num_bytes);
  int64_t *counters = (int64_t*) std::malloc(sizeof(int64_t) * num_centroids);

  std::memset((void*) centroids_position_old, 0, centroids_num_bytes);
  int iteration = 0;
  do {
    // Initialize accumulators
    std::memset((void*) accumulators, 0, centroids_num_bytes);
    std::memset((void*) counters, 0, sizeof(int64_t) * num_centroids);

    // For each point
    for (int64_t n = 0; n < num_rows; n++) {
      // Determine closest centroid for point
      size_t closest = 0;
      int64_t min_distance = std::numeric_limits<int64_t>::max();
      for (size_t c = 0; c < num_centroids; c++) {
        // Get distance to current centroidcent
        int64_t distance = 0;
        for (size_t d = 0; d < dimensionality; d++) {
          int64_t dim_distance = data[n * dimensionality + d] - centroids_position[c * dimensionality + d];
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
        accumulators[closest * dimensionality + d] += data[n * dimensionality + d];
      }
    }

    std::memcpy((void*) centroids_position_old, (void*) centroids_position, centroids_num_bytes);
    // Calculate new centroid positions
    for (size_t c = 0; c < num_centroids; c++) {
      for (size_t d = 0; d < dimensionality; d++) {
        centroids_position[c * dimensionality + d] = accumulators[c * dimensionality + d] / counters[c];
      }
    }

    iteration++;
  } while (std::memcmp((void*) centroids_position, (void*) centroids_position_old, centroids_num_bytes) != 0 && iteration < iteration_limit);

  free(centroids_position_old);
  free(accumulators);
  free(counters);
  return centroids_position;
}

int64_t* numpy_kmeans_cpu(int64_t* data,
                             int64_t* centroids_position,
                             int iteration_limit, size_t num_centroids, size_t dimensionality, int64_t num_rows) {

  size_t centroids_num_bytes = sizeof(int64_t) * dimensionality * num_centroids;
  int64_t *centroids_position_old = (int64_t*) std::malloc(centroids_num_bytes);
  int64_t *accumulators = (int64_t*) std::malloc(centroids_num_bytes);
  int64_t *counters = (int64_t*) std::malloc(sizeof(int64_t) * num_centroids);

  std::memset((void*) centroids_position_old, 0, centroids_num_bytes);
  int iteration = 0;
  do {
    // Initialize accumulators
    std::memset((void*) accumulators, 0, centroids_num_bytes);
    std::memset((void*) counters, 0, sizeof(int64_t) * num_centroids);

    // For each point
    for (int64_t n = 0; n < num_rows; n++) {
      // Determine closest centroid for point
      size_t closest = 0;
      int64_t min_distance = std::numeric_limits<int64_t>::max();
      for (size_t c = 0; c < num_centroids; c++) {
        // Get distance to current centroidcent
        int64_t distance = 0;
        for (size_t d = 0; d < dimensionality; d++) {
          int64_t dim_distance = data[n * dimensionality + d] - centroids_position[c * dimensionality + d];
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
        accumulators[closest * dimensionality + d] += data[n * dimensionality + d];
      }
    }

    std::memcpy((void*) centroids_position_old, (void*) centroids_position, centroids_num_bytes);
    // Calculate new centroid positions
    for (size_t c = 0; c < num_centroids; c++) {
      for (size_t d = 0; d < dimensionality; d++) {
        centroids_position[c * dimensionality + d] = accumulators[c * dimensionality + d] / counters[c];
      }
    }

    iteration++;
  } while (std::memcmp((void*) centroids_position, (void*) centroids_position_old, centroids_num_bytes) != 0 && iteration < iteration_limit);

  free(centroids_position_old);
  free(accumulators);
  free(counters);
  return centroids_position;
}