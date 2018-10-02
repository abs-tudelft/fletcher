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
from libcpp cimport bool as cpp_bool

from pyarrow.lib cimport *


cdef extern from "fletcher/fletcher.h" namespace "fletcher" nogil:
    ctypedef unsigned long long fa_t
    ctypedef unsigned int fr_t

    cdef cppclass CFPGAPlatform" fletcher::FPGAPlatform":
        uint64_t prepare_column_chunks(const shared_ptr[CColumn]& column)
        uint64_t argument_offset()
        cpp_string name()

    cdef cppclass CEchoPlatform" fletcher::EchoPlatform"(CFPGAPlatform):
        CEchoPlatform()
        int write_mmio(uint64_t offset, fr_t value)
        int read_mmio(uint64_t offset, fr_t *dest)
        cpp_bool good()

    cdef cppclass CUserCore" fletcher::UserCore":
        pass