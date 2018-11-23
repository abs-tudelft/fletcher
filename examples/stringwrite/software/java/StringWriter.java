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
	List<Integer> lengths;
	List<String> values;
	int total_length;

	List<String> values_old;

	public static void main(String[] args) {
		int num_str = 8454660;
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
/*
		for (String val : sw.values) {
			System.out.println(val);
		}
*/
		t.start();
		List<ByteBuffer> arrow = sw.deserializeToArrow();
		t.stop();
		System.out.println(t.seconds() + " deser_to_arrow");
		
		t.start();
		sw.serializeFromArrow(arrow.get(0), arrow.get(1));
		t.stop();
		System.out.println(t.seconds() + " ser_from_arrow");
		
		if (sw.values.equals(sw.values_old)) {
			System.out.println("PASS");
			System.exit(0);
		} else {
			System.out.println("ERROR");
			System.exit(1);
		}
	}

	
	public List<Integer> genRandomLengths(int amount, int min, int mask) {
		LFSRRandomizer lfsr = new LFSRRandomizer();
		lengths = new ArrayList<Integer>(amount);
		
		total_length = 0;
		for (int i = 0; i < amount; i++) {
			int len = min + (lfsr.next() & mask);
			total_length += len;
			lengths.add(len);
		}
		return lengths;
	}
	
	
	public List<String> genRandomValues() {
		List<LFSRRandomizer> lfsrs = new ArrayList<LFSRRandomizer>(64);
		
		// initialize the lfsrs as in hardware
		for (int i = 0; i < 64; i++) {
			lfsrs.add(new LFSRRandomizer());
			lfsrs.get(i).lfsr = i;
		}
		
		values = new ArrayList<String>(lengths.size());
		StringBuilder buffer = new StringBuilder(255);
		// For every string length
		for (int len : lengths) {
			int strpos = 0;
			// First generate a new "line" of random characters, even if it's zero length
			do {
				buffer.setLength(0);
				for (int c = 0; c < 64; c++) {
					int val = lfsrs.get(c).next() & 127;
					if (val < 32)
						val = '.';
					if (val == 127)
						val = '.';
					if (c < len)
						buffer.append((char) val);
				}
				strpos += 64;
			} while (strpos < len);
			buffer.setLength(len);
			values.add(buffer.toString());
		}
		return values;
	}
	
	
	public List<ByteBuffer> deserializeToArrow() {
		ByteBuffer valuesBuf = ByteBuffer.allocateDirect(total_length);
		ByteBuffer offsetsBuf = ByteBuffer.allocateDirect((values.size() + 1) * 4);
		
		int offset = 0;
		for (String str : values) {
			offsetsBuf.putInt(offset);
			valuesBuf.put(str.getBytes(StandardCharsets.US_ASCII));
			offset += str.length();
		}
		offsetsBuf.putInt(offset);
		offsetsBuf.rewind();
		valuesBuf.rewind();
		
		List<ByteBuffer> arrow = new ArrayList<ByteBuffer>();
		arrow.add(offsetsBuf);
		arrow.add(valuesBuf);
		return arrow;
	}
	
	
	public void serializeFromArrow(ByteBuffer offsetsBuf, ByteBuffer valuesBuf) {
		values_old = values;
		
		values = new ArrayList<String>(offsetsBuf.remaining() / 4 - 1);
		
		try {
			byte[] valueBuf = new byte[255];
			int offset = offsetsBuf.getInt();
			while (true) {
				int nextOffset = offsetsBuf.getInt();
				int length = nextOffset - offset;
				valuesBuf.get(valueBuf, 0, length);
				String str = new String(valueBuf, 0, length, StandardCharsets.US_ASCII);
				values.add(str);
				offset = nextOffset;
			}
		} catch (BufferUnderflowException e) { }
	}
}
