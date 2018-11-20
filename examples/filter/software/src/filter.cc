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
#include <vector>
#include <string>
#include <numeric>
#include <iostream>
#include <iomanip>
#include <fstream>
#include <random>
#include <omp.h>
#include <unistd.h>

// RE2 regular expressions library
#include <re2/re2.h>

// Apache Arrow
#include <arrow/api.h>

// Fletcher
#include <fletcher/fletcher.h>
#include <fletcher/common/timer.h>

// RegEx FPGA UserCore
#include "./regex-usercore.h"

#define PRINT_TIME(X) std::cout << std::setprecision(10) << (X) << ", " << std::flush
#define PRINT_INT(X) std::cout << std::dec << (X) << ", " << std::flush

using std::vector;
using std::string;
using std::endl;
using std::shared_ptr;
using fletcher::Timer;

typedef int16_t zip_t;

/**
 * Generate a random string possibly containing some other string.
 *
 * \param period The probability of insertion is 1/period
 */
inline std::string generate_random_string_with(const vector<vector<string>> &insert_strings,
                                               const string &alphabet,
                                               size_t max_length,
                                               int period,
                                               int &which,
                                               std::mt19937 &gen
) {
  std::uniform_int_distribution<int> dis(0, std::numeric_limits<int>::max());

  // Determine which string to insert
  auto s = static_cast<int>(dis(gen) % insert_strings.size());
  auto n = static_cast<int>(dis(gen) % insert_strings[s].size());

  // Determine the length of the resulting string
  auto strlen = static_cast<int>(insert_strings[s][n].length()
      + (dis(gen) % (max_length - insert_strings[s][n].length())));

  // Create a string with nulls
  string ret((size_t) strlen, '\0');

  // Fill the string with random characters from the alphabet
  for (int i = 0; i < strlen; i++) {
    ret[i] = alphabet[dis(gen) % alphabet.length()];
  }

  // Randomize insertion based on the period argument
  if (dis(gen) % period == 0) {
    auto start = static_cast<int>(dis(gen) % ret.length());
    auto length = static_cast<int>(insert_strings[s][n].length());
    ret.replace(static_cast<unsigned long>(start), static_cast<unsigned long>(length), insert_strings[s][n]);
    which = s;
  }

  return ret;
}

void generate_input(vector<string> &first_names,
                      vector<string> &last_names,
                      vector<zip_t> &zip_codes,
                      string special_last_name,
                      int special_zip_code,
                      const string &alphabet,
                      uint32_t max_str_len,
                      uint32_t rows,
                      int last_name_period,
                      int zip_code_period,
                      bool save_to_file = true) {
  std::mt19937 gen(0);
  for (uint32_t i = 0; i < rows; i++) {
    int which = -1;
    strings[i] = generate_random_string_with(insert_strings, alphabet, max_str_len, period, which, gen);
  }

  // Used to compare performance with other programs
  if (save_to_file) {
    string fname("strings");
    fname += std::to_string(rows);
    fname += ".dat";
    std::ofstream fs(fname);
    if (fs.is_open()) {
      for (const auto &str : strings) {
        fs << str << endl;
      }
    }
  }
}

int main(int argc, char **argv) {

// Characters to use
  string alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890          ";
  string special_last_name = "Smith";
  int special_zip_code = 1337

  uint32_t num_rows = 1024;
  uint32_t max_str_len = 256;
  uint32_t emask = 31;
  int last_name_period = 10;  // 1/10 chance to insert the selected special last name
  int zip_code_period = 10; // 1/10 chance to insert the selected special zip_code
  int num_threads = omp_get_max_threads();

  std::cout.flush();

  if (argc >= 2) {
    num_rows = static_cast<uint32_t>(std::strtoul(argv[1], nullptr, 10));
  }
  if (argc >= 3) {
    ne = static_cast<int>(std::strtoul(argv[2], nullptr, 10));
  }
  if (argc >= 4) {
    emask = static_cast<uint32_t>(std::strtoul(argv[3], nullptr, 10));
  }
  if (argc >= 5) {
    num_threads = static_cast<int>(std::strtoul(argv[4], nullptr, 10));
  }

  // Generate some input values
  vector<string> first_names(num_rows);
  vector<string> last_names(num_rows);
  vector<zip_t> zip_codes(num_rows);

  generate_input(first_names,
                   last_names,
                   zip_codes
                   special_last_name,
                   special_zip_code,
                   alphabet,
                   max_str_len,
                   num_rows,
                   last_name_period,
                   zip_code_period,
                   true);

}

// Todo: replace generate_random_string_with. Correct filewriting