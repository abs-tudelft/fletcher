

import java.util.ArrayList;
import java.util.List;
import java.util.Random;

public class UniformDatasetGenerator extends DatasetGenerator {
	int range = 99;
	Random rng;
	
	UniformDatasetGenerator(long num_rows, int num_columns, Random rng) {
		this.num_rows = num_rows;
		this.num_columns = num_columns;
		this.rng = rng;
	}

	@Override
	protected void init() {	}
	
	@Override
	public List<Long> getRow() {
		List<Long> row = new ArrayList<Long>(num_columns);
		for (int d = 0; d < num_columns; d++) {
			row.add((long) (rng.nextInt(2 * range + 1) - range));
		}
		return row;
	}
}
