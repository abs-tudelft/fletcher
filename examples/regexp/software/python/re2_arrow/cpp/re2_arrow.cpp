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

#include <cstdint>
#include <memory>
#include <iostream>
#include <vector>
#include <string>
#include <numeric>
#include <omp.h>

// RE2 regular expressions library
#include <re2/re2.h>

// Apache Arrow
#include <arrow/api.h>

#include "re2_arrow.h"

using std::vector;
using std::string;
using std::shared_ptr;

void clear_programs(vector<re2::RE2 *> &programs) {
  for (auto p : programs) {
    delete p;
  }
}

vector<re2::RE2 *> compile_regexes(const vector<string> &regexes) {
  // Allocate a vector for the programs
  vector<re2::RE2 *> programs;

  // Compile the regexes
  for (const auto &regexe : regexes) {
    re2::RE2 *re = new re2::RE2(regexe);
    programs.push_back(re);
  }

  return programs;
}

/**
 * Match regular expression using Arrow table as a source
 */
void add_matches_arrow(const shared_ptr<arrow::Array> &array,
                       const vector<string> &regexes,
                       uint32_t* matches) {
  auto programs = compile_regexes(regexes);

  // Get the StringArray representation
  auto sa = std::static_pointer_cast<arrow::StringArray>(array);

  // Iterate over all strings
  for (uint32_t i = 0; i < sa->length(); i++) {
    // Get the string in a zero-copy manner
    int length;
    const char *str = (const char *) sa->GetValue(i, &length);

    // Use a StringPiece for this, as Arrow does not (yet) support this in 0.8
    re2::StringPiece strpiece(str, static_cast<re2::StringPiece::size_type>(length));

    // Iterate over programs
    for (int p = 0; p < (int) regexes.size(); p++) {

      // Attempt to match each program
      if (re2::RE2::FullMatch(strpiece, *programs[p])) {
        matches[p]++;
      }
    }
  }

  // Clean up
  clear_programs(programs);
}

void add_matches_arrow_omp(const shared_ptr<arrow::Array> &array,
                           const vector<string> &regexes,
                           uint32_t* matches) {
  int np = static_cast<int>(regexes.size());
  int threads = omp_get_max_threads();
  // Prepare some memory to store each thread result
  auto *thread_matches = reinterpret_cast<uint32_t *>(calloc(sizeof(uint32_t), static_cast<size_t>(np) * threads));

  omp_set_num_threads(threads);

#pragma omp parallel
  {
    int t = omp_get_thread_num();

    auto programs = compile_regexes(regexes);

    // Get the StringArray representation
    auto sa = std::static_pointer_cast<arrow::StringArray>(array);

    // Each thread gets a range of strings to work on
#pragma omp for
    // Iterate over strings
    for (uint32_t i = 0; i < sa->length(); i++) {
      // Get the string in a zero-copy manner
      int length;
      const char *str = (const char *) sa->GetValue(i, &length);

      // Use a StringPiece for this, as Arrow does not (yet) support this in 0.8
      re2::StringPiece strpiece(str, static_cast<re2::StringPiece::size_type>(length));

      // Iterate over programs
      for (int p = 0; p < (int) regexes.size(); p++) {

        // Attempt to match each program
        if (re2::RE2::FullMatch(strpiece, *programs[p])) {
          // Increase the match count
          thread_matches[t * np + p]++;
        }
      }
    }

    // Clean up
    clear_programs(programs);
  }

  // Iterate over programs
  for (int p = 0; p < np; p++)
    // Iterate over threads
    for (int t = 0; t < threads; t++)
      // Accumulate the total match count
      matches[p] += thread_matches[t * np + p];

  // Clean up
  free(thread_matches);
}