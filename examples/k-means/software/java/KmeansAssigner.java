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

import java.util.List;
import java.util.concurrent.Callable;

public class KmeansAssigner implements Callable<KmeansPartialResult> {
	private Kmeans kmeans;
	private List<List<Long>> centroids;
	private List<List<Long>> data;

	KmeansAssigner(Kmeans kmeans, List<List<Long>> centroids, List<List<Long>> data) {
		this.kmeans = kmeans;
		this.centroids = centroids;
		this.data = data;
	}
	
	@Override
	public KmeansPartialResult call() throws Exception {
		long[] counters = new long[kmeans.num_centroids];
		long[][] accumulators = new long[kmeans.num_centroids][kmeans.num_columns];
		
		// For each point
		for (List<Long> row : data) {
			// Determine closest centroid for point
			int closest = 0;
			long min_distance = Long.MAX_VALUE;
			for (int c = 0; c < kmeans.num_centroids; c++) {
				List<Long> centroid = centroids.get(c);
				long distance = 0;
				for (int d = 0; d < kmeans.num_columns; d++) {
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
			for (int d = 0; d < kmeans.num_columns; d++) {
				accumulators[closest][d] += row.get(d);
			}
		}

		KmeansPartialResult result = new KmeansPartialResult();
		result.counters = counters;
		result.accumulators = accumulators;
		return result;
	}

}
