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

import timeit
import argparse
import gc
import pandas as pd
import pyarrow as pa
import pyfletcher as pf

# Add pyre2 to the Python 3 compatibility wall of shame
__builtins__.basestring = str
import re2


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


class RegExCore(pf.UserCore):

    def __init__(self, context):
        self.reuc_result_offset = 42
        if self.get_platform().get_name() == "aws":
            self.active_units = 16
            self.ctrl_start = 0x0000FFFF
            self.ctrl_reset = 0xFFFF0000
            self.done_status = 0xFFFF0000
            self.done_status_mask = 0xFFFFFFFF
        elif self.get_platform().get_name() == "echo":
            self.active_units = 16
        elif self.get_platform().get_name() == "snap":
            self.active_units = 8
            self.ctrl_start = 0x000000FF
            self.ctrl_reset = 0x0000FF00
            self.done_status = 0x0000FF00
            self.done_status_mask = 0x0000FFFF

    def _generate_unit_arguments(self, first_index, last_index):
        arguments = [0]*2*self.active_units

        if first_index >= last_index:
            raise RuntimeError("First index cannot be larger than or equal to last index.")

        match_rows = last_index - first_index
        for i in range(self.active_units):
            first = first_index + i*match_rows/self.active_units
            last = first + match_rows/self.active_units
            arguments[i] = first
            arguments[self.active_units + i] = last

        return arguments

    def set_reg_exp_arguments(self, first_index, last_index):
        arguments = self._generate_unit_arguments(first_index, last_index)
        self.set_arguments(arguments)

    def get_matches(self, num_reads):
        matches = []
        for p in range(num_reads):
            matches.append(self.get_platform().read_mmio(self.reuc_result_offset + p))

        return matches




def create_record_batch(strings):
    """
    Creates an Arrow record batch containing one column of strings.

    Args:
        strings(sequence, iterable, ndarray or Series): Strings for in the record batch

    Returns:
        record_batch

    """
    array = pa.array(strings)
    column_field = pa.field("tweets", pa.string(), False)
    schema = pa.schema([column_field])
    return pa.RecordBatch.from_arrays([array], schema)


def add_matches_cpu(strings, regexes):
    progs = []
    matches = []

    for regex in regexes:
        progs.append(re2.compile(regex))

    for prog in progs:
        result = 0
        for string in strings:
            if prog.test_fullmatch(string):
                result += 1
        matches.append(result)

    return matches


def add_matches_cpu_arrow(strings, regexes):
    progs = []
    matches = []

    for regex in regexes:
        progs.append(re2.compile(regex))

    for prog in progs:
        result = 0
        for string in strings:
            if prog.test_fullmatch(string.as_py()):
                result += 1
        matches.append(result)

    return matches


if __name__ == "__main__":
    t = Timer()

    parser = argparse.ArgumentParser()
    parser.add_argument("--num_exp", dest="ne", default=1,
                        help="Number of experiments to perform")
    parser.add_argument("--input_strings", dest="input_file", default="../build/strings1024.dat",
                        help="Path to file with strings to search through")
    parser.add_argument("--platform_type", dest="platform_type", default="echo", choices=["echo", "aws"],
                        help="Type of FPGA platform")
    args = parser.parse_args()

    # Parsed args
    ne = int(args.ne)
    input_file = args.input_file
    platform_type = args.platform_type

    # Regular expressions to match in input file
    regexes = [".*(?i)bird.*", ".*(?i)bunny.*", ".*(?i)cat.*", ".*(?i)dog.*", ".*(?i)ferret.*", ".*(?i)fish.*",
               ".*(?i)gerbil.*", ".*(?i)hamster.*", ".*(?i)horse.*", ".*(?i)kitten.*", ".*(?i)lizard.*",
               ".*(?i)mouse.*", ".*(?i)puppy.*", ".*(?i)rabbit.*", ".*(?i)rat.*", ".*(?i)turtle.*"]
    np = len(regexes)

    bytes_copied = 0

    # Timers
    t_pcpu = []
    t_ncpu = []
    t_acpu = []
    t_copy = []
    t_fpga = []

    # Matches
    m_pcpu = []
    m_ncpu = []
    m_acpu = []
    m_fpga = []

    f = open(input_file, 'r')
    filedata = f.read()

    strings_native = filedata.splitlines()
    strings_pandas = pd.Series(strings_native)

    t.start()
    rb = create_record_batch(strings_native)
    t.stop()
    t_nser = t.seconds()

    t.start()
    rb = create_record_batch(strings_pandas)
    t.stop()
    t_pser = t.seconds()

    print("Native to Arrow serialization time: " + str(t_nser))
    print("Pandas to Arrow serialization time: " + str(t_pser))

    num_rows = len(strings_native)

    for e in range(ne):
        # Match Python list on CPU (marginal performance improvement most likely possible with Cython)
        t.start()
        m_ncpu.append(add_matches_cpu(strings_native, regexes))
        t.stop()
        t_ncpu.append(t.seconds())
        print(t.seconds())

        # Match Pandas series on CPU (marginal performance improvement most likely possible with Cython)
        t.start()
        m_pcpu.append(add_matches_cpu(strings_pandas, regexes))
        t.stop()
        t_pcpu.append(t.seconds())
        print(t.seconds())

        # Match Arrow array on CPU (significant performance improvement most likely possible with Cython)
        t.start()
        m_acpu.append(add_matches_cpu_arrow(rb.column(0), regexes))
        t.stop()
        t_acpu.append(t.seconds())
        print(t.seconds())

        # Match Arrow array on FPGA
        platform = pf.Platform(platform_type)
        context = pf.Context(platform)
        rc = RegExCore(context)

        # Initialize the platform
        platform.init()

        # Reset the UserCore
        rc.reset()

        # Prepare the column buffers
        t.start()
        context.queue_record_batch(rb)
        bytes_copied += context.get_queue_size()
        context.enable()
        t.stop()
        t_copy.append(t.seconds())

        # Run the example
        t.start()
        rc.set_reg_exp_arguments(0, num_rows)

        # Start the matchers and poll until completion
        rc.start()
        rc.wait_for_finish(10)

        # Get the number of matches from the UserCore
        m_fpga.append(rc.get_matches(np))
        t.stop()
        t_fpga.append(t.seconds())


    print("Bytes copied: " + str(bytes_copied))

    print("Total runtimes for " + str(ne) + "runs:")
    print("Python list on CPU: " + str(sum(t_ncpu)))
    print("Pandas series on CPU: " + str(sum(t_pcpu)))
    print("Arrow array on CPU: " + str(sum(t_acpu)))
    print("Arrow array on FPGA: " + str(sum(t_fpga)))

    # Accumulated matches
    a_ncpu = [0] * np
    a_pcpu = [0] * np
    a_acpu = [0] * np
    a_fpga = [0] * np

    for p in range(np):
        for e in range(ne):
            a_ncpu[p] += m_ncpu[e][p]
            a_pcpu[p] += m_pcpu[e][p]
            a_acpu[p] += m_acpu[e][p]
            a_fpga[p] += m_fpga[e][p]

    # Check if matches are equal
    if (a_ncpu == a_pcpu) and (a_pcpu == a_acpu) and (a_acpu == a_fpga):
        print("PASS")
    else:
        print("ERROR")
