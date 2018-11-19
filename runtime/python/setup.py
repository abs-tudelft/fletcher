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
import os

import numpy as np
import pyarrow as pa

ext_modules = cythonize(Extension(
    "pyfletcher.lib",
    ["pyfletcher/lib.pyx"],
    language="c++",
    extra_compile_args=["-std=c++11", "-O3"],
    extra_link_args=["-std=c++11"]
))

for ext in ext_modules:
    ext.include_dirs.append(np.get_include())
    ext.include_dirs.append(pa.get_include())
    ext.libraries.extend(pa.get_libraries())
    ext.library_dirs.extend(pa.get_library_dirs())
    ext.runtime_library_dirs.extend(pa.get_library_dirs())
    ext.libraries.extend(["fletcher"])
    ext.define_macros.append(("_GLIBCXX_USE_CXX11_ABI", "0"))

this_directory = os.path.abspath(os.path.dirname(__file__))
with open(os.path.join(this_directory, 'README.md'), encoding='utf-8') as f:
    long_description = f.read()

setup(
    name="pyfletcher",
    version="0.0.6",
    author="Lars van Leeuwen",
    packages=['pyfletcher'],
    description="A Python wrapper for the Fletcher runtime library",
    long_description=long_description,
    long_description_content_type='text/markdown',
    url="https://github.com/johanpel/fletcher",
    ext_modules=ext_modules,
    install_requires=[
        'numpy >= 1.14',
        'pyarrow',
        'pandas'
    ],
    setup_requires=['setuptools_scm', 'cython >= 0.27'],
    classifiers=[
        "Programming Language :: Python :: 3",
        "Programming Language :: Cython",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: Apache Software License",
        "Operating System :: POSIX :: Linux"
    ],
    license='Apache License, Version 2.0',
    include_package_data=True
)

#https://github.com/pypa/manylinux
