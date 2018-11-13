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
from pyarrow.lib cimport *


cdef extern from "cpp/kmeans.h" nogil:
    vector[vector[int64_t]] arrow_kmeans_cpu(shared_ptr[CRecordBatch] batch,
                                             vector[vector[int64_t]] centroids_position,
                                             int iteration_limit)


cpdef arrow_kmeans_cpp(batch, centroids_position, iteration_limit):
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
    cpp_result = arrow_kmeans_cpu(cpp_batch, cpp_centroids_position, iteration_limit)

    # Convert C++ result vector into Python list
    cdef list result = []
    for i in range(centroid_count):
        result.append([])

        for j in range(dimensionality):
            result[i].append(cpp_result[i][j])

    return result