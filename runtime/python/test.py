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

import pyarrow as pa
import pyfletcher as pf
import numpy as np

def test_platform():
    # Create
    platform = pf.Platform()

    # Init
    platform.init()

    # Info
    print("Platform name: " + platform.get_name())

    # Malloc/free
    address = platform.device_malloc(1024)
    platform.device_free(address)

    # MMIO
    platform.write_mmio(0, 0)
    val = platform.read_mmio(0)

    # Buffers
    size = 7
    host_bytes = bytes([1, 2, 3, 4, 5, 6, 7])
    host_bytearray = bytearray([1, 2, 3, 4, 5, 6, 7])
    host_nparray = np.array([1, 2, 3, 4, 5, 6, 7], dtype=np.uint8)

    platform.copy_host_to_device(host_bytes, 0, size)
    platform.copy_host_to_device(host_bytearray, 7, size)
    platform.copy_host_to_device(host_nparray, 14, size)

    buffer = platform.copy_device_to_host(0, 7)

    platform.terminate()

    return True

if __name__ == "__main__":
    test_platform()

    print("Reaching end of program")
