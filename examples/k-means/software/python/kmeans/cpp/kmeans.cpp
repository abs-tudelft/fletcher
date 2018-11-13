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
#include <cstdint>
#include <memory>
#include <vector>
#include <utility>
#include <numeric>

// Apache Arrow
#include <arrow/api.h>

/**
 * Run k-means on the CPU.
 */
std::vector<std::vector<int64_t>> arrow_kmeans_cpu(std::shared_ptr<arrow::RecordBatch> batch,
                             std::vector<std::vector<int64_t>> centroids_position,
                             int iteration_limit) {

  // Probe into the Arrow data structures to extract a pointer to the raw data
  auto points_list = std::static_pointer_cast<arrow::ListArray>(
      batch->column(0));
  auto points = std::static_pointer_cast<arrow::Int64Array>(
      points_list->values());
  const int64_t * data = points->raw_values();

  const size_t num_centroids = centroids_position.size();
  const size_t dimensionality = centroids_position[0].size();
  const int64_t num_rows = batch->num_rows();

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
        // Get distance to current centroidcent
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

  return centroids_position;
}

