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
import pyarrow as pa
import numpy as np
import copy
import sys
import argparse
import struct

import pyfletcher as pf
import kmeans

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


def numpy_kmeans_python(points, centroids, iteration_limit):
    num_centroids = len(centroids)
    dimensionality = len(centroids[0])
    num_rows = len(points)

    centroids_old = []
    iteration = 0

    while not np.array_equal(centroids_old, centroids) and iteration < iteration_limit:
        accumulators = [[0 for i in range(dimensionality)] for j in range(num_centroids)]
        counters = [0] * num_centroids

        for n in range(num_rows):
            # Determine closest centroid for point
            closest = 0
            min_distance = sys.maxsize
            for c in range(num_centroids):
                # Get distance to current centroid
                distance = 0
                for d in range(dimensionality):
                    dim_distance = points[n][d] - centroids[c][d]
                    distance += dim_distance * dim_distance

                if distance <= min_distance:
                    closest = c
                    min_distance = distance

            # Update counters of closest centroid
            counters[closest] += 1
            for d in range(dimensionality):
                accumulators[closest][d] += points[n][d]

        centroids_old = copy.deepcopy(centroids)
        # Calculate new centroids
        for c in range(num_centroids):
            for d in range(dimensionality):
                if accumulators[c][d] >= 0:
                    centroids[c][d] = accumulators[c][d] // counters[c]
                else:
                    centroids[c][d] = -(abs(accumulators[c][d]) // counters[c])

        iteration += 1

    return centroids

def arrow_kmeans_python(batch, centroids, iteration_limit):
    num_centroids = len(centroids)
    dimensionality = len(centroids[0])
    num_rows = batch.num_rows
    points = batch.column(0)

    centroids_old = []
    iteration = 0

    while not np.array_equal(centroids_old, centroids) and iteration < iteration_limit:
        accumulators = [[0 for i in range(dimensionality)] for j in range(num_centroids)]
        counters = [0] * num_centroids

        for n in range(num_rows):
            # Determine closest centroid for point
            closest = 0
            min_distance = sys.maxsize
            for c in range(num_centroids):
                # Get distance to current centroid
                distance = 0
                for d in range(dimensionality):
                    dim_distance = points[n][d].as_py() - centroids[c][d]
                    distance += dim_distance * dim_distance

                if distance <= min_distance:
                    closest = c
                    min_distance = distance

            # Update counters of closest centroid
            counters[closest] += 1
            for d in range(dimensionality):
                accumulators[closest][d] += points[n][d].as_py()

        centroids_old = copy.deepcopy(centroids)
        # Calculate new centroids
        for c in range(num_centroids):
            for d in range(dimensionality):
                if accumulators[c][d] >= 0:
                    centroids[c][d] = accumulators[c][d] // counters[c]
                else:
                    centroids[c][d] = -(abs(accumulators[c][d]) // counters[c])

        iteration += 1

    return centroids


def arrow_kmeans_fpga(batch, centroids, iteration_limit, max_hw_dim, max_hw_centroids, t_copy, t_fpga):
    t = Timer()

    platform = pf.Platform(platform_type)
    context = pf.Context(platform)
    uc = pf.UserCore(context)

    # Initialize the platform
    platform.init()

    # Reset the UserCore
    uc.reset()

    # Prepare the column buffers
    context.queue_record_batch(batch)
    t.start()
    context.enable()
    t.stop()
    t_copy.append(t.seconds())

    # Determine size of table
    last_index = batch.num_rows
    uc.set_range(0, last_index)

    # Set UserCore arguments
    args = []
    for centroid in centroids:
        for dim in centroid:
            lo = dim & 0xFFFFFFFF
            hi = (dim >> 32) & 0xFFFFFFFF
            args.append(lo)
            args.append(hi)

        for dim in range(max_hw_dim - len(centroid)):
            args.append(0)
            args.append(0)

    for centroid in range(max_hw_centroids - len(centroids)):
        for dim in range(max_hw_dim - 1):
            args.append(0)
            args.append(0)

        args.append(0x80000000)
        args.append(0)

    args.append(iteration_limit)
    uc.set_arguments(args)

    t.start()
    uc.start()
    uc.wait_for_finish(10)
    t.stop()
    t_fpga.append(t.seconds())

    num_centroids = len(centroids)
    dimensionality = len(centroids[0])
    regs_per_dim = 2
    regs_offset = 10

    for c in range(num_centroids):
        for d in range(dimensionality):
            reg_num = (c * max_hw_dim + d) * regs_per_dim + regs_offset
            centroids[c][d] = platform.read_mmio_64(reg_num, type="int")

    return centroids


def create_points(num_points, dim, element_max):
    """Create the points for use in k-means algorithm

    Args:
        num_points: Number of points
        dim: Dimension of k-means
        element_max: Max value of the coordinates of the points (-element_max is the min value)

    Returns:
        numpy array with the randomly generated points

    """
    np.random.seed(42)
    return np.random.randint(-element_max, element_max, size=(num_points, dim))


def create_record_batch_from_list(list_points):
    arpoints = pa.array(list_points, type=pa.list_(pa.int64()))

    field = pa.field("points", pa.list_(pa.field("coord", pa.int64(), False)), False)
    schema = pa.schema([field])

    return pa.RecordBatch.from_arrays([arpoints], schema)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--platform_type", dest="platform_type", default="echo", choices=["echo", "aws"],
                        help="Type of FPGA platform.")
    parser.add_argument("--num_rows", dest="num_rows", default=1024,
                        help="Number of points in coordinate system")
    parser.add_argument("--dim", dest="dimensionality", default=8,
                        help="Dimension of coordinate system")
    parser.add_argument("--iteration_limit", dest="iteration_limit", default=30,
                        help="Max number of k-means iterations")
    parser.add_argument("--num_centroids", dest="num_centroids", default=16,
                        help="Number of centroids")
    parser.add_argument("--num_exp", dest="num_exp", default=1,
                        help="Number of experiments")
    parser.add_argument("--max_hw_dim", dest="max_hw_dim", default=8,
                        help="Hardware property. Maximum dimension allowed for K-means.")
    parser.add_argument("--max_hw_centroids", dest="max_hw_centroids", default=16,
                        help="Hardware property. Maximum amount of centroids allowed for K-means.")
    args = parser.parse_args()

    num_rows = int(args.num_rows)
    platform_type = args.platform_type
    dimensionality = int(args.dimensionality)
    iteration_limit = int(args.iteration_limit)
    num_centroids = int(args.num_centroids)
    ne = int(args.num_exp)
    max_hw_dim = int(args.max_hw_dim)
    max_hw_centroids = int(args.max_hw_centroids)

    # Timers
    t = Timer(gc_disable=False)
    t_naser = []
    t_npser = []
    t_napy = []
    t_nppy = []
    t_arpy = []
    t_npcy = []
    t_arcpp = []
    t_arcpp_omp = []
    t_npcpp = []
    t_npcpp_omp = []
    t_fpga = []
    t_ftot = []
    t_copy = []

    # Results
    r_napy = []
    r_nppy = []
    r_arpy = []
    r_npcy = []
    r_arcpp = []
    r_arcpp_omp = []
    r_npcpp = []
    r_npcpp_omp = []
    r_fpga = []

    numpy_points = create_points(num_rows, dimensionality, 99)
    print(numpy_points.dtype)
    list_points = numpy_points.tolist()

    for i in range(ne):
        t.start()
        batch_points_from_list = create_record_batch_from_list(list_points)
        t.stop()
        t_naser.append(t.seconds())

        t.start()
        batch_points = kmeans.create_record_batch_from_numpy(numpy_points)
        t.stop()
        t_npser.append(t.seconds())

    print("Total serialization time for {ne} runs".format(ne=ne))
    print("Native to arrow serialization time: " + str(sum(t_naser)))
    print("Numpy to arrow serialization time: " + str(sum(t_npser)))
    print()
    print("Average serialization times:")
    print("Native to arrow serialization time: " + str(sum(t_naser)/ne))
    print("Numpy to arrow serialization time: " + str(sum(t_npser)/ne))

    # Determine starting centroids
    list_centroids = []
    for i in range(num_centroids):
        list_centroids.append(list_points[np.random.randint(0, len(list_points))])
    print(list_centroids)

    numpy_centroids = np.array(list_centroids)

    # Benchmarking
    for i in range(ne):
        print("Starting experiment {i}".format(i=i))
        # Native list k-means in pure Python
        numpy_centroids_copy = copy.deepcopy(numpy_centroids)
        t.start()
        #r_napy.append(numpy_kmeans_python(list_points, numpy_centroids_copy, iteration_limit))
        t.stop()
        t_napy.append(t.seconds())

        # Numpy k-means in pure Python
        numpy_centroids_copy = copy.deepcopy(numpy_centroids)
        t.start()
        #r_nppy.append(numpy_kmeans_python(numpy_points, numpy_centroids_copy, iteration_limit))
        t.stop()
        t_nppy.append(t.seconds())

        # Arrow k-means in pure Python (immensely slow)
        numpy_centroids_copy = copy.deepcopy(numpy_centroids)
        t.start()
        #r_arpy.append(arrow_kmeans_python(batch_points, numpy_centroids_copy, iteration_limit))
        t.stop()
        t_arpy.append(t.seconds())

        # Numpy k-means with the algorithm implemented in Cython
        numpy_centroids_copy = copy.deepcopy(numpy_centroids)
        t.start()
        #r_npcy.append(kmeans.np_kmeans_cython(numpy_points, numpy_centroids_copy, iteration_limit))
        t.stop()
        t_npcy.append(t.seconds())

        # Arrow k-means using Cython wrapped C++
        numpy_centroids_copy = copy.deepcopy(numpy_centroids)
        t.start()
        #r_arcpp.append(kmeans.arrow_kmeans_cpp(batch_points, numpy_centroids_copy, iteration_limit))
        t.stop()
        t_arcpp.append(t.seconds())

        # Numpy k-means using Cython wrapped C++
        numpy_centroids_copy = copy.deepcopy(numpy_centroids)
        t.start()
        #r_npcpp.append(kmeans.numpy_kmeans_cpp(numpy_points, numpy_centroids_copy, iteration_limit))
        t.stop()
        t_npcpp.append(t.seconds())

        print("Starting arcpp_omp")

        # Arrow k-means using Cython wrapped C++ (multi core)
        numpy_centroids_copy = copy.deepcopy(numpy_centroids)
        t.start()
        r_arcpp_omp.append(kmeans.arrow_kmeans_cpp_omp(batch_points, numpy_centroids_copy, iteration_limit))
        t.stop()
        t_arcpp_omp.append(t.seconds())

        print("Starting npcpp_omp")

        # Arrow k-means using Cython wrapped C+ (multi core)
        numpy_centroids_copy = copy.deepcopy(numpy_centroids)
        t.start()
        r_npcpp_omp.append(kmeans.numpy_kmeans_cpp_omp(numpy_points, numpy_centroids_copy, iteration_limit))
        t.stop()
        t_npcpp_omp.append(t.seconds())

        print("Starting fpga")

        # Arrow k-means on the FPGA
        numpy_centroids_copy = copy.deepcopy(numpy_centroids)
        t.start()
        r_fpga.append(arrow_kmeans_fpga(batch_points, numpy_centroids_copy, iteration_limit, max_hw_dim, max_hw_centroids, t_copy, t_fpga))
        t.stop()
        t_ftot.append(t.seconds())

        print("Total runtimes for " + str(ne) + " runs:")
        print("Kmeans native list pure Python execution time: " + str(sum(t_napy)))
        print("Kmeans NumPy pure Python execution time: " + str(sum(t_nppy)))
        print("Kmeans Arrow pure Python execution time: " + str(sum(t_arpy)))
        print("Kmeans NumPy Cython execution time: " + str(sum(t_npcy)))
        print("Kmeans Arrow Cython/CPP execution time: " + str(sum(t_arcpp)))
        print("Kmeans Numpy Cython/CPP execution time: " + str(sum(t_npcpp)))
        print("Kmeans Arrow Cython/CPP OMP execution time: " + str(sum(t_arcpp_omp)))
        print("Kmeans Numpy Cython/CPP OMP execution time: " + str(sum(t_npcpp_omp)))
        print("Kmeans Arrow FPGA copy time: " + str(sum(t_copy)))
        print("Kmeans Arrow FPGA algorithm time: " + str(sum(t_fpga)))
        print("Kmeans Arrow FPGA total time: " + str(sum(t_ftot)))
        print()
        print("Average runtimes:")
        print("Kmeans native list pure Python execution time: " + str(sum(t_napy)/(i+1)))
        print("Kmeans NumPy pure Python execution time: " + str(sum(t_nppy)/(i+1)))
        print("Kmeans Arrow pure Python execution time: " + str(sum(t_arpy)/(i+1)))
        print("Kmeans NumPy Cython execution time: " + str(sum(t_npcy)/(i+1)))
        print("Kmeans Arrow Cython/CPP execution time: " + str(sum(t_arcpp)/(i+1)))
        print("Kmeans Numpy Cython/CPP execution time: " + str(sum(t_npcpp)/(i+1)))
        print("Kmeans Arrow Cython/CPP OMP execution time: " + str(sum(t_arcpp_omp)/(i+1)))
        print("Kmeans Numpy Cython/CPP OMP execution time: " + str(sum(t_npcpp_omp)/(i+1)))
        print("Kmeans Arrow FPGA copy time: " + str(sum(t_copy)/(i+1)))
        print("Kmeans Arrow FPGA algorithm time: " + str(sum(t_fpga)/(i+1)))
        print("Kmeans Arrow FPGA total time: " + str(sum(t_ftot)/(i+1)))

    with open("Output.txt", "w") as text_file:
        text_file.write("Total runtimes for " + str(ne) + " runs:")
        text_file.write("\nKmeans native list pure Python execution time: " + str(sum(t_napy)))
        text_file.write("\nKmeans NumPy pure Python execution time: " + str(sum(t_nppy)))
        text_file.write("\nKmeans Arrow pure Python execution time: " + str(sum(t_arpy)))
        text_file.write("\nKmeans NumPy Cython execution time: " + str(sum(t_npcy)))
        text_file.write("\nKmeans Arrow Cython/CPP execution time: " + str(sum(t_arcpp)))
        text_file.write("\nKmeans Numpy Cython/CPP execution time: " + str(sum(t_npcpp)))
        text_file.write("\nKmeans Arrow Cython/CPP OMP execution time: " + str(sum(t_arcpp_omp)))
        text_file.write("\nKmeans Numpy Cython/CPP OMP execution time: " + str(sum(t_npcpp_omp)))
        text_file.write("\nKmeans Arrow FPGA copy time: " + str(sum(t_copy)))
        text_file.write("\nKmeans Arrow FPGA algorithm time: " + str(sum(t_fpga)))
        text_file.write("\nKmeans Arrow FPGA total time: " + str(sum(t_ftot)))
        text_file.write("\n")
        text_file.write("\nAverage runtimes:")
        text_file.write("\nKmeans native list pure Python execution time: " + str(sum(t_napy) / ne))
        text_file.write("\nKmeans NumPy pure Python execution time: " + str(sum(t_nppy) / ne))
        text_file.write("\nKmeans Arrow pure Python execution time: " + str(sum(t_arpy) / ne))
        text_file.write("\nKmeans NumPy Cython execution time: " + str(sum(t_npcy) / ne))
        text_file.write("\nKmeans Arrow Cython/CPP execution time: " + str(sum(t_arcpp) / ne))
        text_file.write("\nKmeans Numpy Cython/CPP execution time: " + str(sum(t_npcpp) / ne))
        text_file.write("\nKmeans Arrow Cython/CPP OMP execution time: " + str(sum(t_arcpp_omp) / ne))
        text_file.write("\nKmeans Numpy Cython/CPP OMP execution time: " + str(sum(t_npcpp_omp) / ne))
        text_file.write("\nKmeans Arrow FPGA copy time: " + str(sum(t_copy) / ne))
        text_file.write("\nKmeans Arrow FPGA algorithm time: " + str(sum(t_fpga) / ne))
        text_file.write("\nKmeans Arrow FPGA total time: " + str(sum(t_ftot) / ne))

    # Print results (partially)
    # print(r_nppy[0])
    # print(r_npcy[0])
    # print(r_arcpp[0])
    # print(r_arcpp_omp[0])
    # print(r_npcpp[0])
    # print(r_fpga[0])

    # Todo: Temporary shortcut
    r_nppy = r_arcpp_omp
    r_arpy = r_arcpp_omp
    r_napy = r_arcpp_omp
    r_arcpp = r_arcpp_omp
    r_npcpp = r_arcpp_omp
    r_npcy = r_arcpp_omp

    # Check correctness of results
    if np.array_equal(r_nppy, r_npcy) \
            and np.array_equal(r_npcy, r_arcpp) \
            and np.array_equal(r_arcpp, r_npcpp) \
            and np.array_equal(r_npcpp, r_arcpp_omp) \
            and np.array_equal(r_arcpp_omp, r_npcpp_omp) \
            and np.array_equal(r_npcpp_omp, r_arpy) \
            and np.array_equal(r_arpy, r_napy) \
            and np.array_equal(r_napy, r_fpga):
        print("PASS")
    else:
        print("ERROR")
