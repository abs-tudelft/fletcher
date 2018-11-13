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
import kmeans
import copy
import sys

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

    centroids_old = copy.deepcopy(centroids)
    centroids_old = []
    iteration = 0

    while(centroids_old != centroids and iteration < iteration_limit):
        centroid_accumulator = [0] * dimensionality
        accumulators = [[0] * dimensionality] * num_centroids
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

                if(distance<min_distance)
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
                centroids[c][d] = accumulators[c][d] // counters[c]



t = Timer()

arpoints = pa.array([[9, 10],
                   [13, 14],
                   [15, 16],
                   [2, 2],
                   [4, 4]],
                  type=pa.list_(pa.int64()))

field = pa.field("points", pa.list_(pa.field("coord", pa.int64(), False)), False)
schema = pa.schema([field])

batch = pa.RecordBatch.from_arrays([arpoints], schema)

centroids = [[2, 2],
             [10, 10]]

npcentroids = np.array(centroids)

t.start()
result = kmeans.arrow_kmeans_cpp(batch, npcentroids, 10)
t.stop()
print(t.seconds())

nppoints = np.array([[9, 10],
                   [13, 14],
                   [15, 16],
                   [2, 2],
                   [4, 4]])

kmeans_python(nppoints, centroids, 10)