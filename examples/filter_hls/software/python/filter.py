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
import pyfletcher as pf

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


def get_filter_read_schema():
    fields = [pa.field("First", pa.string(), False),
              pa.field("Last", pa.string(), False),
              pa.field("Zip", pa.uint32(), False)]

    return pa.schema(fields)


def get_filter_write_schema():
    field = pa.field("First", pa.string(), False)
    return pa.schema([field], metadata={"fletcher_mode": "write"})


def create_batch_from_frame_basic(frame):
    """Converts Pandas dataframe to Arrow batch using the basic from_arrays() function
    Args:
        frame: dataframe to convert

    Returns:
        Arrow RecordBatch

    """
    schema = get_filter_read_schema()

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
              pa.field("Zip", pa.uint32(), False)]

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
    return frame.loc[(frame["Last"] == "Smith") & (frame["Zip"] == zip_code), ["First"]]


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
        if batch.column(1)[i] == "Smith" and batch.column(2)[i] == zip_code:
            first_names.append(batch.column(0)[i].as_py())

    schema = get_filter_write_schema()

    return pa.RecordBatch.from_arrays([pa.array(first_names, type=pa.string())], schema)


def get_filter_output_rb(offsets_buffer_size, values_buffer_size):
    string_array_length = offsets_buffer_size / 4 - 1
    offsets_buffer = pa.allocate_buffer(offsets_buffer_size)
    values_buffer = pa.allocate_buffer(values_buffer_size)

    array = pa.StringArray.from_buffers(string_array_length, offsets_buffer, values_buffer)

    return pa.RecordBatch.from_arrays([array], get_filter_write_schema())


def filter_record_batch_fpga(batch_in, zip_code, platform_type, offsets_buffer_out_size, values_buffer_out_size, t_copy,
                             t_fpga):
    t = Timer()
    platform = pf.Platform(platform_type)
    context = pf.Context(platform)
    uc = pf.UserCore(context)

    batch_out = get_filter_output_rb(offsets_buffer_out_size, values_buffer_out_size)

    platform.init()

    context.queue_record_batch(batch_in)
    context.queue_record_batch(batch_out)

    uc.reset()
    t.start()
    context.enable()
    t.stop()
    t_copy.append(t.seconds())
    uc.set_range(0, batch_in.num_rows)
    uc.set_arguments([zip_code])

    t.start()
    uc.start()
    uc.wait_for_finish(10)
    t.stop()
    t_fpga.append(t.seconds())

    platform.copy_device_to_host(context.get_buffer_device_address(3, 0), offsets_buffer_out_size,
                           batch_out.column(0).buffers()[1])
    platform.copy_device_to_host(context.get_buffer_device_address(3, 1), values_buffer_out_size,
                                 batch_out.column(0).buffers()[2])

    return batch_out


