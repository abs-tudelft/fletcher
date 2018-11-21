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

#define PRINT_TIME(X) std::cout << std::setprecision(10) << (X) << ", " << std::flush
#define PRINT_INT(X) std::cout << std::dec << (X) << ", " << std::flush

using std::vector;
using std::string;
using std::endl;
using std::shared_ptr;
using fletcher::Timer;

typedef int16_t zip_t;

/**
 * Generate a random row possibly containing the special last name and/or zip code.
 *
 * \param period The probability of insertion is 1/period
 */
void generate_random_row(vector<string> &first_names,
                                vector<string> &last_names,
                                vector<zip_t> &zip_codes,
                                const string &alphabet,
                                size_t max_length,
                                size_t min_length,
                                int last_name_period,
                                int zip_code_period,
                                string special_last_name,
                                int special_zip_code,
                                std::mt19937 &gen) {
    std::uniform_int_distribution<int> dis(0, std::numeric_limits<int>::max());

    // First name
    // Determine the length of the resulting string
    auto strlen = static_cast<int>(dis(gen) % (max_length-min_length) + min_length);

    // Create a string with nulls
    string first_name((size_t) strlen, '\0');

    // Fill the string with random characters from the alphabet
    for (int i = 0; i < strlen; i++) {
        first_name[i] = alphabet[dis(gen) % alphabet.length()];
    }

    first_names.push_back(first_name);

    //Last name
    if (dis(gen) % last_name_period == 0) {
        last_names.push_back(special_last_name);
    } else {
        // Determine the length of the resulting string
        strlen = static_cast<int>(dis(gen) % (max_length-min_length) + min_length);

        // Create a string with nulls
        string last_name((size_t) strlen, '\0');

        // Fill the string with random characters from the alphabet
        for (int i = 0; i < strlen; i++) {
            last_name[i] = alphabet[dis(gen) % alphabet.length()];
        }

        last_names.push_back(last_name);
    }

    //Zip code
    if (dis(gen) % zip_code_period == 0) {
        zip_codes.push_back(special_zip_code);
    } else {
        zip_codes.push_back(dis(gen) % 10000);
    }
}

void generate_input(vector<string> &first_names,
                    vector<string> &last_names,
                    vector<zip_t> &zip_codes,
                    string special_last_name,
                    int special_zip_code,
                    const string &alphabet,
                    uint32_t max_str_len,
                    uint32_t min_str_len,
                    uint32_t rows,
                    int last_name_period,
                    int zip_code_period,
                    bool save_to_file = true) {
    std::mt19937 gen(0);
    for (uint32_t i = 0; i < rows; i++) {
        generate_random_row(first_names, last_names, zip_codes, alphabet, max_str_len, min_str_len,
                            last_name_period, zip_code_period, special_last_name, special_zip_code,
                            gen);
    }

    // Used to compare performance with other programs
    if (save_to_file) {
        string fname("rows");
        fname += std::to_string(rows);
        fname += ".dat";
        std::ofstream fs(fname);
        if (fs.is_open()) {
            for (int i = 0; i < rows; i++) {
                fs << first_names.at(i) << "," << last_names.at(i) << "," << std::setw(4) << std::setfill('0')
                   << zip_codes.at(i) << endl;
            }
        }
    }
}

int main(int argc, char **argv) {

// Characters to use
    string alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
    string special_last_name = "Smith";
    int special_zip_code = 1337;

    uint32_t num_rows = 10024;
    uint32_t max_str_len = 8;
    uint32_t min_str_len = 2;
    uint32_t emask = 31;
    int ne = 1;
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
    vector<string> first_names;
    vector<string> last_names;
    vector<zip_t> zip_codes;

    generate_input(first_names,
                   last_names,
                   zip_codes,
                   special_last_name,
                   special_zip_code,
                   alphabet,
                   max_str_len,
                   min_str_len,
                   num_rows,
                   last_name_period,
                   zip_code_period,
                   true);

}