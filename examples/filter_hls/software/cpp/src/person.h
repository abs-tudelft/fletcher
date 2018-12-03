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
#pragma once

#include <memory>
#include <random>

#include <arrow/api.h>

struct RandomGenerator {
  // Use the mt19937 random number engine
  std::mt19937 gen;
  // Use a uniform real destribution for integers
  std::uniform_int_distribution<int> dis;

  explicit RandomGenerator(int seed = 0, int min = 0, int max = std::numeric_limits<int>::max())
      : gen(std::mt19937(seed)) {
    dis = std::uniform_int_distribution<int>(min, max);
  }

  inline int next() { return dis(gen); }
};

typedef uint32_t zip_t;

struct Person {
  std::string first_name;
  std::string last_name;
  zip_t zip_code;
};

std::shared_ptr<arrow::Schema> getReadSchema();
std::shared_ptr<arrow::Schema> getWriteSchema();

/**
 * Generate a random row possibly containing the special last name and/or zip code.
 *
 * @param period The probability of insertion is 1/period
 */
Person generateRandomPerson(const std::string &alphabet,
                            int last_name_period,
                            int zip_code_period,
                            const std::string &special_last_name,
                            zip_t special_zip_code,
                            RandomGenerator& len,
                            RandomGenerator& zip);

std::shared_ptr<std::vector<Person>> generateInput(const std::string &special_last_name,
                                                   zip_t special_zip_code,
                                                   const std::string &alphabet,
                                                   uint32_t min_str_len,
                                                   uint32_t max_str_len,
                                                   int32_t rows,
                                                   int last_name_period,
                                                   int zip_code_period,
                                                   bool save_to_file);

std::shared_ptr<arrow::RecordBatch> serialize(std::shared_ptr<std::vector<Person>> dataset);