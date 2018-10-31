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


if __name__ == "__main__":
    t = Timer()

    parser = argparse.ArgumentParser()
    parser.add_argument("--num_rows", dest="num_rows", default=1024,
                        help="Number of integers in the Arrow array")
    parser.add_argument("--num_exp", dest="ne", default=1,
                        help="Number of experiments to perform")
    parser.add_argument("--input_strings", dest="input_file", default="../build/strings1024.dat",
                        help="Path to file with strings to search through")
    parser.add_argument("--platform_type", dest="platform_type", default="echo", choices=["echo", "aws"],
                        help="Type of FPGA platform")
    args = parser.parse_args()

    # Parsed args
    num_rows = int(args.num_rows)
    ne = int(args.ne)
    input_file = args.input_file
    platform_type = args.platform_type

    # Regular expressions to match in input file
    regexes = [".*(?i)bird.*", ".*(?i)bunny.*", ".*(?i)cat.*", ".*(?i)dog.*", ".*(?i)ferret.*", ".*(?i)fish.*",
               ".*(?i)gerbil.*", ".*(?i)hamster.*", ".*(?i)horse.*", ".*(?i)kitten.*", ".*(?i)lizard.*",
               ".*(?i)mouse.*", ".*(?i)puppy.*", ".*(?i)rabbit.*", ".*(?i)rat.*", ".*(?i)turtle.*"]

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

    print("Number of rows: " + str(num_rows))

    f = open(input_file, 'r')
    filedata = f.read()

    strings_native = filedata.split(sep='\n')
    strings_pandas = pd.Series(strings_native)


    # Todo: Create function createRecordBatchFromPandas() and createRecordBatchFromNative()
    t.start()
    rb = pa.array(strings_native)
    t.stop()
    t_nser = t.seconds()

    print(t_nser)
    print(rb[5])
