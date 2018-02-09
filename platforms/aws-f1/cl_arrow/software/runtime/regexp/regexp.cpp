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
 * TODO:
 * - Somehow, only on the Amazon instance on CentOS after using dev toolkit 6
 *   the program will end with a segmentation fault. GDB/Valgrind reveal that
 *   it has something to do with the Arrow schema, when the shared_ptr tries
 *   to clean up the last use count. However, at this time I have no idea how
 *   to fix it. I cannot reproduce the error on any other configuration. This
 *   code may be wrong or it may be something in Arrow internally. -johanpel
 *
 */
#include <cstdint>
#include <memory>
#include <vector>
#include <string>
#include <numeric>
#include <iostream>
#include <fstream>
#include <omp.h>

// RE2 regular expressions library
#include <re2/re2.h>

// Apache Arrow
#include <arrow/api.h>

// Fletcher
#include "fletcher.h"

// RegEx FPGA UserCore
#include "RegExUserCore.h"

using namespace std;

/**
 * Generate a random string possibly containing some other string.
 *
 * \param period The probability of insertion is 1/period
 */
inline string generate_random_string_with(const vector<vector<string>>& insert_strings,
                                          const string& alphabet,
                                          size_t max_length,
                                          int period,
                                          int &which)
{
  // Determine which string to insert
  int s = rand() % insert_strings.size();
  int n = rand() % insert_strings[s].size();

  // Determine the length of the resulting string
  int strlen = insert_strings[s][n].length()
      + (rand() % (max_length - insert_strings[s][n].length()));

  // Create a string with nulls
  string ret((size_t) strlen, '\0');

  // Fill the string with random characters from the alphabet
  for (int i = 0; i < strlen; i++) {
    ret[i] = alphabet[rand() % alphabet.length()];
  }

  // Randomize insertion based on the period argument
  if (rand() % period == 0) {
    int start = rand() % ret.length();
    int length = insert_strings[s][n].length();
    ret.replace(start, length, insert_strings[s][n]);
    which = s;
  }

  return ret;
}

vector<uint32_t> generate_strings(vector<string>& strings,
                                  const vector<vector<string>>& insert_strings,
                                  const string& alphabet,
                                  uint32_t max_str_len,
                                  uint32_t rows,
                                  int period,
                                  bool save_to_file = true)
{

  vector<uint32_t> insertions(strings.size(), 0);

  // Create some strings
  for (uint32_t i = 0; i < rows; i++) {
    int which = -1;
    strings[i] = generate_random_string_with(insert_strings,
                                             alphabet,
                                             max_str_len,
                                             period,
                                             which);
    if (which != -1) {
      insertions[which]++;
    }
  }

  // Used to compare performance with other programs
  if (save_to_file) {
    string fname("strings");
    fname += to_string(rows);
    fname += ".dat";
    ofstream fs(fname);
    if (fs.is_open()) {
      for (auto str : strings) {
        fs << str << endl;
      }
    }
  }

  return insertions;
}

/**
 * Create an Arrow table containing one column of random strings.
 */
shared_ptr<arrow::Table> create_table(const vector<string>& strings)
{

  arrow::StringBuilder str_builder(arrow::default_memory_pool());

  for (uint32_t i = 0; i < strings.size(); i++) {
    auto s = strings[i];
    str_builder.Append(s);
  }

  // Define the schema
  auto column_field = arrow::field("tweets", arrow::utf8(), false);
  vector<shared_ptr<arrow::Field>> fields = { column_field };
  shared_ptr<arrow::Schema> schema = make_shared<arrow::Schema>(fields);

  // Create an array and finish the builder
  shared_ptr<arrow::Array> str_array;
  str_builder.Finish(&str_array);

  // Create and return the table
  return move(arrow::Table::Make(schema, { str_array }));
}

vector<re2::RE2*> compile_regexes(const vector<string>& regexes)
{
  // Allocate a vector for the programs
  vector<re2::RE2*> programs;

  // Compile the regexes
  for (int i = 0; i < (int) regexes.size(); i++) {
    re2::RE2* re = new re2::RE2(regexes[i]);

    programs.push_back(re);
  }

  return programs;
}

void clear_programs(vector<re2::RE2*>& programs)
{
  for (auto p : programs) {
    delete p;
  }
}

/**
 * Match regular expression using a vector of strings as a source
 */
void add_matches(const vector<string>& strings,
                 const vector<string>& regexes,
                 vector<uint32_t>& matches)
{
  auto programs = compile_regexes(regexes);

  // Match the regexes to the strings
  for (uint32_t i = 0; i < strings.size(); i++) {
    for (int p = 0; p < (int) regexes.size(); p++) {
      if (re2::RE2::FullMatch(strings[i], *programs[p])) {
        matches[p]++;
      }
    }
  }

  clear_programs(programs);
}

/**
 * Match regular expression on multiple cores using a vector of strings as a source
 */
