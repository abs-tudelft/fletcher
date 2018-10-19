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
    cdef:
        shared_ptr[CContext] context

    def __cinit__(self, Platform platform):
        check_fletcher_status(CContext.Make(&self.context, platform.platform))

    cdef from_pointer(self, shared_ptr[CContext] context):
        self.context = context

    def queueArray(self, array, field=None, cache=False):
        if not field:
            check_fletcher_status(self.context.get().queueArray(pyarrow_unwrap_array(array), cache))
        else:
            check_fletcher_status(self.context.get().queueArray(pyarrow_unwrap_array(array),
                                                                pyarrow_unwrap_field(field),
                                                                cache))

    def queueRecordBatch(self, record_batch, cache=False):
        check_fletcher_status(self.context.get().queueRecordBatch(pyarrow_unwrap_batch(record_batch), cache))

    def enable(self):
        check_fletcher_status(self.context.get().enable())