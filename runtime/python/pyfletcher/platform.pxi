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

cdef class Platform:
    cdef:
        shared_ptr[CPlatform] platform

    def __init__(self, str name = "", quiet = True):
        self._create(name, quiet)
        #raise TypeError("Do not call {}'s constructor directly, use "
        #                "pyfletcher.Platform.create() instead."
        #                .format(self.__class__.__name__))

    cdef _create(self, str name = "", quiet = True):
        if not name:
            check_fletcher_status(CPlatform.createUnnamed(&self.platform))
        else:
            check_fletcher_status(CPlatform.createNamed(name.encode("utf-8"), &self.platform, quiet))