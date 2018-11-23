

import java.io.BufferedWriter;
import java.io.IOException;
import java.io.OutputStream;
import java.io.OutputStreamWriter;
import java.util.ArrayList;
import java.util.List;

public abstract class DatasetGenerator {
	long num_rows;
	int num_columns;
	
	protected abstract void init();
	
	public abstract List<Long> getRow();
	
	public List<List<Long>> getDataset() {
		List<List<Long>> data = new ArrayList<List<Long>>((int) num_rows);
		for (int n = 0; n < num_rows; n++) {
			if (n % 1000000 == 0) {
				System.err.println("Generating: " + (n*100/num_rows) + "%");
			}
			data.add(getRow());
		}
		return data;
	}
	
	public void getCSV(OutputStream stream) throws IOException {
		BufferedWriter out = new BufferedWriter(new OutputStreamWriter(stream));
		for (long n = 0; n < num_rows; n++) {
			List<Long> row = getRow();
			for (int d = 0; d < num_columns - 1; d++) {
				out.write(row.get(d).toString());
				out.write(",");
			}
			out.write(row.get(num_columns - 1).toString());
			out.newLine();
		}
		out.flush();
	}
}
