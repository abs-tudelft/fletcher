// Copyright 2018 Delft University of Technology
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package nl.tudelft.ewi.ce.abs.kmeans;

import java.util.ArrayList;
import java.util.List;
import java.util.Random;

public class Kmeans {
	int num_columns = 8;
	int num_centroids = 16;
	int iteration_limit = 10;

	
	public static void main(String[] args) {
		Kmeans kmeans = new Kmeans();
		
		Random rng = new Random();
		List<List<Long>> data = kmeans.createData(rng, 1000);
		
		List<List<Long>> start_centroids = kmeans.getStartingCentroids(data);
		
		List<List<Long>> result_vcpu = kmeans.kmeansCPU(data, start_centroids);
		System.out.println("vCPU clusters: ");
		for (List<Long> centroid : result_vcpu) {
			System.out.println(centroid);
		}
	}

	
	private List<List<Long>> getStartingCentroids(List<List<Long>> data) {
		List<List<Long>> centroids = new ArrayList<List<Long>>(num_centroids);
		for (int c = 0; c < num_centroids; c++) {
			centroids.add(data.get(c));
		}
		return centroidsCopy(centroids);
	}
	
	
	private List<List<Long>> createData(Random rng, int num_rows) {
		List<List<Long>> data = new ArrayList<List<Long>>(num_rows);
		for (int n = 0; n < num_rows; n++) {
			List<Long> row = new ArrayList<Long>(num_columns);
			for (int d = 0; d < num_columns; d++) {
				row.add((long) (rng.nextInt(199)-99)); // range: [-99,99]
			}
			data.add(row);
		}
		return data;
	}
	
	
	private List<List<Long>> centroidsCopy(List<List<Long>> centroids) {
		List<List<Long>> new_centroids = new ArrayList<List<Long>>(num_centroids);
		for (List<Long> row : centroids) {
			new_centroids.add(new ArrayList<Long>(row));
		}
		return new_centroids;
	}
	
	
	private List<List<Long>> kmeansCPU(List<List<Long>> data, List<List<Long>> centroids) {
		long[] counters = new long[num_centroids];
		long[][] accumulators = new long[num_centroids][num_columns];
		
		List<List<Long>> old_centroids;
		List<List<Long>> new_centroids = centroidsCopy(centroids);
		int iteration = 0;
		do {
			old_centroids = centroidsCopy(new_centroids);

			// For each point
			for (List<Long> row : data) {
				// Determine closest centroid for point
				int closest = 0;
				long min_distance = Long.MAX_VALUE;
				for (int c = 0; c < num_centroids; c++) {
					List<Long> centroid = old_centroids.get(c);
					long distance = 0;
					for (int d = 0; d < num_columns; d++) {
						long dim_distance = row.get(d) - centroid.get(d);
						distance += dim_distance * dim_distance;
					}
					if (distance <= min_distance) {
						closest = c;
						min_distance = distance;
					}
				}
				// Update counters of closest centroid
				counters[closest]++;
				for (int d = 0; d < num_columns; d++) {
					accumulators[closest][d] += row.get(d);
				}
			}
			
			// Calculate new centroid positions
			for (int c = 0; c < num_centroids; c++) {
				List<Long> centroid = new_centroids.get(c);
				for (int d = 0; d < num_columns; d++) {
					centroid.set(d, accumulators[c][d] / counters[c]);
					accumulators[c][d] = 0;
				}
				counters[c] = 0;
			}

			iteration++;
		} while (!old_centroids.equals(new_centroids) && iteration < iteration_limit);

		return new_centroids;
	}
}
