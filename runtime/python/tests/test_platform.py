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
    platform = pf.Platform("echo", False)

    # Init
    platform.init()

    # Info
    print("Platform name: " + platform.name())

    # Malloc
    address = platform.device_malloc(1024)

    # MMIO
    platform.write_mmio(0, 0)
    val = platform.read_mmio(0)
    val64 = platform.read_mmio_64(0)

    # Buffers
    size = 7
    host_bytes = bytes([1, 2, 3, 4, 5, 6, 7])
    host_bytearray = bytearray([1, 2, 3, 4, 5, 6, 7])
    host_nparray = np.array([1, 2, 3, 4, 5, 6, 7], dtype=np.uint8)

    platform.copy_host_to_device(host_bytes, address, size)
    platform.copy_host_to_device(host_bytearray, address + 7, size)
    platform.copy_host_to_device(host_nparray, address + 14, size)

    buffer = platform.copy_device_to_host(address, 21)
    assert list(buffer) == [1, 2, 3, 4, 5, 6, 7] * 3

    # Free buffer
    platform.device_free(address)

    platform.terminate()

    return True

def test_context():
    # Create
    platform = pf.Platform("echo", False)

    # Init
    platform.init()

    # Create a schema with some stuff
    fields = [
        pa.field("a", pa.uint64(), False),
        pa.field("b", pa.string(), False),
        pa.field("c", pa.uint64(), True),
        pa.field("d", pa.list_(pa.field("e", pa.uint32(), True)), False)
    ]

    schema = pa.schema(fields)

    a = pa.array([1, 2, 3, 4], type=pa.uint64())
    b = pa.array(["hello", "world", "fletcher", "arrow"], type=pa.string())
    c = pa.array([5, 6, 7, 8], mask=np.array([True, False, True, True]), type=pa.uint64())
    d = pa.array([[9, 10, 11, 12], [13, 14], [15, 16, 17], [18]], type=pa.list_(pa.uint32()))
    f = pa.array([19, 20, 21, 22], type=pa.uint32())
    g = pa.array([23, 24, 25, 26], type=pa.uint32())

    rb = pa.RecordBatch.from_arrays([a, b, c, d], schema)

    context = pf.Context(platform)

    context.queue_record_batch(rb)

    context.queue_array(f)

    context.queue_array(g, field=pa.field("g", pa.uint32(), False))

    # Write buffers
    context.enable()

    # Terminate
    platform.terminate()

test_platform()
# test_context()
