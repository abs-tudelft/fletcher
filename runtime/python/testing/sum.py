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


def create_record_batch(num_rows):
    np.random.seed(42)
    element_max = np.iinfo(np.int64).max/num_rows
    int_dist = np.random.randint(0, element_max, num_rows)

    # Force creation of null bitmap because Fletcher requires it to not be null
    num_array = pa.array(int_dist)

    column_field = pa.field("weight", pa.int64(), nullable=False)
    schema = pa.schema([column_field])

    return pa.RecordBatch.from_arrays([num_array], schema)


def arrow_column_sum_cpu(batch):
    start_time = timeit.default_timer()
    sum_cpu = np.sum(batch.column(0).to_numpy())
    stop_time = timeit.default_timer()

    print("Sum CPU time: " + str(stop_time - start_time) + " seconds")

    return sum_cpu


def arrow_column_sum_fpga(batch, platform_type):
    # Create a platform
    platform = pf.Platform(platform_type)

    # Create a context
    context = pf.Context(platform)

    # Initialize the platform
    platform.init()

    # Prepare the recordbatch
    context.queueRecordBatch(batch)

    start_time = timeit.default_timer()
    context.enable()
    stop_time = timeit.default_timer()

    print("FPGA copy time " + str(stop_time - start_time) + " seconds")

    # Create UserCore
    uc = pf.UserCore(context)

    # Reset it
    uc.reset()

    # Determine size of table
    last_index = batch.num_rows
    uc.set_range(0, last_index)

    start_time = timeit.default_timer()

    # Start the FPGA user function
    uc.start()
    uc.wait_for_finish(1000)

    #Get the sum from UserCore
    sum_fpga = uc.get_return(np.dtype(np.int64))

    stop_time = timeit.default_timer()
    print("Sum FPGA time: " + str(stop_time - start_time) + " seconds")

    return sum_fpga

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--platform_type", dest="platform_type", default="echo", choices=["echo", "aws"],
                        help="Type of FPGA platform.")
    parser.add_argument("--num_rows", dest="num_rows", default=1024,
                        help="Number of integers in the Arrow array")
    args = parser.parse_args()

    batch = create_record_batch(int(args.num_rows))
    sum_cpu = arrow_column_sum_cpu(batch)
    sum_fpga = arrow_column_sum_fpga(batch, args.platform_type)

    print("Expected sum: " + str(sum_cpu))
    print("FPGA sum: " + str(sum_fpga))

    if sum_fpga==sum_cpu:
        print("PASS")
        sys.exit(0)
    else:
        print("ERROR")
        sys.exit(1)