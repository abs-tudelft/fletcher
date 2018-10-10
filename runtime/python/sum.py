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
import timeit
import sys
import argparse


def create_table(num_rows):
    np.random.seed(42)
    element_max = np.iinfo(np.int64).max/num_rows
    int_dist = np.random.randint(0, element_max, num_rows)

    # Force creation of null bitmap because Fletcher requires it to not be null
    num_array = pa.array(int_dist, mask=[False]*len(int_dist))

    column_field = pa.field("weight", pa.int64())
    schema = pa.schema([column_field])

    return pa.Table.from_arrays([num_array], schema=schema)


def arrow_column_sum_cpu(table):
    start_time = timeit.default_timer()
    sum_cpu = np.sum(table.column(0).data.chunk(0).to_numpy())
    stop_time = timeit.default_timer()

    print("Sum CPU time: " + str(stop_time - start_time) + " seconds")

    return sum_cpu


def arrow_column_sum_fpga(table, platform_type):
    if platform_type==0:
        platform = pf.EchoPlatform()
    else:
        print("Unsupported platform type " + str(platform_type) + ". Options: 0, 1, 2.", file=sys.stderr)
        sys.exit(1)

    field = table.column(0).field
    print(field.nullable)

    start_time = timeit.default_timer()
    platform.prepare_column_chunks(table.column(0))
    stop_time = timeit.default_timer()

    print("FPGA copy time " + str(stop_time - start_time) + " seconds")

    uc = pf.UserCore(platform)

    uc.reset()

    last_index = table.num_rows
    uc.set_range(0, last_index)

    for i in range(6):
        reg = platform.read_mmio(i)
        print("fpga register " + str(i) + ": " + format(reg, "02x"))

    start_time = timeit.default_timer()

    uc.start()
    uc.wait_for_finish(1000)
    sum_fpga = uc.get_return()

    stop_time = timeit.default_timer()
    print("Sum FPGA time: " + str(stop_time - start_time) + " seconds")

    return sum_fpga

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--platform_type", dest="platform_type", default="0",
                        help="Type of FPGA platform. 0: Echo, 1: AWS, 2: SNAP")
    parser.add_argument("--num_rows", dest="num_rows", default=1024,
                        help="Number of integers in the Arrow array")
    args = parser.parse_args()

    table = create_table(int(args.num_rows))
    sum_cpu = arrow_column_sum_cpu(table)
    sum_fpga = arrow_column_sum_fpga(table, int(args.platform_type))

    print("Expected sum: " + str(sum_cpu))
    print("FPGA sum: " + str(sum_fpga))

    if sum_fpga==sum_cpu:
        print("PASS")
        sys.exit(0)
    else:
        print("ERROR")
        sys.exit(1)