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

/**
 * Main file for the regular expression matching example application.
 *
 * This example works only under the following constraints:
 *
 * - The number of rows MUST be an integer multiple of the number of active
 *   units (due to naive work distribution)
 *
 * Output format (all times are in seconds):
 * - no. rows, no. bytes (all buffers), table fill time,
 *   C++ run time, C++ using Arrow run time,
 *   C++ using OpenMP run time, C++ using OpenMP and Arrow run time,
 *   FPGA Copy time, FPGA run time
 *
 */
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

void generate_strings(vector<string> &strings,
                      const vector<vector<string>> &insert_strings,
                      const string &alphabet,
                      uint32_t max_str_len,
                      uint32_t rows,
                      int period,
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

/**
 * Create an Arrow table containing one column of random strings.
 */
shared_ptr<arrow::RecordBatch> createRecordBatch(const vector<string> &strings) {

  arrow::StringBuilder str_builder(arrow::default_memory_pool());

  for (const auto &s : strings) {
    str_builder.Append(s);
  }

  // Define the schema
  auto column_field = arrow::field("tweets", arrow::utf8(), false);
  vector<shared_ptr<arrow::Field>>
      fields = {column_field};
  shared_ptr<arrow::Schema> schema = std::make_shared<arrow::Schema>(fields);

  // Create an array and finish the builder
  shared_ptr<arrow::Array> str_array;
  str_builder.Finish(&str_array);

  // Create and return the table
  return arrow::RecordBatch::Make(schema, str_array->length(), {str_array});
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

void clear_programs(vector<re2::RE2 *> &programs) {
  for (auto p : programs) {
    delete p;
  }
}

/**
 * Match regular expression using a vector of strings as a source
 */
void add_matches(const vector<string> &strings,
                 const vector<string> &regexes,
                 vector<uint32_t> &matches) {
  auto programs = compile_regexes(regexes);

  // Match the regexes to the strings
  for (const auto &string : strings) {
    for (int p = 0; p < (int) regexes.size(); p++) {
      if (re2::RE2::FullMatch(string, *programs[p])) {
        matches[p]++;
      }
    }
  }

  clear_programs(programs);
}

/**
 * Match regular expression on multiple cores using a vector of strings as a source
 */
void add_matches_omp(const vector<string> &strings,
                     const vector<string> &regexes,
                     vector<uint32_t> &matches,
                     int threads) {
  int nt = threads;
  auto np = static_cast<int>(regexes.size());

  // Prepare some memory to store each thread result
  auto *thread_matches = (uint32_t *) calloc(sizeof(uint32_t), static_cast<size_t>(nt * np));

  omp_set_num_threads(threads);

#pragma omp parallel
  {
    int t = omp_get_thread_num();

    auto programs = compile_regexes(regexes);

    // Each thread gets a range of strings to work on
#pragma omp for
    // Iterate over strings
    for (uint s = 0; s < strings.size(); s++) {
      std::string str = strings[s];
      // Iterate over programs
      for (int p = 0; p < np; p++) {
        // Attempt to match each program
        if (re2::RE2::FullMatch(str, *programs[p])) {
          // Increase the match count
          thread_matches[t * np + p]++;
        }
      }
    }
    // Clean up regexes
    clear_programs(programs);
  }

  // Iterate over threads
  for (int t = 0; t < nt; t++) {
    // Iterate over programs
    for (int p = 0; p < np; p++) {
      // Accumulate the total match count
      matches[p] += thread_matches[t * np + p];
    }
  }

  // Clean up
  free(thread_matches);
}

/**
 * Match regular expression using Arrow table as a source
 */
void add_matches_arrow(const shared_ptr<arrow::Array> &array,
                       const vector<string> &regexes,
                       vector<uint32_t> &matches) {

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

/**
 * Match regular expression on multiple cores using Arrow table as a source
 */
void match_regex_arrow_omp(const shared_ptr<arrow::Array> &array,
                           const vector<string> &regexes,
                           vector<uint32_t> &matches,
                           int threads) {
  int np = static_cast<int>(matches.size());
  int nt = threads;

  // Prepare some memory to store each thread result
  auto *thread_matches = reinterpret_cast<uint32_t *>(calloc(sizeof(uint32_t), static_cast<size_t>(np) * nt));

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
    for (int t = 0; t < nt; t++)
      // Accumulate the total match count
      matches[p] += thread_matches[t * np + p];

  // Clean up
  free(thread_matches);
}

double calc_sum(const vector<double> &values) {
  return accumulate(values.begin(), values.end(), 0.0);
}

uint32_t calc_sum(const vector<uint32_t> &values) {
  return static_cast<uint32_t>(accumulate(values.begin(), values.end(), 0.0));
}

/**
 * Main function for the regular expression matching example
 */
int main(int argc, char **argv) {
  Timer t;

  // Number of experiments
  int ne = 1;

  srand(0);

  // Vector of vector of strings that get randomly inserted
  vector<vector<string>> insert_strings = {
      {"birD", "BirD", "biRd", "BIRd"}, {"BuNNy", "bunNY", "Bunny", "BUnnY"}, {"CaT", "CAT", "caT", "cAT"},
      {"doG", "DoG", "doG", "dOG"}, {"FerReT", "fErret", "feRret", "FERrEt"}, {"fIsH", "fIsH", "fisH", "fish"},
      {"geRbil", "GERbIl", "geRBiL", "GerBIL"}, {"hAMStER", "haMsTer", "hamstER", "hAMstER"},
      {"hOrsE", "HoRSE", "HORSe", "horSe"}, {"KITTeN", "KiTTEN", "KitteN", "KitTeN"},
      {"LiZArd", "LIzARd", "lIzArd", "LIzArD"}, {"MOusE", "MOUsE", "mOusE", "MouSE"},
      {"pUpPY", "pUPPy", "PUppY", "pupPY"}, {"RaBBIt", "RABBIt", "RaBbit", "RABBIt"}, {"Rat", "rAT", "rAT", "rat"},
      {"tuRtLE", "TURTLE", "tuRtle", "TURTle"}};

  // Regular expressions to match
  vector<string> regexes =
      {".*(?i)bird.*", ".*(?i)bunny.*", ".*(?i)cat.*", ".*(?i)dog.*", ".*(?i)ferret.*", ".*(?i)fish.*",
       ".*(?i)gerbil.*", ".*(?i)hamster.*", ".*(?i)horse.*", ".*(?i)kitten.*", ".*(?i)lizard.*", ".*(?i)mouse.*",
       ".*(?i)puppy.*", ".*(?i)rabbit.*", ".*(?i)rat.*", ".*(?i)turtle.*"};

  // Characters to use
  string alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890          ";

  uint32_t num_rows = 1024;
  uint32_t max_str_len = 256;
  uint32_t emask = 31;
  int period = 50;  // 1/50 chance to insert an insert_strings string in each row
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

  // Aggregators
  double t_create = 0.0;
  double t_ser = 0.0;
  uint64_t bytes_copied = 0;

  // Times
  vector<double> t_vcpu(static_cast<unsigned long>(ne), 0.0);
  vector<double> t_vomp(static_cast<unsigned long>(ne), 0.0);
  vector<double> t_acpu(static_cast<unsigned long>(ne), 0.0);
  vector<double> t_aomp(static_cast<unsigned long>(ne), 0.0);
  vector<double> t_copy(static_cast<unsigned long>(ne), 0.0);
  vector<double> t_fpga(static_cast<unsigned long>(ne), 0.0);

  auto np = static_cast<int>(regexes.size());

  // Matches for each experimenthttps://webdata.tudelft.nl/
  vector<vector<uint32_t>> m_vcpu(static_cast<unsigned long>(ne), vector<uint32_t>(np, 0));
  vector<vector<uint32_t>> m_vomp(static_cast<unsigned long>(ne), vector<uint32_t>(np, 0));
  vector<vector<uint32_t>> m_acpu(static_cast<unsigned long>(ne), vector<uint32_t>(np, 0));
  vector<vector<uint32_t>> m_aomp(static_cast<unsigned long>(ne), vector<uint32_t>(np, 0));
  vector<vector<uint32_t>> m_fpga(static_cast<unsigned long>(ne), vector<uint32_t>(np, 0));

  uint32_t first_index = 0;
  uint32_t last_index = num_rows;

  PRINT_INT(num_rows);

  t.start();
  // Generate some strings
  vector<string> strings(num_rows);

  generate_strings(strings,
                   insert_strings,
                   alphabet,
                   max_str_len,
                   num_rows,
                   period,
                   true);

  t.stop();
  t_create = t.seconds();

  PRINT_TIME(t_create);

  // Make a table with random strings containing some other string effectively serializing the data
  t.start();
  shared_ptr<arrow::RecordBatch> rb = createRecordBatch(strings);
  t.stop();
  t_ser = t.seconds();

  PRINT_TIME(t_ser);

  // Repeat the experiment
  for (int e = 0; e < ne; e++) {

    // Match on CPU
    if (emask & 1u) {
      t.start();
      add_matches(strings, regexes, m_vcpu[e]);
      t.stop();
      t_vcpu[e] = t.seconds();
    }

    // Match on CPU using OpenMP
    if (emask & 2u) {
      t.start();
      add_matches_omp(strings, regexes, m_vomp[e], omp_get_max_threads());
      t.stop();
      t_vomp[e] = t.seconds();
    }

    // Match on CPU using Arrow
    if (emask & 4u) {
      t.start();
      add_matches_arrow(rb->column(0), regexes, m_acpu[e]);
      t.stop();
      t_acpu[e] = t.seconds();
    }

    // Match on CPU using Arrow and OpenMP
    if (emask & 8u) {
      t.start();
      match_regex_arrow_omp(rb->column(0), regexes, m_aomp[e], omp_get_max_threads());
      t.stop();
      t_aomp[e] = t.seconds();
    }

    // Match on FPGA
    if (emask & 16u) {
      shared_ptr<fletcher::Platform> platform;
      shared_ptr<fletcher::Context> context;
      shared_ptr<RegExCore> rc;

      // Create a platform
      fletcher::Platform::Make(&platform);
      // Create a context
      fletcher::Context::Make(&context, platform);
      // Create the UserCore
      rc = std::make_shared<RegExCore>(context);

      // Initialize the platform
      platform->init();

      // Reset the UserCore
      rc->reset();

      // Prepare the column buffers
      t.start();
      context->queueRecordBatch(rb).ewf();
      bytes_copied += context->getQueueSize();
      context->enable().ewf();
      t.stop();
      t_copy[e] = t.seconds();

      // Run the example
      t.start();
      rc->setRegExpArguments(first_index, last_index);

#ifdef DEBUG
      // Check registers
      platform->printMMIO(0, 58, true);
#endif

      // Start the matchers and poll until completion
      rc->start();
#ifdef DEBUG
      rc->waitForFinish(100000);
#else
      rc->waitForFinish(10);
#endif

      // Get the number of matches from the UserCore
      rc->getMatches(&m_fpga[e]);

      t.stop();
      t_fpga[e] = t.seconds();
    }
  }

  PRINT_INT(bytes_copied);

  // Report the run times:
  PRINT_TIME(calc_sum(t_vcpu));
  PRINT_TIME(calc_sum(t_vomp));
  PRINT_TIME(calc_sum(t_acpu));
  PRINT_TIME(calc_sum(t_aomp));
  PRINT_TIME(calc_sum(t_copy));
  PRINT_TIME(calc_sum(t_fpga));

  // Report other settings
  PRINT_INT(ne);
  PRINT_INT(num_threads);
  PRINT_INT(emask);

  // Accumulated matches:
  vector<uint32_t> a_vcpu(np, 0);
  vector<uint32_t> a_vomp(np, 0);
  vector<uint32_t> a_acpu(np, 0);
  vector<uint32_t> a_aomp(np, 0);
  vector<uint32_t> a_fpga(np, 0);

  for (int p = 0; p < np; p++) {
    for (int e = 0; e < ne; e++) {
      a_vcpu[p] += m_vcpu[e][p];
      a_vomp[p] += m_vomp[e][p];
      a_acpu[p] += m_acpu[e][p];
      a_aomp[p] += m_aomp[e][p];
      a_fpga[p] += m_fpga[e][p];
    }
  }

  // Check if matches are equal
  if ((a_vcpu == a_vomp) && (a_vomp == a_acpu) && (a_acpu == a_aomp)
      && (a_aomp == a_fpga)) {
    std::cout << "PASS";
  } else {
    std::cout << "ERROR";
  }

  std::cout << endl;

  return 0;
}


