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

from setuptools import setup, Extension
from Cython.Build import cythonize

import numpy as np
import pyarrow as pa

ext_modules = cythonize(Extension(
    "kmeans.lib",
    ["kmeans/lib.pyx", "kmeans/cpp/kmeans.cpp"],
    language="c++",
    extra_compile_args=["-std=c++11", "-Ofast", "-fopenmp", "-march=native"],
    extra_link_args=["-std=c++11", "-fopenmp"]
))

for ext in ext_modules:
    ext.include_dirs.append(np.get_include())
    ext.include_dirs.append(pa.get_include())
    ext.include_dirs.append("./kmeans/cpp")
    ext.libraries.extend(pa.get_libraries())
    ext.libraries.extend(["arrow"])
    ext.library_dirs.extend(pa.get_library_dirs())
    ext.runtime_library_dirs.extend(pa.get_library_dirs())
    ext.define_macros.append(("_GLIBCXX_USE_CXX11_ABI", "0"))

setup(ext_modules=ext_modules)

