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

    def write_mmio(self, uint64_t offset, fr_t value):
        self.fpgaplatform.get().write_mmio(offset, value)

    cdef _read_mmio(self, uint64_t offset):
        cdef fr_t dest
        self.fpgaplatform.get().read_mmio(offset, &dest)

        return dest

    def read_mmio(self, uint64_t offset):
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


#cdef class AWSPlatform(FPGAPlatform):
#    cdef:
#        shared_ptr[CAWSPlatform] awsplatform
#
#    def __cinit__(self, int slot_id=0, int pf_id=0, int bar_id=1):
#        if type(self) is AWSPlatform:
#            self.fpgaplatform.reset(new CAWSPlatform(slot_id, pf_id, bar_id))
#            self.awsplatform = base_to_aws(self.fpgaplatform)
#
#    def __init__(self, int slot_id=0, int pf_id=0, int bar_id=0):
#        pass
#
#    def set_alignment(self, uint64_t alignment):
#        return self.awsplatform.get().set_alignment(alignment)
#
#
#cdef class SNAPPlatform(FPGAPlatform):
#    cdef:
#        shared_ptr[CSNAPPlatform] snapplatform
#
#    def __cinit__(self, int card_no=0, uint32_t action_type=1, cpp_bool sim=False):
#        if type(self) is SNAPPlatform:
#            self.fpgaplatform.reset(new CSNAPPlatform(card_no, action_type, sim))
#            self.snapplatform = base_to_snap(self.fpgaplatform)
#
#    def __init__(self, card_no=0, action_type=1, sim=False):
#        pass
#
#    def set_alignment(self, uint64_t alignment):
#        return self.SNAPplatform.get().set_alignment(alignment)
