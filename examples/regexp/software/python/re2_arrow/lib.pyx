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

from libcpp.memory cimport shared_ptr
from libc.stdlib cimport malloc, free
from libc.stdint cimport *
from libcpp.string cimport string as cpp_string
from libcpp.vector cimport vector
from libcpp cimport bool as cpp_bool

import numpy as np
cimport numpy as np
from pyarrow.lib cimport *

cdef extern from "cpp/re2_arrow.h" nogil:
    void add_matches_arrow(const shared_ptr[CArray] &array, const vector[cpp_string] &regexes, uint32_t* matches)

    void add_matches_arrow_omp(const shared_ptr[CArray] &array,
                               const vector[cpp_string] &regexes,
                               uint32_t* matches)

# Single core efficient regex matching for Arrow
cpdef add_matches_cpp_arrow(strings, list regexes):
    cdef int i
    cdef int num_regexes = len(regexes)
    cdef vector[cpp_string] cpp_regexes

    for i in range(num_regexes):
        cpp_regexes.push_back(regexes[i].encode('utf-8'))

    # Use numpy array as container for match results
    npmatches = np.zeros(num_regexes, dtype=np.dtype('u4'))
    cdef uint32_t[:] matches_view = npmatches
    cdef uint32_t* matches_pointer = &matches_view[0]

    add_matches_arrow(pyarrow_unwrap_array(strings), cpp_regexes, matches_pointer)

    return npmatches.tolist()


# Multi core efficient regex matching for Arrow
cpdef add_matches_cpp_arrow_omp(strings, list regexes):
    cdef int i
    cdef int num_regexes = len(regexes)
    cdef vector[cpp_string] cpp_regexes

    for i in range(num_regexes):
        cpp_regexes.push_back(regexes[i].encode('utf-8'))

    # Use numpy array as container for match results
    npmatches = np.zeros(num_regexes, dtype=np.dtype('u4'))
    cdef uint32_t[:] matches_view = npmatches
    cdef uint32_t* matches_pointer = &matches_view[0]

    add_matches_arrow_omp(pyarrow_unwrap_array(strings), cpp_regexes, matches_pointer)

    return npmatches.tolist()
