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

import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.List;
import java.util.Random;

public class ClusteredDatasetGenerator extends DatasetGenerator {
	int num_centers = 16;
	double noise = 0.5;
	double spread = 0.2;
	long max_abs;
	long scale;
	Random rng;
	List<List<Long>> centers;
	private int target_space;

	
	public static void main(String[] args) throws IOException {

		ClusteredDatasetGenerator generator = new ClusteredDatasetGenerator(8, 16, 1024*1024*1024/((64/8)*8+4));
		
		OutputStream target = new FileOutputStream("k-means-64-16-8-1Glist.csv");
		generator.getCSV(target);
		

		for (List<Long> center : generator.centers) {
			System.out.println(center);
		}
	}

	
	public ClusteredDatasetGenerator(int num_columns, int num_centers, long num_rows) {
		this.num_columns = num_columns;
		this.num_centers = num_centers;
		this.num_rows = num_rows;
		
		rng = new Random();
		rng.setSeed(3141592653589793238L);
		
		init();
	}
	
	public ClusteredDatasetGenerator(int num_columns, int num_centers, long num_rows, Random rng) {
		this.num_columns = num_columns;
		this.num_centers = num_centers;
		this.num_rows = num_rows;
		
		init();
	}
	
	protected void init() {
		// Prevent overflow in Int64 during k-means
		long max_dist = (long) (Math.sqrt(Long.MAX_VALUE) / num_columns / 2);
		long max_sum = Long.MAX_VALUE / num_rows;
		max_abs = Math.min(max_dist, max_sum);
		
		// Place centers in subsection of allowed space
		target_space = (int) (max_abs / 100);
		centers = new ArrayList<List<Long>>();
		for (int c = 0; c < num_centers; c++) {
			centers.add(getCenter());
		}
		
		// Set spread of generated points
		scale = (long) (target_space * spread);
	}
	
	
	private long getDim() {
		double num = rng.nextGaussian();
		num = num * scale;
		return (long) num;
	}
	
	
	private List<Long> getCenter() {
		List<Long> center = new ArrayList<Long>();
		for (int d = 0; d < num_columns; d++) {
			long dim = rng.nextInt(target_space * 2) - target_space;
			center.add(dim);
		}
		return center;
	}
	
	
	private List<Long> getPoint() {
		List<Long> point = new ArrayList<Long>();
		for (int d = 0; d < num_columns; d++) {
			point.add(getDim());
		}
		return point;
	}
	
	
	private List<Long> getPointShifted(List<Long> center) {
		List<Long> point = getPoint();
		for (int d = 0; d < num_columns; d++) {
			point.set(d, point.get(d) + center.get(d));
		}
		return point;
	}
	
	
	public List<Long> getRow() {
		if (rng.nextInt(Integer.MAX_VALUE) < noise * Integer.MAX_VALUE) {
			return getPointShifted(getCenter());
		} else {
			int center_idx = rng.nextInt(num_centers);
			return getPointShifted(centers.get(center_idx));
		}
	}
}
