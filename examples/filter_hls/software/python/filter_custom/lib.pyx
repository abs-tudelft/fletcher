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

from libcpp.memory cimport shared_ptr
from libc.stdlib cimport malloc, free
from libc.stdint cimport *
from libcpp.string cimport string as cpp_string
from libcpp.vector cimport vector
from libcpp cimport bool as cpp_bool

import pandas as pa
import numpy as np
cimport numpy as np
from pyarrow.lib cimport *

cdef extern from "cpp/filter_custom.h" nogil:
    shared_ptr[CRecordBatch] filter_record_batch(shared_ptr[CRecordBatch] batch, uint32_t special_zip_code)


cpdef filter_record_batch_cpp(batch, zip_code):
    return pyarrow_wrap_batch(filter_record_batch(pyarrow_unwrap_batch(batch), zip_code))

cpdef filter_dataframe_python(frame, zip_code):
    """Filter a dataframe using standard Pandas syntax.

    The filter removes rows that contain last_name="Smith" and zip_code as selected.

    Args:
        frame: Frame to be filtered
        zip_code: Special zip_code to filter on.

    Returns:
        Pandas dataframe containing only the column "First". All rows containing last_name="Smith" & zip_code=zip_code
        are filtered out.

    """
    return frame.loc[(frame["Last"] == "Smith") & (frame["Zip"] == zip_code), ["First"]]