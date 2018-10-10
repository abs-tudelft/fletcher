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
    cdef:
        shared_ptr[CUserCore] usercore

    def __cinit__(self, FPGAPlatform platform):
        self.usercore.reset(new CUserCore(platform.fpgaplatform))

    def implements_schema(self, schema):
        return self.usercore.get().implements_schema(pyarrow_unwrap_schema(schema))

    def reset(self):
        self.usercore.get().reset()

    def set_range(self, unsigned int first, unsigned int last):
        self.usercore.get().set_range(first, last)

    # Todo: To be implemented
    def set_arguments(self):
        pass

    def start(self):
        self.usercore.get().start()

    def get_status(self):
        return self.usercore.get().get_status()

    def get_return(self):
        return self.usercore.get().get_return()

    def wait_for_finish(self, poll_interval_usec=0):
        return self.usercore.get().wait_for_finish(poll_interval_usec)