void add_matches_omp(const vector<string>& strings,
                     const vector<string>& regexes,
                     vector<uint32_t>& matches,
                     int threads)
{
  int nt = threads;
  int np = regexes.size();

  // Prepare some memory to store each thread result
  uint32_t* thread_matches = (uint32_t*) calloc(sizeof(uint32_t), nt * np);

  omp_set_num_threads(threads);

#pragma omp parallel
  {
    int t = omp_get_thread_num();

    auto programs = compile_regexes(regexes);

    // Each thread gets a range of strings to work on
#pragma omp for
    // Iterate over strings
    for (uint32_t i = 0; i < strings.size(); i++) {
      // Iterate over programs
      for (int p = 0; p < np; p++) {
        // Attempt to match each program
        if (re2::RE2::FullMatch(strings[i], *programs[p])) {
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
void add_matches_arrow(const shared_ptr<arrow::Column>& column,
                       const vector<string>& regexes,
                       vector<uint32_t>& matches)
{

  auto programs = compile_regexes(regexes);

  // Get the StringArray representation
  auto sa = static_pointer_cast<arrow::StringArray>(column->data()->chunk(0));

  // Iterate over all strings
  for (uint32_t i = 0; i < sa->length(); i++) {
    // Get the string in a zero-copy manner
    int length;
    const char* str = (const char*) sa->GetValue(i, &length);

    // Use a StringPiece for this, as Arrow does not (yet) support this in 0.8
    re2::StringPiece strpiece(str, length);

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
void match_regex_arrow_omp(const shared_ptr<arrow::Column>& column,
                           const vector<string>& regexes,
                           vector<uint32_t>& matches,
                           int threads)
{
  int np = matches.size();
  int nt = threads;

  // Prepare some memory to store each thread result
  uint32_t* thread_matches = (uint32_t*) calloc(sizeof(uint32_t), np * nt);

  omp_set_num_threads(threads);

#pragma omp parallel
  {
    int t = omp_get_thread_num();

    auto programs = compile_regexes(regexes);

    // Get the StringArray representation
    auto sa = static_pointer_cast<arrow::StringArray>(column->data()->chunk(0));

    // Each thread gets a range of strings to work on
#pragma omp for
    // Iterate over strings
    for (uint32_t i = 0; i < sa->length(); i++) {
      // Get the string in a zero-copy manner
      int length;
      const char* str = (const char*) sa->GetValue(i, &length);

      // Use a StringPiece for this, as Arrow does not (yet) support this in 0.8
      re2::StringPiece strpiece(str, length);

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

double calc_sum(const vector<double>& values)
{
  return accumulate(values.begin(), values.end(), 0.0);
}

uint32_t calc_sum(const vector<uint32_t>& values)
{
  return accumulate(values.begin(), values.end(), 0.0);
}

/**
 * Main function for the regular expression matching example
 */
int main(int argc, char ** argv)
{
  // For wall clock timers
  double start, stop;

  // Number of experiments
  int ne = 1;

  srand(0);

  // Vector of vector of strings that get randomly inserted
  vector<vector<string>> insert_strings = {
    {"birD","BirD","biRd","BIRd"},
    {"BuNNy","bunNY","Bunny","BUnnY"},
    {"CaT","CAT","caT","cAT"},
    {"doG","DoG","doG","dOG"},
    {"FerReT","fErret","feRret","FERrEt"},
    {"fIsH","fIsH","fisH","fish"},
    {"geRbil","GERbIl","geRBiL","GerBIL"},
    {"hAMStER","haMsTer","hamstER","hAMstER"},
    {"hOrsE","HoRSE","HORSe","horSe"},
    {"KITTeN","KiTTEN","KitteN","KitTeN"},
    {"LiZArd","LIzARd","lIzArd","LIzArD"},
    {"MOusE","MOUsE","mOusE","MouSE"},
    {"pUpPY","pUPPy","PUppY","pupPY"},
    {"RaBBIt","RABBIt","RaBbit","RABBIt"},
    {"Rat","rAT","rAT","rat"},
    {"tuRtLE","TURTLE","tuRtle","TURTle"}
  };

  // Regular expressions to match
  vector<string> regexes = {".*(?i)bird.*",
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
                            ".*(?i)turtle.*"};

  // Characters to use
  string alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890          ";

  uint32_t num_rows = 512;
  uint32_t max_str_len = 256;
  uint32_t emask = 31;
  int period = 50;  // 1/50 chance to insert an insert_strings string in each row

  flush(cout);
  if (argc >= 2) {
    sscanf(argv[1], "%u", &num_rows);
  }
  if (argc >= 3) {
    sscanf(argv[2], "%u", &ne);
  }
  if (argc == 4) {
    sscanf(argv[3], "%u", &emask);
  }

  // Aggregators
  double t_create = 0.0;
  double t_ser = 0.0;
  uint64_t bytes_copied = 0;

  // Times
  vector<double> t_vcpu(ne, 0.0);
  vector<double> t_vomp(ne, 0.0);
  vector<double> t_acpu(ne, 0.0);
  vector<double> t_aomp(ne, 0.0);
  vector<double> t_copy(ne, 0.0);
  vector<double> t_fpga(ne, 0.0);

  int np = regexes.size();

  // Matches for each experiment
  vector<vector<uint32_t>> m_vcpu(ne, vector<uint32_t>(np, 0));
  vector<vector<uint32_t>> m_vomp(ne, vector<uint32_t>(np, 0));
  vector<vector<uint32_t>> m_acpu(ne, vector<uint32_t>(np, 0));
  vector<vector<uint32_t>> m_aomp(ne, vector<uint32_t>(np, 0));
  vector<vector<uint32_t>> m_fpga(ne, vector<uint32_t>(np, 0));

  uint32_t first_index = 0;
  uint32_t last_index = num_rows;

  start = omp_get_wtime();
  // Generate some strings
  vector<string> strings(num_rows);

  auto insertions = generate_strings(strings,
                                     insert_strings,
                                     alphabet,
                                     max_str_len,
                                     num_rows,
                                     period);
  stop = omp_get_wtime();
  t_create = (stop - start);

  // Make a table with random strings containing some other string effectively serializing the data
  start = omp_get_wtime();
  shared_ptr<arrow::Table> table = create_table(strings);
  stop = omp_get_wtime();
  t_ser = (stop - start);

  // Repeat the experiment
  for (int e = 0; e < ne; e++) {

    // Match on CPU
    if (emask & 1) {
      start = omp_get_wtime();
      add_matches(strings, regexes, m_vcpu[e]);
      stop = omp_get_wtime();
      t_vcpu[e] = (stop - start);
    }

    // Match on CPU using OpenMP
    if (emask & 2) {
      start = omp_get_wtime();
      add_matches_omp(strings, regexes, m_vomp[e], omp_get_max_threads());
      stop = omp_get_wtime();
      t_vomp[e] = (stop - start);
    }

    // Match on CPU using Arrow
    if (emask & 4) {
      start = omp_get_wtime();
      add_matches_arrow(table->column(0), regexes, m_acpu[e]);
      stop = omp_get_wtime();
      t_acpu[e] = (stop - start);
    }

    // Match on CPU using Arrow and OpenMP
    if (emask & 8) {
      start = omp_get_wtime();
      match_regex_arrow_omp(table->column(0), regexes, m_aomp[e], omp_get_max_threads());
      stop = omp_get_wtime();
      t_aomp[e] = (stop - start);
    }

    // Match on FPGA
    if (emask & 16) {
      // Create a platform
      shared_ptr<fletcher::AWSPlatform> platform(new fletcher::AWSPlatform());

      // Prepare the colummn buffers
      start = omp_get_wtime();
      bytes_copied = platform->prepare_column_chunks(table->column(0));
      stop = omp_get_wtime();
      t_copy[e] = (stop - start);

      // Create a UserCore
      RegExUserCore uc(static_pointer_cast<fletcher::FPGAPlatform>(platform));

      // Reset it
      uc.reset();

      // Run the example
      start = omp_get_wtime();
      uc.set_arguments(first_index, last_index);
      uc.start();
      uc.wait_for_finish(10);

      // Get the number of matches from the UserCore
      uc.get_matches(m_fpga[e]);
      stop = omp_get_wtime();
      t_fpga[e] = (stop - start);
    }
  }

  // Report the outcomes:
  printf("%10u,", num_rows);
  printf("%10lu,", bytes_copied);
  printf("%13.10f,", t_create);
  printf("%13.10f,", t_ser);

  printf("%13.10f,", calc_sum(t_vcpu));
  printf("%13.10f,", calc_sum(t_vomp));
  printf("%13.10f,", calc_sum(t_acpu));
  printf("%13.10f,", calc_sum(t_aomp));
  printf("%13.10f,", calc_sum(t_copy));
  printf("%13.10f,", calc_sum(t_fpga));

  // Print insertions
  //for (int p = 0; p < np; p++) {
  //  printf("%u,", insertions[p]);
  //}

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

  // Print matches. Not necessarily equal to insertions as lots of random dogs or cats can pop up
  //for (int p = 0; p < np; p++) {
  //  printf("%u,%u,%u,%u,%u,", a_vcpu[p], a_vomp[p], a_acpu[p], a_aomp[p], a_fpga[p]);
  //}

  // Check if matches are equal
  if ((a_vcpu == a_vomp) && (a_vomp == a_acpu) && (a_acpu == a_aomp)
      && (a_aomp == a_fpga)) {
    printf("PASS");
  } else {
    printf("ERROR");
  }

  printf("\n");

  return 0;
}

