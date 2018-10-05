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

cdef extern from "<memory>":
    shared_ptr[CEchoPlatform] base_to_echo "std::static_pointer_cast<fletcher::EchoPlatform>" (shared_ptr[CFPGAPlatform])

# Todo: implement check status for write/read_mmio (?)
cdef class FPGAPlatform:
    cdef:
        shared_ptr[CFPGAPlatform] fpgaplatform

    def __cinit__(self, *args, **kwargs):
        pass

    def __init__(self, *args, **kwargs):
        pass

    def prepare_column_chunks(self, arrowcolumn):
        return self.fpgaplatform.get().prepare_column_chunks(pyarrow_unwrap_column(arrowcolumn))

    def argument_offset(self):
        return self.fpgaplatform.get().argument_offset()

    def name(self):
        return self.fpgaplatform.get().name()

    def write_mmio(self, unsigned long long offset, fr_t value):
        self.fpgaplatform.get().write_mmio(offset, value)

    cdef _read_mmio(self, uint64_t offset):
        cdef fr_t dest
        self.fpgaplatform.get().read_mmio(offset, &dest)

        return dest

    def read_mmio(self, unsigned long long offset):
        return self._read_mmio(offset)

    def good(self):
        return self.fpgaplatform.get().good()

cdef class EchoPlatform(FPGAPlatform):
    cdef:
        shared_ptr[CEchoPlatform] echoplatform

    def __cinit__(self, *args, **kwargs):
        if type(self) is EchoPlatform:
            self.fpgaplatform.reset(new CEchoPlatform())
            self.echoplatform = base_to_echo(self.fpgaplatform)

    def __init__(self, *args, **kwargs):
        pass