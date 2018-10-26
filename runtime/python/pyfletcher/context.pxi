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

cdef class Context():
    """Python wrapper for Fletcher Context.

    Args:
        Platform this context should run on.

    """
    cdef:
        shared_ptr[CContext] context

    def __cinit__(self, Platform platform):
        check_fletcher_status(CContext.Make(&self.context, platform.platform))

    cdef from_pointer(self, shared_ptr[CContext] context):
        self.context = context

    def queueArray(self, array, field=None, cache=False):
        """Enqueue an arrow::Array for usage preparation on the device.

        This function enqueues any buffers in the underlying structure of the Array. If hardware was generated to not
        contain validity bitmap support, while arrow implementation provides a validity bitmap anyway, discrepancies
        between device hardware and host software may occur. Therefore, it is recommended to use queueArray with the
        field argument.

        Args:
            array: Arrow Array to queue
            field: Arrow Schema corresponding to this array.
            cache (bool): Force caching; i.e. the Array is guaranteed to be copied to on-board memory.

        """
        if not field:
            check_fletcher_status(self.context.get().queueArray(pyarrow_unwrap_array(array), cache))
        else:
            check_fletcher_status(self.context.get().queueArray(pyarrow_unwrap_array(array),
                                                                pyarrow_unwrap_field(field),
                                                                cache))

    def queueRecordBatch(self, record_batch, cache=False):
        """Enqueue an arrow::RecordBatch for usage preparation on the device.

        Args:
            record_batch: Arrow RecordBatch to queue
            cache (bool): Force caching; i.e. the RecordBatch is guaranteed to be copied to on-board memory.

        """
        check_fletcher_status(self.context.get().queueRecordBatch(pyarrow_unwrap_batch(record_batch), cache))

    def enable(self):
        check_fletcher_status(self.context.get().enable())