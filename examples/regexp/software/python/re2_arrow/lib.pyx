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
from libc.stdint cimport *
from libcpp.string cimport string as cpp_string
from libcpp.vector cimport vector
from libcpp cimport bool as cpp_bool

from pyarrow.lib cimport *

cdef extern from "re2/re2.h" namespace "re2" nogil:
    cdef cppclass StringPiece:
        StringPiece(const cpp_string& str)

    cdef cppclass RE2:
        RE2(const cpp_string pattern)
        cpp_bool FullMatch(const StringPiece& text, const RE2& re)


cdef _add_matches_cython_arrow(shared_ptr[CArray] array, list regexes, int num_regexes):
    cdef vector[RE2*] programs
    cdef int i
    cdef int num_strings = array.get().length()

    for i in range(num_regexes):
        programs.push_back(new RE2(regexes[i]))


def add_matches_cython_arrow(array, regexes):
    return _add_matches_cython_arrow(pyarrow_unwrap_array(array), regexes, len(regexes))