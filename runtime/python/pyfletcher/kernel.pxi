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

cdef vector[shared_ptr[CSchema]] pyfletcher_unwrap_schemaset(schemaset):
  cdef vector[shared_ptr[CSchema]] result

  for sch in schemaset:
    result.push_back(pyarrow_unwrap_schema(sch))

  return result

cdef class Kernel:
    """Python wrapper for Fletcher Kernel.

    Args:
        Context on which this Kernel should be based.

    """
    cdef:
        shared_ptr[CKernel] Kernel

    def __cinit__(self, Context context):
        self.Kernel.reset(new CKernel(context.context))

    cdef from_pointer(self, const shared_ptr[CKernel]& Kernel):
        self.Kernel = Kernel

    @property
    def ctrl_start(self):
        return self.Kernel.get().ctrl_start

    @ctrl_start.setter
    def ctrl_start(self, uint32_t value):
        self.Kernel.get().ctrl_start = value

    @property
    def ctrl_reset(self):
        return self.Kernel.get().ctrl_reset

    @ctrl_reset.setter
    def ctrl_reset(self, uint32_t value):
        self.Kernel.get().ctrl_reset = value

    @property
    def done_status(self):
        return self.Kernel.get().done_status

    @done_status.setter
    def done_status(self, uint32_t value):
        self.Kernel.get().done_status = value

    @property
    def done_status_mask(self):
        return self.Kernel.get().done_status_mask

    @done_status_mask.setter
    def done_status_mask(self, uint32_t value):
        self.Kernel.get().done_status_mask = value

    def implements_schema(self, schemaset):
        """Check if this Kernel implements an operation on a specific set of Arrow schemas.

        Args:
            schemaset: List of Arrow schemas to compare with.

        Returns:
            True if compatible, False otherwise.

        """
        return self.Kernel.get().ImplementsSchemaSet(pyfletcher_unwrap_schemaset(schemaset))

    def reset(self):
        check_fletcher_status(self.Kernel.get().Reset())

    def set_range(self, size_t recordbatch_index, uint32_t first, uint32_t last):
        """Set the first (inclusive) and last (exclusive) column to process.

        Args:
            first (int):
            last (int):

        """
        check_fletcher_status(self.Kernel.get().SetRange(recordbatch_index, first, last))

    def set_arguments(self, list arguments):
        """Set the parameters of the Kernel.

        Args:
            arguments(:obj:`list` of :obj:`int`):

        """
        cdef vector[uint32_t] cpp_arguments
        for argument in arguments:
            cpp_arguments.push_back(argument)

        self.Kernel.get().SetArguments(cpp_arguments)

    def start(self):
        check_fletcher_status(self.Kernel.get().Start())

    def get_status(self):
        cdef uint32_t status
        check_fletcher_status(self.Kernel.get().GetStatus(&status))
        return status

    def get_return(self, np.dtype nptype):
        """Read the return registers.

        Args:
            nptype (np.dtype): How the registers should be interpreted.

        Returns:
            Register contents interpreted as supplied dtype.

        """
        cdef uint32_t hi
        cdef uint32_t lo
        cdef uint64_t ret

        check_fletcher_status(self.Kernel.get().GetReturn(&lo, &hi))
        ret = (<uint64_t>hi << 32) + lo

        scalar = np.uint64(ret)
        cast_scalar = scalar.astype(nptype)

        return cast_scalar.item()

    def wait_for_finish(self, int poll_interval_usec=0):
        """A blocking function that waits for the Kernel to finish.

        Args:
            poll_interval_usec (int): Polling interval in microseconds.

        """
        check_fletcher_status(self.Kernel.get().WaitForFinish(poll_interval_usec))

    def get_context(self):
        """Get associated context.

        Returns:
            Context associated with this Kernel.

        """
        return pyfletcher_wrap_context(self.Kernel.get().context())
