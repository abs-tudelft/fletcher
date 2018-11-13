# Copyright 2018 Delft University of Technology
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import cython
from libcpp.memory cimport shared_ptr
from libc.stdint cimport *
from libcpp.vector cimport vector
from libcpp.limits cimport numeric_limits
import numpy as np
cimport numpy as np
from pyarrow.lib cimport *


cdef extern from "cpp/kmeans.h" nogil:
    int64_t* arrow_kmeans_cpu(shared_ptr[CRecordBatch] batch,
                              int64_t* centroids_position,
                              int iteration_limit,
                              size_t num_centroids,
                              size_t dimensionality,
                              int64_t num_rows)

    vector[vector[int64_t]] arrow_kmeans_cpu_old(shared_ptr[CRecordBatch] batch,
                                                 vector[vector[int64_t]] centroids_position,
                                                 int iteration_limit)

@cython.cdivision(True)
@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
cdef _list_kmeans_cython(list points, list centroids, int iteration_limit):
    cdef int num_centroids = len(centroids)
    cdef int dimensionality = len(centroids[0])
    cdef int num_rows = len(points)

    cdef list centroids_old = []
    cdef int iteration = 0

    cdef int i, j, n, c ,d

    cdef list accumulators, counters

    cdef int closest, min_distance, distance, dim_distance

    while centroids_old != centroids and iteration < iteration_limit:
        accumulators = [[0 for i in range(dimensionality)] for j in range(num_centroids)]
        counters = [0] * num_centroids

        for n in range(num_rows):
            # Determine closest centroid for point
            closest = 0
            min_distance = numeric_limits[int].max()
            for c in range(num_centroids):
                # Get distance to current centroid
                distance = 0
                for d in range(dimensionality):
                    dim_distance = points[n][d] - centroids[c][d]
                    distance += dim_distance * dim_distance

                if distance < min_distance:
                    closest = c
                    min_distance = distance

            # Update counters of closest centroid
            counters[closest] += 1
            for d in range(dimensionality):
                accumulators[closest][d] += points[n][d]

        centroids_old = [[centroids[i][j] for j in range(dimensionality)] for i in range(num_centroids)]
        # Calculate new centroids
        for c in range(num_centroids):
            for d in range(dimensionality):
                centroids[c][d] = accumulators[c][d] / counters[c]

        iteration += 1

    return centroids

@cython.cdivision(True)
@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
cdef _np_kmeans_cython(np.ndarray[np.int64_t, ndim=1] points, np.ndarray[np.int64_t, ndim=1] centroids,
                       int iteration_limit, int num_centroids, int dimensionality, int num_rows):
    cdef np.ndarray[np.int64_t, ndim=1] centroids_old = np.zeros(num_centroids * dimensionality, dtype=np.int64)
    cdef int iteration = 0

    cdef int i, j, n, c ,d

    cdef np.ndarray[np.int64_t, ndim=1] accumulators, counters

    cdef int closest, min_distance, distance, dim_distance

    while not np.array_equal(centroids_old, centroids) and iteration < iteration_limit:
        accumulators = np.zeros(num_centroids * dimensionality, dtype=np.int64)
        counters = np.zeros(num_centroids, dtype=np.int64)

        for n in range(num_rows):
            # Determine closest centroid for point
            closest = 0
            min_distance = numeric_limits[int].max()
            for c in range(num_centroids):
                # Get distance to current centroid
                distance = 0
                for d in range(dimensionality):
                    dim_distance = points[n*dimensionality + d] - centroids[c*dimensionality + d]
                    distance += dim_distance * dim_distance

                if distance < min_distance:
                    closest = c
                    min_distance = distance

            # Update counters of closest centroid
            counters[closest] += 1
            for d in range(dimensionality):
                accumulators[closest*dimensionality + d] += points[n*dimensionality + d]

        centroids_old = np.copy(centroids)
        # Calculate new centroids
        for c in range(num_centroids):
            for d in range(dimensionality):
                centroids[c*dimensionality + d] = accumulators[c*dimensionality + d] / counters[c]

        iteration += 1

    return centroids

def list_kmeans_cython(points, centroids, iteration_limit):
    return _list_kmeans_cython(points, centroids, iteration_limit)

def np_kmeans_cython(points, centroids, iteration_limit):
    shape = centroids.shape
    return _np_kmeans_cython(points.ravel(), centroids.ravel(), iteration_limit,
                             shape[0], shape[1], points.shape[0]).reshape(shape)


cpdef arrow_kmeans_cpp_old(batch, centroids_position, iteration_limit):
    cdef shared_ptr[CRecordBatch] cpp_batch = pyarrow_unwrap_batch(batch)
    cdef vector[vector[int64_t]] cpp_centroids_position

    cdef int dimensionality = len(centroids_position[0])
    cdef int centroid_count = len(centroids_position)

    cdef int i
    cdef int j

    # Convert Python list into C++ vector
    cdef vector[int64_t] centroid
    for i in range(centroid_count):

        for j in range(dimensionality):
            centroid.push_back(centroids_position[i][j])

        cpp_centroids_position.push_back(centroid)
        centroid.clear()

    # Call C++ k-means algorithm
    cpp_result = arrow_kmeans_cpu_old(cpp_batch, cpp_centroids_position, iteration_limit)

    # Convert C++ result vector into Python list
    cdef list result = []
    for i in range(centroid_count):
        result.append([])

        for j in range(dimensionality):
            result[i].append(cpp_result[i][j])

    return result


cdef _arrow_kmeans_cpp(batch, centroids_position, iteration_limit):
    shape = centroids_position.shape
    cdef int64_t[:] centroids_view = centroids_position.ravel()
    cdef int64_t *centroids = &centroids_view[0]

    # Call C++ k-means algorithm
    arrow_kmeans_cpu(pyarrow_unwrap_batch(batch), centroids, iteration_limit, shape[0], shape[1], batch.num_rows)

def arrow_kmeans_cpp(batch, centroids_position, iteration_limit):
    return _arrow_kmeans_cpp(batch, centroids_position, iteration_limit)
