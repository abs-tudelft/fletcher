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

import java.io.File;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.charset.Charset;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.*;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class Rem {

    private static final Charset UTF8_CHARSET = Charset.forName("UTF-8");

    private static void genRandStringsWith(Vector<String> strings, String with, String alphabet, int num_strings, int max_str_len) {
        Random rnd = new Random();

        for (int i = 0; i < num_strings; i++) {
            StringBuilder b = new StringBuilder(max_str_len);

            int strlen = with.length() + rnd.nextInt(max_str_len - with.length());

            for (int j = 0; j < strlen; ) {
                if ((rnd.nextInt(max_str_len) == 0) && (j + with.length() < max_str_len)) {
                    b.append(with);
                    j += with.length();
                } else {
                    b.append(alphabet.charAt(rnd.nextInt(alphabet.length())));
                    j++;
                }
            }

            strings.add(i, b.toString());
        }
    }

    private static ByteBuffer getOffsetBuffer(String[] strings) {
        ByteBuffer b = ByteBuffer.allocateDirect(4 * (strings.length + 1));

        int offset = 0;

        // First offset
        b.putInt(offset);

        // Other offsets
        for (int i = 0; i < strings.length; i++) {
            offset = offset + strings[i].length();
            b.putInt(offset);
        }

        return b;
    }

    private static ByteBuffer getDataBuffer(String[] strings, int size) {
        ByteBuffer b = ByteBuffer.allocateDirect(size);

        for (int i = 0; i < strings.length; i++) {
            byte[] utf8 = strings[i].getBytes(UTF8_CHARSET);
            b.put(utf8);
        }

        return b;
    }

    private static void printContents(ByteBuffer ob, ByteBuffer db) {
        int rows = (ob.capacity() / 4) - 1;

        db.position(0);

        for (int i = 0; i < rows; i++) {
            int offset = ob.getInt(i * 4);
            int strlen = ob.getInt((i + 1) * 4) - offset;

            System.out.print(i + ", " + offset + ", " + strlen + ", ");

            byte[] utf8 = new byte[strlen];
            db.get(utf8, 0, strlen);

            String str = new String(utf8, UTF8_CHARSET);
            System.out.print(str + "\n");
        }
    }

    private static long addMatches(final String[] strings, final List<String> regexes, int[] matches) {
        final int np = regexes.size();
        Matcher[] matchers = new Matcher[np];

        for (int p = 0; p < np; p++) {
            matchers[p] = Pattern.compile(regexes.get(p)).matcher("");
        }

        long start = System.nanoTime();
        for (int i = 0; i < strings.length; i++) {
            for (int p = 0; p < np; p++) {
                if (matchers[p].reset(strings[i]).matches()) {
                    matches[p]++;
                }
            }
        }
        long stop = System.nanoTime();
        return stop - start;
    }

    private static long addMatchesParallel(final String[] strings, final List<String> regexes, int[] matches, final int num_threads) {

        int nt = num_threads;
        int np = regexes.size();

        long tstart = System.nanoTime();

        // Create executor service
        ExecutorService executor = Executors.newFixedThreadPool(num_threads);

        List<int[]> thread_matches = new ArrayList<>();

        // Make list for future results
        List<Future<Boolean>> ready = new ArrayList<Future<Boolean>>();

        // Spawn the threads
        for (int t = 0; t < nt; t++) {
            // Make the result array
            thread_matches.add(new int[np]);
            int start = t * (strings.length / num_threads);
            int stop = (t + 1) * (strings.length / num_threads);
            Future<Boolean> future_result = executor.submit(new RemThread(strings, regexes, thread_matches.get(t), start, stop));
            ready.add(future_result);
        }

        boolean all_done = true;

        for (Future<Boolean> done : ready) {
            try {
                all_done = all_done & done.get();
            } catch (InterruptedException | ExecutionException e) {
                e.printStackTrace();
            }
        }

        // Aggregate the results for each thread

        for (int t = 0; t < nt; t++) {
            for (int p = 0; p < np; p++) {
                matches[p] += thread_matches.get(t)[p];
            }
        }

        executor.shutdown();

        long tstop = System.nanoTime();

        return tstop - tstart;
    }

    public static void main(String[] args) {
        long start, end;

        int num_strings = 256;
        int max_str_len = 256;
        int threads = Runtime.getRuntime().availableProcessors();
        int repeats = 1;

        long t_cpu = 0;
        long t_par = 0;
        long t_ser = 0;

        final List<String> regexes = Arrays.asList(
                ".*(?i)bird.*",
                ".*(?i)bunny.*",
                ".*(?i)cat.*",
                ".*(?i)dog.*",
                ".*(?i)ferret.*",
                ".*(?i)fish.*",
                ".*(?i)gerbil.*",
                ".*(?i)hamster.*",
                ".*(?i)horse.*",
                ".*(?i)kitten.*",
                ".*(?i)lizard.*",
                ".*(?i)mouse.*",
                ".*(?i)puppy.*",
                ".*(?i)rabbit.*",
                ".*(?i)rat.*",
                ".*(?i)turtle.*"
        );

        if (args.length >= 1) {
            num_strings = Integer.parseInt(args[0]);
        }
        if (args.length >= 2) {
            repeats = Integer.parseInt(args[1]);
        }

        String[] strings = null;

        if (args.length >= 3) {
            Path filePath = new File(args[2]).toPath();
            try {
                List<String> stringList = Files.readAllLines(filePath, UTF8_CHARSET);
                strings = new String[stringList.size()];
                stringList.toArray(strings);

            } catch (IOException e) {
                e.printStackTrace();
                return;
            }
        }

        int np = regexes.size();

        int[] m_cpu = new int[np];
        int[] m_par = new int[np];

        for (int i = 0; i < repeats; i++) {
            t_cpu += addMatches(strings, regexes, m_cpu);
            t_par += addMatchesParallel(strings, regexes, m_par, threads);

            start = System.nanoTime();
            ByteBuffer ob = getOffsetBuffer(strings);
            int data_buf_size = ob.getInt(4 * num_strings); // The size of the data buffer is the last offset in the offset buffer
            ByteBuffer db = getDataBuffer(strings, data_buf_size);
            end = System.nanoTime();
            t_ser += (end - start);
        }

        System.out.print(num_strings + ", " + t_cpu + ", " + t_par + ", " + t_ser + ", " + threads);

        for (int p = 0; p < np; p++) {
            System.out.print("   ," + m_cpu[p] + "," + m_par[p]);
        }

        System.out.print("\n");
    }
}
