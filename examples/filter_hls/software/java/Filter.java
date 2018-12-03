import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.BufferUnderflowException;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Random;

public class Filter {

	public static void main(String[] args) throws IOException {
		String special_last_name = "Smith";
		int special_zip_code = 1337;
		int min_str_len = 3;
		int max_str_len = 40;
		int num_rows = 1024*1024*8;
		int zip_period = 32;
		int ln_period = 32;
		
		Timer t = new Timer();
		
		// Generate native data
		System.err.println("Generating dataset");
		List<Person> persons;
		t.start();
		if (args.length > 0 && args[0].equals("-")) {
			persons = new ArrayList<Person>(num_rows);
			BufferedReader input = new BufferedReader(new InputStreamReader(System.in));
			String line = input.readLine();
			while (line != null) {
				String[] fields = line.split(",");
				persons.add(new Person(fields[0], fields[1], Integer.parseInt(fields[2])));
				line = input.readLine();
			}
		} else {
			Random rng = new Random();
			persons = new ArrayList<Person>(num_rows);
			for (int n = 0; n < num_rows; n++) {
				persons.add(Person.generateRandomPerson(rng, min_str_len, max_str_len, ln_period, zip_period, special_last_name, special_zip_code));
			}
		}
		t.stop();
		System.out.println(t.seconds() + " generate");
		
		// Serialize to Arrow
		t.start();
		List<ByteBuffer> arrow = serializeToArrow(persons);
		t.stop();
		System.out.println(t.seconds() + " serialize to Arrow");
		int num_bytes = 0;
		for (ByteBuffer buf : arrow) {
			num_bytes += buf.limit();
		}
		System.out.println(num_bytes + " bytes in Arrow buffers");
		
		// Filter native data
		t.start();
		List<String> filteredNative = filterNative(persons, special_last_name, special_zip_code);
		t.stop();
		System.out.println(t.seconds() + " native filtering");
		System.out.println(filteredNative.size() + " strings from native after filter");
//		for (String s : filteredNative) {
//			System.err.println(s);
//		}
		
		// Filter Arrow data
		t.start();
		List<ByteBuffer> filteredArrow = filterArrow(arrow, special_last_name, special_zip_code);
		t.stop();
		System.out.println(t.seconds() + " Arrow filtering");
		num_bytes = 0;
		for (ByteBuffer buf : filteredArrow) {
			num_bytes += buf.limit();
		}
		System.out.println(num_bytes + " bytes in " + (filteredArrow.get(0).limit() / 4  - 1) + " strings from Arrow after filter");
//		byte[] data = new byte[filteredArrow.get(1).limit()];
//		filteredArrow.get(1).get(data);
//		System.err.println(new String(data, 0, filteredArrow.get(1).limit(), StandardCharsets.US_ASCII));
	}

	private static List<ByteBuffer> serializeToArrow(List<Person> persons) {
		ByteBuffer zipBuf = ByteBuffer.allocateDirect(persons.size() * 4);
		ByteBuffer firstNameOffsets = ByteBuffer.allocateDirect(persons.size() * 4 + 4);
		ByteBuffer lastNameOffsets = ByteBuffer.allocateDirect(persons.size() * 4 + 4);
		int first_name_offset = 0;
		int last_name_offset = 0;
		firstNameOffsets.putInt(first_name_offset);
		lastNameOffsets.putInt(last_name_offset);
		for (Person p : persons) {
			zipBuf.putInt(p.zip_code);
			first_name_offset += p.first_name.length();
			last_name_offset += p.last_name.length();
			firstNameOffsets.putInt(first_name_offset);
			lastNameOffsets.putInt(last_name_offset);
		}
		
		ByteBuffer firstNameBuf = ByteBuffer.allocateDirect(first_name_offset);
		ByteBuffer lastNameBuf = ByteBuffer.allocateDirect(last_name_offset);
		for (Person p : persons) {
			firstNameBuf.put(p.first_name.getBytes(StandardCharsets.US_ASCII));
			lastNameBuf.put(p.last_name.getBytes(StandardCharsets.US_ASCII));
		}
		
		List<ByteBuffer> arrow = new ArrayList<ByteBuffer>();
		arrow.add(firstNameOffsets);
		arrow.add(firstNameBuf);
		arrow.add(lastNameOffsets);
		arrow.add(lastNameBuf);
		arrow.add(zipBuf);
		for (ByteBuffer buf : arrow) {
			buf.flip();
		}
		return arrow;
	}

	private static List<String> filterNative(List<Person> persons, String special_last_name,
			int special_zip_code) {
		List<String> filtered = new ArrayList<String>(persons.size());
		for (Person p : persons) {
			if (p.zip_code == special_zip_code && special_last_name.equals(p.last_name)) {
				filtered.add(p.first_name);
			}
		}
		return filtered;
	}
	
	private static List<ByteBuffer> filterArrow(List<ByteBuffer> arrow, String special_last_name,
			int special_zip_code) {
		ByteBuffer firstNameOffsets = arrow.get(0).asReadOnlyBuffer();
		ByteBuffer firstNameBuf = arrow.get(1).asReadOnlyBuffer();
		ByteBuffer lastNameOffsets = arrow.get(2).asReadOnlyBuffer();
		ByteBuffer lastNameBuf = arrow.get(3).asReadOnlyBuffer();
		ByteBuffer zipBuf = arrow.get(4).asReadOnlyBuffer();

		ByteBuffer filteredNameOffsets = ByteBuffer.allocateDirect(lastNameOffsets.limit());
		ByteBuffer filteredNameBuf = ByteBuffer.allocateDirect(arrow.get(1).limit());
		ByteBuffer specialLastNameBuf = ByteBuffer.allocateDirect(special_last_name.length());
		specialLastNameBuf.put(special_last_name.getBytes(StandardCharsets.US_ASCII));
		specialLastNameBuf.flip();

		int write_offset = 0;
		try {
			int row_num = 0;
			while (true) {
				int zip_code = zipBuf.getInt();
				// Match ZIP code
				if (zip_code == special_zip_code) {
					// Get offsets for last name
					int start_offset = lastNameOffsets.getInt(row_num * 4);
					int end_offset = lastNameOffsets.getInt(row_num * 4 + 4);
					lastNameBuf.limit(end_offset);
					lastNameBuf.position(start_offset);
					// Compare last name with special name
					if (lastNameBuf.compareTo(specialLastNameBuf) == 0) {
						// Add first name to filtered output
						int length = end_offset - start_offset;
						filteredNameOffsets.putInt(write_offset);
						write_offset += length;
						
						start_offset = firstNameOffsets.getInt(row_num * 4);
						end_offset = firstNameOffsets.getInt(row_num * 4 + 4);
						firstNameBuf.limit(end_offset);
						firstNameBuf.position(start_offset);
						filteredNameBuf.put(firstNameBuf);
					}
					specialLastNameBuf.rewind();
				}
				row_num++;
			}
		} catch (BufferUnderflowException e) {
			// Normal termination
		} finally {
			filteredNameOffsets.putInt(write_offset);
		}
		
		filteredNameOffsets.flip();
		filteredNameBuf.flip();
		List<ByteBuffer> filtered = new ArrayList<ByteBuffer>();
		filtered.add(filteredNameOffsets);
		filtered.add(filteredNameBuf);
		return filtered;
	}
}
