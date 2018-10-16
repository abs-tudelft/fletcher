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

# distutils: language = c++

cimport cython

from libcpp.memory cimport shared_ptr
from libc.stdint cimport *
from libcpp.string cimport string as cpp_string
from libcpp.vector cimport vector
from libcpp cimport bool as cpp_bool

from pyarrow.lib cimport *

#Todo: Remove temporary relative imports
cdef extern from "fletcher.h" nogil:
    ctypedef unsigned long long fstatus_t
    ctypedef unsigned long long da_t

cdef extern from "../../../cpp/src/status.h" nogil:
    cdef struct CStatus"Status":
        fstatus_t val
        CStatus() except +
        CStatus(fstatus_t val) except +
        cpp_bool ok()
        void ewf()
        CStatus OK()
        CStatus ERROR()

cdef extern from "../../../cpp/src/platform.h" namespace "fletcher" nogil:
    cdef cppclass CPlatform" fletcher::Platform":
        pass