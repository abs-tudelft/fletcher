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
import java.util.regex.Matcher;
import java.util.regex.Pattern;

// import com.google.re2j.Matcher;
// import com.google.re2j.Pattern;

public class RemThread implements Callable<Boolean> {

    private final String[] strings;
    private final int start;
    private final int stop;
    private int[] matches;
    private final Matcher[] matchers;

    public RemThread(final String[] strings, final List<String> regexes, int[] matches, final int start, final int stop) {
        this.strings = strings;
        this.start = start;
        this.stop = stop;
        this.matches = matches;
        final int np = regexes.size();
        this.matchers = new Matcher[np];

        for (int p = 0; p < np; p++) {
            matchers[p] = Pattern.compile(regexes.get(p)).matcher("");
        }
    }

    public Boolean call() {
        int np = matches.length;
        for (int i = start; i < stop; i++) {
            for (int p = 0; p < np; p++) {
                if (matchers[p].reset(strings[i]).matches()) {
                    matches[p]++;
                }
            }
        }

        return true;
    }
}
