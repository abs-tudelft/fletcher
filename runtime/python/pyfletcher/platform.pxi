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

import numpy as np

cdef class Platform:
    cdef:
        shared_ptr[CPlatform] platform

    def __init__(self, str name = "", quiet = True):
        self._create(name, quiet)

    cdef from_pointer(self, const shared_ptr[CPlatform]& platform):
        self.platform = platform

    cdef _create(self, str name = "", quiet = True):
        if not name:
            check_fletcher_status(CPlatform.createUnnamed(&self.platform))
        else:
            check_fletcher_status(CPlatform.createNamed(name.encode("utf-8"), &self.platform, quiet))

    def get_name(self):
        return self.platform.get().getName().decode("utf-8")

    def init(self):
        check_fletcher_status(self.platform.get().init())

    def write_mmio(self, uint64_t offset, uint32_t value):
        check_fletcher_status(self.platform.get().writeMMIO(offset, value))

    def read_mmio(self, uint64_t offset):
        cdef uint32_t value
        check_fletcher_status(self.platform.get().readMMIO(offset, &value))

        return value

    def device_malloc(self, size_t size):
        cdef da_t device_address
        check_fletcher_status(self.platform.get().deviceMalloc(&device_address, size))

        return device_address

    def device_free(self, da_t device_address):
        check_fletcher_status(self.platform.get().deviceFree(device_address))

    def copy_host_to_device(self, host_bytes, da_t device_destination, uint64_t size):
        #Accepts bytes-like objects for host_bytes
        cdef const uint8_t[:] host_source_view = host_bytes
        cdef const uint8_t *host_source = &host_source_view[0]

        check_fletcher_status(self.platform.get().copyHostToDevice(<uint8_t*>host_source, device_destination, size))

    # Todo: Discuss if numpy array is the best return type
    def copy_device_to_host(self, da_t device_source, uint64_t size):
        buffer = np.zeros((size,), dtype=np.uint8)
        cdef const uint8_t[:] buffer_view = buffer
        cdef const uint8_t *host_destination = &buffer_view[0]

        check_fletcher_status(self.platform.get().copyDeviceToHost(device_source, <uint8_t*>host_destination, size))

        return buffer

    def prepare_host_buffer(self, host_bytes, int64_t size):
        #Accepts bytes-like objects for host_bytes
        cdef const uint8_t[:] host_source_view = host_bytes
        cdef const uint8_t *host_source = &host_source_view[0]

        cdef da_t device_destination
        cdef cpp_bool alloced

        check_fletcher_status(self.platform.get().prepareHostBuffer(host_source, &device_destination, size, &alloced))

        return device_destination, alloced


    def cache_host_buffer(self, host_bytes, int64_t size):
        #Accepts bytes-like objects for host_bytes
        cdef const uint8_t[:] host_source_view = host_bytes
        cdef const uint8_t *host_source = &host_source_view[0]

        cdef da_t device_destination

        check_fletcher_status(self.platform.get().cacheHostBuffer(host_source, &device_destination, size))

        return device_destination

    def terminate(self):
        check_fletcher_status(self.platform.get().terminate())


