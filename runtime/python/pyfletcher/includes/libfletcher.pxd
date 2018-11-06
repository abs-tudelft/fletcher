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

cdef extern from "fletcher/fletcher.h" nogil:
    ctypedef unsigned long long fstatus_t
    ctypedef unsigned long long da_t
    ctypedef unsigned int freg_t

cdef extern from "fletcher/common/arrow-utils.h" namespace "fletcher" nogil:
    ctypedef enum Mode:
        READ "fletcher::Mode::READ",
        WRITE "fletcher::Mode::WRITE"

cdef extern from "fletcher/api.h" namespace "fletcher" nogil:
    cdef cppclass Status:
        fstatus_t val
        Status() except +
        Status(fstatus_t val) except +
        cpp_bool ok()
        void ewf()
        Status OK()
        Status ERROR()

    cdef cppclass CPlatform" fletcher::Platform":
        #Renamed create function because overloading of static functions causes errors
        @staticmethod
        Status createNamed"Make"(const cpp_string &name, shared_ptr[CPlatform] *platform, cpp_bool quiet)
        @staticmethod
        Status createUnnamed"Make"(shared_ptr[CPlatform] *platform)

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

    cdef cppclass CContext" fletcher::Context":
        @staticmethod
        Status Make(shared_ptr[CContext] *context, const shared_ptr[CPlatform] &platform)
        Status queueArray(const shared_ptr[CArray] &array, Mode access_mode, cpp_bool cache)
        Status queueArray(const shared_ptr[CArray] &array, const shared_ptr[CField] field, Mode access_mode, cpp_bool cache)
        Status queueRecordBatch(const shared_ptr[CRecordBatch] &record_batch, cpp_bool cache)
        size_t getQueueSize()
        uint64_t num_buffers()
        Status enable()

    cdef cppclass CUserCore" fletcher::UserCore":
        # Control and status values
        uint32_t ctrl_start
        uint32_t ctrl_reset
        uint32_t done_status
        uint32_t done_status_mask

        CUserCore(shared_ptr[CContext] context)
        cpp_bool implementsSchema(const shared_ptr[CSchema] &schema)
        Status reset()
        Status setRange(int32_t first, int32_t last)
        Status setArguments(vector[uint32_t] arguments)
        Status start()
        Status getStatus(uint32_t *status)
        Status getReturn(uint32_t *ret0, uint32_t *ret1)
        Status waitForFinish(unsigned int poll_interval_usec)
        shared_ptr[CPlatform] platform()
        shared_ptr[CContext] context()
