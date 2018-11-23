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
import re
import pandas as pd
import pyarrow as pa
import pyfletcher as pf

# Add pyre2 to the Python 3 compatibility wall of shame
__builtins__.basestring = str
import re2

import re2_arrow


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


def add_matches_cpu_re2(strings, regexes):
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


def add_matches_cpu_re(strings, regexes):
    progs = []
    matches = []

    for regex in regexes:
        progs.append(re.compile(regex))

    for prog in progs:
        result = 0
        for string in strings:
            if prog.fullmatch(string) is not None:
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


def add_matches_fpga_arrow(strings, regexes, platform_type, t_copy, t_fpga):
    t = Timer()

    # Match Arrow array on FPGA
    platform = pf.Platform(platform_type)
    context = pf.Context(platform)
    rc = RegExCore(context)

    # Initialize the platform
    platform.init()

    # Reset the UserCore
    rc.reset()

    # Prepare the column buffers
    context.queue_record_batch(rb)
    t.start()
    context.enable()
    t.stop()
    t_copy.append(t.seconds())

    # Run the example
    rc.set_reg_exp_arguments(0, num_rows)

    # Start the matchers and poll until completion
    t.start()
    rc.start()
    rc.wait_for_finish(10)
    t.stop()
    t_fpga.append(t.seconds())


    # Get the number of matches from the UserCore
    matches = rc.get_matches(np)
    return matches


