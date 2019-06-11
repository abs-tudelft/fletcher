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

import os
import numpy as np
import pyarrow as pa

def read(fname):
    with open(os.path.join(os.path.dirname(__file__), fname)) as f:
        return f.read()

setup(
    name="pyfletcher",
    version="0.0.8",
    author="Lars van Leeuwen",
    packages=['pyfletcher'],
    description="A Python wrapper for the Fletcher runtime library",
    long_description=read('README.md'),
    long_description_content_type='text/markdown',
    url="https://github.com/abs-tudelft/fletcher",
    project_urls = {
        "Bug Tracker": "https://github.com/abs-tudelft/fletcher/issues",
        "Documentation": "https://abs-tudelft.github.io/fletcher/",
        "Source Code": "https://github.com/abs-tudelft/fletcher/",
    },
    ext_modules=[
        Extension(
            "pyfletcher.lib",
            ["pyfletcher/lib.pyx"],
            language="c++",
            define_macros=[
                ("_GLIBCXX_USE_CXX11_ABI", "0")
            ],
            include_dirs=[
                np.get_include(),
                pa.get_include(),
                "../../common/cpp/include",
                "../../common/cpp/src",
                "../cpp/src"
            ],
            libraries=[
                pa.get_libraries(),
                "fletcher"
            ],
            library_dirs=[
                pa.get_library_dirs()
            ],
            runtime_library_dirs=[
                pa.get_library_dirs()
            ],
            extra_compile_args=["-std=c++11", "-O3"],
            extra_link_args=["-std=c++11"]
        )
    ],
    install_requires=[
        'numpy >= 1.14',
        'pyarrow',
        'pandas'
    ],
    setup_requires=[
        'cython >= 0.27',
        'numpy',
        'pyarrow'
    ],
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
