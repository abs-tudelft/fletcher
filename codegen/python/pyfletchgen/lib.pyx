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

# distutils: language = c++
# cython: language_level=3

from pyfletchgen.fletchgen cimport fletchgen as cfletchgen
from libc.stdlib cimport malloc, free

def fletchgen(*args):
  cdef int argc = len(args) + 1
  cdef char** argv = <char**>malloc((len(args) + 1) * sizeof(char*))
  if not argv:
    raise MemoryError()

  args = [arg.encode() for arg in args]

  argv[0] = 'pyfletchgen'

  for i in range(len(args)):
    argv[i+1] = args[i]

  return cfletchgen(argc, argv)

