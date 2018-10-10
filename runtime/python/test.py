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

import pyarrow as pa
import pyfletcher as pf
import numpy as np
import pandas as pd

num_rows=1024

np.random.seed(42)
element_max = np.iinfo(np.int64).max/num_rows
int_dist = np.random.randint(0, element_max, num_rows)
print(int_dist)

testarray = pa.array(int_dist, mask=[False]*len(int_dist))
testcolumn = pa.column("hello", testarray)
print(testarray.buffers())

echo = pf.EchoPlatform()

echo.prepare_column_chunks(testcolumn)

print(echo.good())
print(echo.argument_offset())
print(echo.name())

uc = pf.UserCore(echo)