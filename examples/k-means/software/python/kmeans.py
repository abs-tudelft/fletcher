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


def kmeans_python(points, centroids, iteration_limit):
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

                if distance < min_distance:
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


def create_points(num_points, dim, element_max):
    np.random.seed(42)
    return np.random.randint(-element_max, element_max, size=(num_points, dim))

def create_record_batch(nparray):
    """Create a recordbatch from a 2D numpy array.

    Unfortunately, pyarrow can't cast the Numpy array because it is 2 dimensional. Therefore, it first has to be
    transformed into a Python list. It is possible to make a more efficient version with some C magic.

    Args:
        nparray: 2 dimensional numpy array

    Returns:
        Arrow RecordBatch with type <list<int64>>

    """
    arpoints = pa.array(nparray.tolist(), type=pa.list_(pa.int64()))

    field = pa.field("points", pa.list_(pa.field("coord", pa.int64(), False)), False)
    schema = pa.schema([field])

    return pa.RecordBatch.from_arrays([arpoints], schema)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--platform_type", dest="platform_type", default="echo", choices=["echo", "aws"],
                        help="Type of FPGA platform.")
    parser.add_argument("--num_rows", dest="num_rows", default=1024,
                        help="Number of points in coordinate system")
    parser.add_argument("--dim", dest="dimensionality", default=2,
                        help="Dimension of coordinate system")
    parser.add_argument("--iteration_limit", dest="iteration_limit", default=30,
                        help="Max number of k-means iterations")
    parser.add_argument("--num_centroids", dest="num_centroids", default=2,
                        help="Number of centroids")
    args = parser.parse_args()

    num_rows = int(args.num_rows)
    platform_type = args.platform_type
    dimensionality = int(args.dimensionality)
    iteration_limit = int(args.iteration_limit)
    num_centroids = int(args.num_centroids)

    t = Timer()

    numpy_points = create_points(num_rows, dimensionality, 99)
    list_points = numpy_points.tolist()

    t.start()
    batch_points = create_record_batch(numpy_points)
    t.stop()
    print("Numpy to arrow serialization time: " + str(t.seconds()))

    list_centroids = []

    for i in range(num_centroids):
        list_centroids.append(list_points[np.random.randint(0, len(list_points))])
    print(list_centroids)

    numpy_centroids = np.array(list_centroids)

    numpy_centroids_copy = copy.deepcopy(numpy_centroids)
    t.start()
    result = kmeans_python(numpy_points, numpy_centroids_copy, iteration_limit)
    t.stop()
    print("Kmeans NumPy pure Python execution time: " + str(t.seconds()))

    print(result)

    list_centroids_copy = copy.deepcopy(list_centroids)
    t.start()
    result = kmeans.list_kmeans_cython(list_points, list_centroids_copy, iteration_limit)
    t.stop()
    print("Kmeans list Cython execution time: " + str(t.seconds()))

    print(result)

    numpy_centroids_copy = copy.deepcopy(numpy_centroids)
    t.start()
    result = kmeans.np_kmeans_cython(numpy_points, numpy_centroids_copy, iteration_limit)
    t.stop()
    print("Kmeans NumPy Cython execution time: " + str(t.seconds()))

    print(result)

    numpy_centroids_copy = copy.deepcopy(numpy_centroids)
    t.start()
    result = kmeans.arrow_kmeans_cpp(batch_points, numpy_centroids_copy, iteration_limit)
    t.stop()
    print("Kmeans Arrow Cython/CPP execution time: " + str(t.seconds()))

    print(numpy_centroids_copy)
