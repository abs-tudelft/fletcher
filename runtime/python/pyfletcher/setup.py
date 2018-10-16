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

from distutils.core import setup, Extension
from Cython.Build import cythonize

import numpy as np
import pyarrow as pa

print(np.get_include())
print(pa.get_include())
print(pa.get_libraries())
print(pa.get_library_dirs())

ext_modules = cythonize(Extension(
    "lib",
    ["lib.pyx"],
    language="c++",
    extra_compile_args=["-std=c++11", "-O3"],
    extra_link_args=["-std=c++11"]
))

for ext in ext_modules:
    # The Numpy C headers are currently required
    ext.include_dirs.append(np.get_include())
    ext.include_dirs.append(pa.get_include())
    ext.libraries.extend(pa.get_libraries())
    ext.library_dirs.extend(pa.get_library_dirs())
    # Todo: fix these two, also had to run ldconfig after fletcher install
    ext.libraries.extend(["fletcher", "arrow"])
    ext.library_dirs.extend(["/usr/local/lib"])
    # Try uncommenting the following line on Linux if you otherwise
    # get weird linker errors or runtime crashes
    ext.define_macros.append(("_GLIBCXX_USE_CXX11_ABI", "0"))

setup(
    ext_modules=ext_modules,
)

#https://github.com/pypa/manylinux