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

#include <memory>
#include <vector>
#include <cstdint>

// Apache Arrow
#include <arrow/api.h>

int64_t* arrow_kmeans_cpu(std::shared_ptr<arrow::RecordBatch> batch,
                                                   int64_t* centroids_position,
                                                   int iteration_limit,
                                                   size_t num_centroids,
                                                   size_t dimensionality,
                                                   int64_t num_rows);

int64_t* numpy_kmeans_cpu(int64_t* data, int64_t* centroids_position, int iteration_limit, size_t num_centroids, size_t dimensionality, int64_t num_rows);

int64_t* arrow_kmeans_cpu_omp(std::shared_ptr<arrow::RecordBatch> batch,
                                                   int64_t* centroids_position,
                                                   int iteration_limit,
                                                   size_t num_centroids,
                                                   size_t dimensionality,
                                                   int64_t num_rows);

int64_t* numpy_kmeans_cpu_omp(int64_t* data, int64_t* centroids_position, int iteration_limit, size_t num_centroids, size_t dimensionality, int64_t num_rows);