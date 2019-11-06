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

cdef extern from * nogil:
    float uint32_to_float "reinterpret_cast<float &>"(uint32_t)
    double uint64_to_double "reinterpret_cast<double &>"(uint64_t)

cdef class Platform:
    """Python wrapper for Fletcher Platforms.

    Most functions are exposed for completeness, but for mose uses cases Context and Kernel are more suited.

    Args:
        name (:obj:'str', optional): Which platform driver to use. Leave empty to autodetect.
        quiet (:obj:'bool', optional): Whether to suppress logging messages. Defaults to True.
    """
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

    def name(self):
        return self.platform.get().name().decode("utf-8")

    def init(self):
        check_fletcher_status(self.platform.get().Init())

    def write_mmio(self, uint64_t offset, uint32_t value):
        """Write to MMIO register.

        Args:
            offset (int): Register offset.
            value (int): Value to write.

        """
        check_fletcher_status(self.platform.get().WriteMMIO(offset, value))

    def read_mmio(self, uint64_t offset, str type="uint"):
        """Read from MMIO register.


        Args:
            offset (int): Register offset.
            type (str): How to interpret register. Can be "uint" (default), "int" or "float".

        Returns:
            Read value.

        """
        cdef uint32_t value
        check_fletcher_status(self.platform.get().ReadMMIO(offset, &value))

        if type == "uint":
            return value
        elif type == "int":
            return <int32_t> value
        elif type == "float":
            return uint32_to_float(value)
        else:
            raise ValueError("Invalid type in read_mmio(). Options: 'uint' (default), 'int' or 'float'")

    def read_mmio_64(self, uint64_t offset, str type="uint"):
        """Read 64 bit value from two 32 bit MMIO registers.


        Args:
            offset (int): Register offset.
            type (str): How to interpret register. Can be "uint" (default), "int" or "double".

        Returns:
            Read value.

        """
        cdef uint64_t value
        check_fletcher_status(self.platform.get().ReadMMIO64(offset, &value))

        if type == "uint":
            return value
        elif type == "int":
            return <int64_t> value
        elif type == "double":
            return uint64_to_double(value)
        else:
            raise ValueError("Invalid type in read_mmio_64(). Options: 'uint' (default), 'int' or 'double'")

    def device_malloc(self, size_t size):
        """Allocate a region of memory on the device.

        Args:
            size (int): Amount of bytes to allocate.

        Returns:
            int: Device address.

        """
        cdef da_t device_address
        check_fletcher_status(self.platform.get().DeviceMalloc(&device_address, size))

        return device_address

    def device_free(self, da_t device_address):
        """Free a previously allocated memory region on the device.

        Args:
            device_address (int): Device address of the memory region.

        """
        check_fletcher_status(self.platform.get().DeviceFree(device_address))

    def copy_host_to_device(self, host_bytes, da_t device_destination, uint64_t size):
        """Copy a memory region from device memory to host memory.

        Args:
            host_bytes (bytes, bytearray or ndarray (dtype=np.uint8)): Bytes to copy
            device_destination (int): Destination in device memory
            size (int): The amount of bytes

        """
        cdef const uint8_t[:] host_source_view = host_bytes
        cdef const uint8_t *host_source = &host_source_view[0]

        check_fletcher_status(self.platform.get().CopyHostToDevice(<uint8_t*>host_source, device_destination, size))

    def copy_device_to_host(self, da_t device_source, uint64_t size, buffer=None):
        """Copy a memory region from device memory to host memory.

        Args:
            device_source (int): Source in device memory
            size (int): The amount of bytes
            buffer: Pyarrow buffer to copy bytes to

        Returns:
            ndarray: Read bytes
        """
        cdef const uint8_t[:] buffer_view
        cdef const uint8_t *host_destination

        if buffer is None:
            buffer = np.zeros((size,), dtype=np.uint8)
            buffer_view = buffer
            host_destination = &buffer_view[0]
        else:
            host_destination = pyarrow_unwrap_buffer(buffer).get().mutable_data()

        check_fletcher_status(self.platform.get().CopyDeviceToHost(device_source, <uint8_t*>host_destination, size))

        return buffer

    def terminate(self):
        check_fletcher_status(self.platform.get().Terminate())