if __name__ == "__main__":
    t = Timer(gc_disable=False)

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
    t_pa_pyre = []
    t_py_pyre = []
    t_pa_pyre2 = []
    t_py_pyre2 = []
    t_ar_pyre2 = []
    t_ar_cppre = []
    t_ar_cppre_omp = []
    t_copy = []
    t_fpga = []
    t_ftot = []

    t_nser = []
    t_pser = []

    # Matches
    m_pa_pyre = []
    m_py_pyre = []
    m_pa_pyre2 = []
    m_py_pyre2 = []
    m_ar_pyre2 = []
    m_ar_cppre = []
    m_ar_cppre_omp = []
    m_fpga = []

    f = open(input_file, 'r')
    filedata = f.read()

    strings_native = filedata.splitlines()
    strings_pandas = pd.Series(strings_native)

    for i in range(ne):
        t.start()
        rb_n = create_record_batch(strings_native)
        t.stop()
        t_nser.append(t.seconds())

        t.start()
        rb = create_record_batch(strings_pandas)
        t.stop()
        t_pser.append(t.seconds())

    print("Total serialization time for {ne} runs:".format(ne=ne))
    print("Native to Arrow serialization time: " + str(sum(t_nser)))
    print("Pandas to Arrow serialization time: " + str(sum(t_pser)))
    print()
    print("Average serialization time:".format(ne=ne))
    print("Native to Arrow serialization time: " + str(sum(t_nser)/ne))
    print("Pandas to Arrow serialization time: " + str(sum(t_pser)/ne))

    num_rows = len(strings_native)

    for e in range(ne):
        print("Starting experiment {i}".format(i=e))
        # Match Python list on CPU using re (marginal performance improvement most likely possible with Cython)
        t.start()
        #m_py_pyre.append(add_matches_cpu_re(strings_native, regexes))
        t.stop()
        t_py_pyre.append(t.seconds())

        # Match Pandas series on CPU using re (marginal performance improvement most likely possible with Cython)
        t.start()
        #m_pa_pyre.append(add_matches_cpu_re(strings_pandas, regexes))
        t.stop()
        t_pa_pyre.append(t.seconds())

        # Match Python list on CPU using Pyre2 (marginal performance improvement most likely possible with Cython)
        t.start()
        m_py_pyre2.append(add_matches_cpu_re2(strings_native, regexes))
        t.stop()
        t_py_pyre2.append(t.seconds())

        print("Starting pa_pyre2")

        # Match Pandas series on CPU using Pyre2 (marginal performance improvement most likely possible with Cython)
        t.start()
        m_pa_pyre2.append(add_matches_cpu_re2(strings_pandas, regexes))
        t.stop()
        t_pa_pyre2.append(t.seconds())

        # Match Arrow array on CPU (significant performance improvement most likely possible with Cython)
        t.start()
        #m_ar_pyre2.append(add_matches_cpu_arrow(rb.column(0), regexes))
        t.stop()
        t_ar_pyre2.append(t.seconds())

        # Match Arrow array on CPU (with Cython wrapped CPP functions)
        t.start()
        #m_ar_cppre.append(re2_arrow.add_matches_cpp_arrow(rb.column(0), regexes))
        t.stop()
        t_ar_cppre.append(t.seconds())

        print("Starting arcpp_omp")

        # Match Arrow array on CPU (with Cython wrapped CPP OMP functions)
        t.start()
        m_ar_cppre_omp.append(re2_arrow.add_matches_cpp_arrow_omp(rb.column(0), regexes))
        t.stop()
        t_ar_cppre_omp.append(t.seconds())

        print("Starting fpga")

        # Match Arrow array on FPGA
        t.start()
        m_fpga.append(add_matches_fpga_arrow(rb, regexes, platform_type, t_copy, t_fpga))
        t.stop()
        t_ftot.append(t.seconds())

        print("Total runtimes for " + str(ne) + " runs:")
        print("Python list on CPU (re): " + str(sum(t_py_pyre)))
        print("Pandas series on CPU (re): " + str(sum(t_pa_pyre)))
        print("Python list on CPU (Pyre2): " + str(sum(t_py_pyre2)))
        print("Pandas series on CPU (Pyre2): " + str(sum(t_pa_pyre2)))
        print("Arrow array on CPU (Pyre2): " + str(sum(t_ar_pyre2)))
        print("Arrow array on CPU (CPP Re2): " + str(sum(t_ar_cppre)))
        print("Arrow array on CPU (CPP Re2 OMP): " + str(sum(t_ar_cppre_omp)))
        print("Arrow array to FPGA copy: " + str(sum(t_copy)))
        print("Arrow array on FPGA algorithm time: " + str(sum(t_fpga)))
        print("Arrow array on FPGA total: " + str(sum(t_ftot)))
        print()
        print("Average runtimes:")
        print("Python list on CPU (re): " + str(sum(t_py_pyre)/(e+1)))
        print("Pandas series on CPU (re): " + str(sum(t_pa_pyre)/(e+1)))
        print("Python list on CPU (Pyre2): " + str(sum(t_py_pyre2)/(e+1)))
        print("Pandas series on CPU (Pyre2): " + str(sum(t_pa_pyre2)/(e+1)))
        print("Arrow array on CPU (Pyre2): " + str(sum(t_ar_pyre2)/(e+1)))
        print("Arrow array on CPU (CPP Re2): " + str(sum(t_ar_cppre)/(e+1)))
        print("Arrow array on CPU (CPP Re2 OMP): " + str(sum(t_ar_cppre_omp)/(e+1)))
        print("Arrow array to FPGA copy: " + str(sum(t_copy)/(e+1)))
        print("Arrow array on FPGA algorithm time: " + str(sum(t_fpga)/(e+1)))
        print("Arrow array on FPGA total: " + str(sum(t_ftot)/(e+1)))

    with open("Output.txt", "w") as text_file:
        text_file.write("Total runtimes for " + str(ne) + " runs:")
        text_file.write("\nPython list on CPU (re): " + str(sum(t_py_pyre)))
        text_file.write("\nPandas series on CPU (re): " + str(sum(t_pa_pyre)))
        text_file.write("\nPython list on CPU (Pyre2): " + str(sum(t_py_pyre2)))
        text_file.write("\nPandas series on CPU (Pyre2): " + str(sum(t_pa_pyre2)))
        text_file.write("\nArrow array on CPU (Pyre2): " + str(sum(t_ar_pyre2)))
        text_file.write("\nArrow array on CPU (CPP Re2): " + str(sum(t_ar_cppre)))
        text_file.write("\nArrow array on CPU (CPP Re2 OMP): " + str(sum(t_ar_cppre_omp)))
        text_file.write("\nArrow array to FPGA copy: " + str(sum(t_copy)))
        text_file.write("\nArrow array on FPGA algorithm time: " + str(sum(t_fpga)))
        text_file.write("\nArrow array on FPGA total: " + str(sum(t_ftot)))
        text_file.write("\n")
        text_file.write("\nAverage runtimes:")
        text_file.write("\nPython list on CPU (re): " + str(sum(t_py_pyre) / ne))
        text_file.write("\nPandas series on CPU (re): " + str(sum(t_pa_pyre) / ne))
        text_file.write("\nPython list on CPU (Pyre2): " + str(sum(t_py_pyre2) / ne))
        text_file.write("\nPandas series on CPU (Pyre2): " + str(sum(t_pa_pyre2) / ne))
        text_file.write("\nArrow array on CPU (Pyre2): " + str(sum(t_ar_pyre2) / ne))
        text_file.write("\nArrow array on CPU (CPP Re2): " + str(sum(t_ar_cppre) / ne))
        text_file.write("\nArrow array on CPU (CPP Re2 OMP): " + str(sum(t_ar_cppre_omp) / ne))
        text_file.write("\nArrow array to FPGA copy: " + str(sum(t_copy) / ne))
        text_file.write("\nArrow array on FPGA algorithm time: " + str(sum(t_fpga) / ne))
        text_file.write("\nArrow array on FPGA total: " + str(sum(t_ftot) / ne))

    # Accumulated matches
    a_py_pyre = [0] * np
    a_pa_pyre = [0] * np
    a_py_pyre2 = [0] * np
    a_pa_pyre2 = [0] * np
    a_ar_pyre2 = [0] * np
    a_ar_cppre = [0] * np
    a_ar_cppre_omp = [0] * np
    a_fpga = [0] * np

    # Todo: Temporary shortcut
    m_py_pyre = m_pa_pyre2
    m_pa_pyre = m_pa_pyre2
    m_ar_pyre2 = m_pa_pyre2
    m_ar_cppre = m_pa_pyre2

    for p in range(np):
        for e in range(ne):
            a_py_pyre[p] += m_py_pyre[e][p]
            a_pa_pyre[p] += m_pa_pyre[e][p]
            a_py_pyre2[p] += m_py_pyre2[e][p]
            a_pa_pyre2[p] += m_pa_pyre2[e][p]
            a_ar_pyre2[p] += m_ar_pyre2[e][p]
            a_ar_cppre[p] += m_ar_cppre[e][p]
            a_ar_cppre_omp[p] += m_ar_cppre_omp[e][p]
            a_fpga[p] += m_fpga[e][p]

    # Check if matches are equal
    if (a_py_pyre2 == a_pa_pyre2) \
            and (a_pa_pyre2 == a_ar_pyre2) \
            and (a_ar_pyre2 == a_py_pyre) \
            and (a_py_pyre == a_pa_pyre) \
            and (a_pa_pyre == a_ar_cppre)\
            and (a_ar_cppre == a_ar_cppre_omp)\
            and (a_ar_cppre_omp == a_fpga):
        print("PASS")
    else:
        print("ERROR")
