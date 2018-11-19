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


cdef class UserCore:
    """Python wrapper for Fletcher UserCore.

    Args:
        Context on which this UserCore should be based.

    """
    cdef:
        shared_ptr[CUserCore] usercore

    def __cinit__(self, Context context):
        self.usercore.reset(new CUserCore(context.context))

    cdef from_pointer(self, const shared_ptr[CUserCore]& usercore):
        self.usercore = usercore

    @property
    def ctrl_start(self):
        return self.usercore.get().ctrl_start

    @ctrl_start.setter
    def ctrl_start(self, uint32_t value):
        self.usercore.get().ctrl_start = value

    @property
    def ctrl_reset(self):
        return self.usercore.get().ctrl_reset

    @ctrl_reset.setter
    def ctrl_reset(self, uint32_t value):
        self.usercore.get().ctrl_reset = value

    @property
    def done_status(self):
        return self.usercore.get().done_status

    @done_status.setter
    def done_status(self, uint32_t value):
        self.usercore.get().done_status = value

    @property
    def done_status_mask(self):
        return self.usercore.get().done_status_mask

    @done_status_mask.setter
    def done_status_mask(self, uint32_t value):
        self.usercore.get().done_status_mask = value

    def implements_schema(self, schema):
        """Check if the schema of this UserCore is compatible with another Schema.

        Args:
            schema: Schema to compare with.

        Returns:
            True if compatible, False otherwise.

        """
        return self.usercore.get().implementsSchema(pyarrow_unwrap_schema(schema))

    def reset(self):
        check_fletcher_status(self.usercore.get().reset())

    def set_range(self, uint32_t first, uint32_t last):
        """Set the first (inclusive) and last (exclusive) column to process.

        Args:
            first (int):
            last (int):

        """
        check_fletcher_status(self.usercore.get().setRange(first, last))

    def set_arguments(self, list arguments):
        """Set the parameters of the UserCore.

        Args:
            arguments(:obj:`list` of :obj:`int`):

        """
        cdef vector[uint32_t] cpp_arguments
        for argument in arguments:
            cpp_arguments.push_back(argument)

        self.usercore.get().setArguments(cpp_arguments)

    def start(self):
        check_fletcher_status(self.usercore.get().start())

    def get_status(self):
        cdef uint32_t status
        check_fletcher_status(self.usercore.get().getStatus(&status))
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

        check_fletcher_status(self.usercore.get().getReturn(&lo, &hi))
        ret = (<uint64_t>hi << 32) + lo

        scalar = np.uint64(ret)
        cast_scalar = scalar.astype(nptype)

        return cast_scalar.item()

    def wait_for_finish(self, int poll_interval_usec=0):
        """A blocking function that waits for the UserCore to finish.

        Args:
            poll_interval_usec (int): Polling interval in microseconds.

        """
        check_fletcher_status(self.usercore.get().waitForFinish(poll_interval_usec))

    def get_platform(self):
        """Get associated platform.

        Returns:
            Platform associated with this UserCore.

        """
        return pyfletcher_wrap_platform(self.usercore.get().platform())

    def get_context(self):
        """Get associated context.

        Returns:
            Context associated with this UserCore.

        """
        return pyfletcher_wrap_context(self.usercore.get().context())