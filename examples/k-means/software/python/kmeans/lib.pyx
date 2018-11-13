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

    int64_t* numpy_kmeans_cpu(int64_t* data,
                              int64_t* centroids_position,
                              int iteration_limit,
                              size_t num_centroids,
                              size_t dimensionality,
                              int64_t num_rows)


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


def np_kmeans_cython(points, centroids, iteration_limit):
    shape = centroids.shape
    return _np_kmeans_cython(points.ravel(), centroids.ravel(), iteration_limit,
                             shape[0], shape[1], points.shape[0]).reshape(shape)


cdef _arrow_kmeans_cpp(batch, centroids_position, iteration_limit):
    shape = centroids_position.shape
    cdef int64_t[:] centroids_view = centroids_position.ravel()
    cdef int64_t *centroids = &centroids_view[0]

    # Call C++ k-means algorithm
    arrow_kmeans_cpu(pyarrow_unwrap_batch(batch), centroids, iteration_limit, shape[0], shape[1], batch.num_rows)


def arrow_kmeans_cpp(batch, centroids_position, iteration_limit):
    return _arrow_kmeans_cpp(batch, centroids_position, iteration_limit)


cdef _numpy_kmeans_cpp(nparray, centroids_position, iteration_limit):
    shape = centroids_position.shape
    cdef int64_t[:] centroids_view = centroids_position.ravel()
    cdef int64_t *centroids = &centroids_view[0]

    cdef int64_t[:] array_view = nparray.ravel()
    cdef int64_t *array_pointer = &array_view[0]

    # Call C++ k-means algorithm
    numpy_kmeans_cpu(array_pointer, centroids, iteration_limit, shape[0], shape[1], nparray.shape[0])


def numpy_kmeans_cpp(nparray, centroids_position, iteration_limit):
    return _numpy_kmeans_cpp(nparray, centroids_position, iteration_limit)