if __name__ == "__main__":
    t = Timer(gc_disable=False)

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

    frame = pd.read_csv(input_file, header=None, dtype={0: np.str, 1: np.str, 2: np.uint32}, keep_default_na=False)
    frame.columns = ["First", "Last", "Zip"]

    # Timers
    t_ser_basic = []
    t_ser_fast = []
    t_pd_py = []
    t_pd_cy = []
    t_pa_py = []
    t_pa_cpp = []
    t_fpga = []
    t_copy = []
    t_ftot = []

    # Results
    r_pd_py = []
    r_pd_cy = []
    r_pa_py = []
    r_pa_cpp = []
    r_fpga = []

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

        # Normal Pandas filtering. Creates copy.
        t.start()
        r_pd_cy.append(filter_custom.filter_dataframe_python(frame, special_zip_code))
        t.stop()
        t_pd_cy.append(t.seconds())

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

        # Filter an Arrow record batch using the FPGA. Creates copy.
        # Currently requires prior knowledge on the size of the output batch.
        t.start()
        r_fpga.append(filter_record_batch_fpga(batch_basic, special_zip_code, platform_type,
                                               r_pa_cpp[0].column(0).buffers()[1].size,
                                               r_pa_cpp[0].column(0).buffers()[2].size,
                                               t_copy,
                                               t_fpga))
        t.stop()
        t_ftot.append(t.seconds())

        print("Total execution times for " + str(ne) + " runs:")
        print("Pandas pure Python filtering: " + str(sum(t_pd_py)))
        print("Pandas Cython (?) filtering: " + str(sum(t_pd_cy)))
        print("Arrow pure Python filtering: " + str(sum(t_pa_py)))
        print("Arrow CPP filtering: " + str(sum(t_pa_cpp)))
        print("Filter Arrow FPGA copy time: " + str(sum(t_copy)))
        print("Filter Arrow FPGA algorithm time: " + str(sum(t_fpga)))
        print("Filter Arrow FPGA total time: " + str(sum(t_ftot)))
        print()
        print("Average execution times:")
        print("Pandas pure Python filtering: " + str(sum(t_pd_py) / (i + 1)))
        print("Pandas Cython (?) filtering: " + str(sum(t_pd_cy) / (i + 1)))
        print("Arrow pure Python filtering: " + str(sum(t_pa_py) / (i + 1)))
        print("Arrow CPP filtering: " + str(sum(t_pa_cpp) / (i + 1)))
        print("Filter Arrow FPGA copy time: " + str(sum(t_copy)/(i+1)))
        print("Filter Arrow FPGA algorithm time: " + str(sum(t_fpga)/(i+1)))
        print("Filter Arrow FPGA total time: " + str(sum(t_ftot)/(i+1)))

    with open("Output.txt", "w") as textfile:
        textfile.write("\nTotal execution times for " + str(ne) + " runs:")
        textfile.write("\nPandas pure Python filtering: " + str(sum(t_pd_py)))
        textfile.write("\nPandas Cython (?) filtering: " + str(sum(t_pd_cy)))
        textfile.write("\nArrow pure Python filtering: " + str(sum(t_pa_py)))
        textfile.write("\nArrow CPP filtering: " + str(sum(t_pa_cpp)))
        textfile.write("\nFilter Arrow FPGA copy time: " + str(sum(t_copy)))
        textfile.write("\nFilter Arrow FPGA algorithm time: " + str(sum(t_fpga)))
        textfile.write("\nFilter Arrow FPGA total time: " + str(sum(t_ftot)))
        textfile.write("\n")
        textfile.write("\nAverage execution times:")
        textfile.write("\nPandas pure Python filtering: " + str(sum(t_pd_py) / ne))
        textfile.write("\nPandas Cython (?) filtering: " + str(sum(t_pd_cy) / ne))
        textfile.write("\nArrow pure Python filtering: " + str(sum(t_pa_py) / ne))
        textfile.write("\nArrow CPP filtering: " + str(sum(t_pa_cpp) / ne))
        textfile.write("\nFilter Arrow FPGA copy time: " + str(sum(t_copy)/(i+1)))
        textfile.write("\nFilter Arrow FPGA algorithm time: " + str(sum(t_fpga)/(i+1)))
        textfile.write("\nFilter Arrow FPGA total time: " + str(sum(t_ftot)/(i+1)))

    # Check if results are equal.
    pass_counter = 0
    cross_exp_pass_counter = 0
    for i in range(ne):
        if r_pa_py[i].equals(pa.RecordBatch.from_pandas(r_pd_py[i], get_filter_write_schema(), preserve_index=False)) \
                and r_pa_py[i].equals(r_pa_cpp[i]) \
                and r_pa_py[i].equals(pa.RecordBatch.from_pandas(r_pd_cy[i], get_filter_write_schema(), preserve_index=False)) \
                and r_pa_py[i].equals(r_fpga[i]):
            pass_counter += 1

        if r_pa_py[0].equals(r_pa_py[i]):
            cross_exp_pass_counter += 1

    if pass_counter == ne and cross_exp_pass_counter == ne:
        print("PASS")
    else:
        print("ERROR ({error_counter} errors)".format(error_counter=ne - pass_counter))
