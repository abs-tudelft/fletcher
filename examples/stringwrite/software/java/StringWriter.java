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

import java.nio.BufferUnderflowException;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

public class StringWriter {
	ByteBuffer lengths;
	ByteBuffer values;
	ByteBuffer offsets;
	ByteBuffer avalues;
	List<String> strings;
	int total_length;

	List<String> values_old;

	public static void main(String[] args) {
		int num_str = 8*1024*1024;
		int min_len = 0;
		int len_msk = 255;
		
		if (args.length > 2) {
			num_str = Integer.parseInt(args[0]);
			min_len = Integer.parseInt(args[1]);
			len_msk = Integer.parseInt(args[2]);
		}
		else {
			System.err.println("Usage: stringwrite <num strings> <min str len> <prng mask>");
			System.exit(-1);
		}

		Timer t = new Timer();
		StringWriter sw = new StringWriter();
		
		System.err.println("Generating dataset");
		t.start();
		sw.genRandomLengths(num_str, min_len, len_msk);
		sw.genRandomValues();
		t.stop();
		System.out.println(t.seconds() + " gen");
		System.out.println(sw.total_length + " bytes");
		System.out.println(sw.lengths.limit() / 4 + " entries");
/*
		for (String val : sw.values) {
			System.out.println(val);
		}
*/
		t.start();
		sw.deserializeToArrow();
		t.stop();
		System.out.println(t.seconds() + " deser_to_arrow");
		
		t.start();
		sw.deserializeToString();
		t.stop();
		System.out.println(t.seconds() + " deser_to_native");
	}

	
	public ByteBuffer genRandomLengths(int amount, int min, int mask) {
		LFSRRandomizer lfsr = new LFSRRandomizer();
		lengths = ByteBuffer.allocateDirect(amount * 4);
		
		total_length = 0;
		for (int i = 0; i < amount; i++) {
			int len = min + (lfsr.next() & mask);
			total_length += len;
			lengths.putInt(len);
		}
		return lengths;
	}
	
	
	public ByteBuffer genRandomValues() {
		List<LFSRRandomizer> lfsrs = new ArrayList<LFSRRandomizer>(64);
		
		// initialize the lfsrs as in hardware
		for (int i = 0; i < 64; i++) {
			lfsrs.add(new LFSRRandomizer());
			lfsrs.get(i).lfsr = i;
		}
		
		values = ByteBuffer.allocateDirect(total_length);
		// For every string length
		try {
			while (true) {
				int len = lengths.getInt();
				int strpos = 0;
				// First generate a new "line" of random characters, even if it's zero length
				do {
					for (int c = 0; c < 64; c++) {
						int val = lfsrs.get(c).next() & 127;
						if (val < 32)
							val = '.';
						if (val == 127)
							val = '.';
						if (c < len)
							values.put((byte) val);
					}
					strpos += 64;
				} while (strpos < len);
			}
		} catch (BufferUnderflowException e) { }
		return values;
	}
	
	
	public void deserializeToArrow() {
		lengths.rewind();
		values.rewind();
		avalues = ByteBuffer.allocateDirect(values.remaining());
		offsets = ByteBuffer.allocateDirect(lengths.remaining() + 4);
		
		avalues.put(values);
		try {
			int offset = 0;
			offsets.putInt(offset);
			while (true) {
				int length = lengths.getInt();
				offset += length;
				offsets.putInt(offset);
			}
		} catch (BufferUnderflowException e) { }
	}
	
	
	public void deserializeToString() {
		lengths.rewind();
		values.rewind();
		strings = new ArrayList<String>(lengths.remaining() / 4);
		
		try {
			byte[] valueBuf = new byte[255];
			while (true) {
				int length = lengths.getInt();
				values.get(valueBuf, 0, length);
				String str = new String(valueBuf, 0, length, StandardCharsets.US_ASCII);
				strings.add(str);
			}
		} catch (BufferUnderflowException e) { }
	}
}
