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


cdef public api bint pyfletcher_is_usercore(object usercore):
    return isinstance(usercore, UserCore)

cdef public api object pyfletcher_wrap_usercore(const shared_ptr[CUserCore]& uc):
    cdef UserCore result = UserCore.__new__(UserCore)
    result.from_pointer(uc)
    return result

cdef public api shared_ptr[CUserCore] pyfletcher_unwrap_usercore(object usercore):
    cdef UserCore uc

    if pyfletcher_is_usercore(usercore):
        uc = <UserCore>(usercore)
        return uc.usercore

    return shared_ptr[CUserCore]()

cdef public api bint pyfletcher_is_platform(object platform):
    return isinstance(platform, Platform)

cdef public api object pyfletcher_wrap_platform(const shared_ptr[CPlatform]& plat):
    cdef Platform result = Platform.__new__(Platform)
    result.from_pointer(plat)
    return result

cdef public api shared_ptr[CPlatform] pyfletcher_unwrap_platform(object platform):
    cdef Platform plat

    if pyfletcher_is_platform(platform):
        plat = <Platform>(platform)
        return plat.platform

    return shared_ptr[CPlatform]()