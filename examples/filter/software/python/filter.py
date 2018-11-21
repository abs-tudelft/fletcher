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

import gc
import timeit
import pandas as pd
import pyarrow as pa
import argparse
import numpy as np

import filter_custom


class Timer:
    def __init__(self, gc_disable=True):
        self.starttime = 0
        self.stoptime = 0
        self.gc_disable = gc_disable

    def start(self):
        if self.gc_disable:
            gc.disable()
        self.starttime = timeit.default_timer()

    def stop(self):
        self.stoptime = timeit.default_timer()
        gc.enable()

    def seconds(self):
        return self.stoptime - self.starttime


def create_batch_from_frame_basic(frame):
    """Converts Pandas dataframe to Arrow batch using the basic from_arrays() function
    Args:
        frame: dataframe to convert

    Returns:
        Arrow RecordBatch

    """
    fields = [pa.field("First", pa.string(), False),
              pa.field("Last", pa.string(), False),
              pa.field("Zip", pa.uint16(), False)]

    schema = pa.schema(fields)

    first_names = pa.array(frame["First"])
    last_names = pa.array(frame["Last"])
    zip_codes = pa.array(frame["Zip"])

    return pa.RecordBatch.from_arrays([first_names, last_names, zip_codes], schema)


def create_batch_from_frame_fast(frame, nthreads=None):
    """Converts Pandas dataframe to Arrow batch in parallel.

    Args:
        frame: dataframe to convert
        nthreads: Number of CPU threads to use

    Returns:
        Arrow RecordBatch

    """
    fields = [pa.field("First", pa.string(), False),
              pa.field("Last", pa.string(), False),
              pa.field("Zip", pa.uint16(), False)]

    schema = pa.schema(fields)

    return pa.RecordBatch.from_pandas(df=frame, schema=schema, preserve_index=False, nthreads=nthreads)


def filter_dataframe_python(frame, zip_code):
    """Filter a dataframe using standard Pandas syntax.

    The filter removes rows that contain last_name="Smith" and zip_code as selected.

    Args:
        frame: Frame to be filtered
        zip_code: Special zip_code to filter on.

    Returns:
        Pandas dataframe containing only the column "First". All rows containing last_name="Smith" & zip_code=zip_code
        are filtered out.

    """
    return frame.loc[(frame["Last"]!="Smith") | (frame["Zip"]!=zip_code), ["First"]]


def filter_record_batch_python(batch, zip_code):
    """Filter a RecordBatch using a rather hacky Python loop.

    The filter removes rows that contain last_name="Smith" and zip_code as selected.

    Args:
        batch: bach to be filtered
        zip_code: Special zip_code to filter on.

    Returns:
        Arrow RecordBatch containing only the column "First". All rows containing last_name="Smith" & zip_code=zip_code
        are filtered out.

    """
    first_names = []

    for i in range(batch.num_rows):
        if not (batch.column(1)[i] == "Smith" and batch.column(2)[i] == zip_code):
            first_names.append(batch.column(0)[i].as_py())

    field = pa.field("First", pa.string(), False)
    schema = pa.schema([field])

    return pa.RecordBatch.from_arrays([pa.array(first_names, type=pa.string())], schema)


if __name__ == "__main__":
    t = Timer()

    parser = argparse.ArgumentParser()
    parser.add_argument("--num_exp", dest="ne", default=1,
                        help="Number of experiments to perform")
    parser.add_argument("--input_strings", dest="input_file", default="../cmake-build-debug/rows1024.dat",
                        help="Path to file with strings to search through")
    parser.add_argument("--platform_type", dest="platform_type", default="echo", choices=["echo", "aws"],
                        help="Type of FPGA platform")
    parser.add_argument("--ser_threads", dest="ser_threads", default=1,
                        help="Amount of threads to use for Pandas to Arrow serialization")
    parser.add_argument("--special_zip_code", dest="special_zip_code", default=1337,
                        help="Special zip code to filter on.")
    args = parser.parse_args()

    # Parsed args
    ne = int(args.ne)
    input_file = args.input_file
    platform_type = args.platform_type
    ser_threads = int(args.ser_threads)
    special_zip_code = int(args.special_zip_code)

    frame = pd.read_csv(input_file, header=None, dtype={0: np.str, 1: np.str, 2: np.int16})
    frame.columns = ["First", "Last", "Zip"]

    # Timers
    t_ser_basic = []
    t_ser_fast = []
    t_pd_py = []
    t_pa_py = []
    t_pa_cpp = []

    # Results
    r_pd_py = []
    r_pa_py = []
    r_pa_cpp = []

    for i in range(ne):
        t.start()
        batch_basic = create_batch_from_frame_basic(frame)
        t.stop()
        t_ser_basic.append(t.seconds())

        t.start()
        batch_fast = create_batch_from_frame_fast(frame, ser_threads)
        t.stop()
        t_ser_fast.append(t.seconds())

    print("Total Pandas to Arrow serialization times for " + str(ne) + " runs: ")
    print("Pandas to Arrow using from_arrays(): " + str(sum(t_ser_basic)))
    print("Pandas to Arrow using from_pandas(): " + str(sum(t_ser_fast)))

    for i in range(ne):
        # Normal Pandas filtering. Creates copy.
        t.start()
        r_pd_py.append(filter_dataframe_python(frame, special_zip_code))
        t.stop()
        t_pd_py.append(t.seconds())

        # Filter an Arrow record batch using only pure Python. Creates copy.
        t.start()
        r_pa_py.append(filter_record_batch_python(batch_basic, special_zip_code))
        t.stop()
        t_pa_py.append(t.seconds())

        # Filter an Arrow record batch using Cython wrapped CPP. Creates copy.
        t.start()
        r_pa_cpp.append(filter_custom.filter_record_batch_cpp(batch_basic, special_zip_code))
        t.stop()
        t_pa_cpp.append(t.seconds())

    print("Total execution times for " + str(ne) + " runs:")
    print("Pandas pure Python filtering: " + str(sum(t_pd_py)))
    print("Arrow pure Python filtering: " + str(sum(t_pa_py)))

    first_name_schema = pa.schema([pa.field("First", pa.string(), False)])

    if r_pa_py[0].equals(pa.RecordBatch.from_pandas(r_pd_py[0], first_name_schema, preserve_index=False)):
        print("PASS")
    else:
        print("ERROR")