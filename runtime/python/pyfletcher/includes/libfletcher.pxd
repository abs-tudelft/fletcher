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

cdef extern from "fletcher.h" nogil:
    ctypedef unsigned long long fstatus_t
    ctypedef unsigned long long da_t

cdef extern from "fletcher/status.h" namespace "fletcher" nogil:
    cdef cppclass Status:
        fstatus_t val
        Status() except +
        Status(fstatus_t val) except +
        cpp_bool ok()
        void ewf()
        Status OK()
        Status ERROR()

cdef extern from "fletcher/platform.h" namespace "fletcher" nogil:
    cdef cppclass CPlatform" fletcher::Platform":
        Status create(const cpp_string &name, shared_ptr[CPlatform] *platform, cpp_bool quiet)
        Status create(shared_ptr[CPlatform] *platform)
        cpp_string getName()
        Status init()
        Status writeMMIO(uint64_t offset, uint32_t value)
        Status readMMIO(uint64_t offset, uint32_t *value)
        Status deviceMalloc(da_t *device_address, size_t size)
        Status deviceFree(da_t device_address)
        Status copyHostToDevice(uint8_t *host_source, da_t device_destination, uint64_t size)
        Status copyDeviceToHost(da_t device_source, uint8_t *host_destination, uint64_t size)
        Status prepareHostBuffer(const uint8_t *host_source, da_t *device_destination, int64_t size, cpp_bool *alloced)
        Status cacheHostBuffer(const uint8_t *host_source, da_t *device_destination, int64_t size)
        Status terminate()

cdef extern from "fletcher/context.h" namespace "fletcher" nogil:
    cdef cppclass CContext" fletcher::Context":
        CContext(shared_ptr[CPlatform] platform)
        Status Make(shared_ptr[CContext] *context, shared_ptr[CPlatform] platform)
        Status queueArray(const shared_ptr[CArray] &array, cpp_bool cache)

cdef extern from "fletcher/usercore.h" namespace "fletcher" nogil:
    cdef cppclass CUserCore" fletcher::UserCore":
        pass