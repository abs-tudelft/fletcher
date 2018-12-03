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

#include <string>
#include <fstream>
#include <iomanip>
#include <memory>

#include <arrow/api.h>
#include <fletcher/api.h>

#include "person.h"

std::shared_ptr<arrow::Schema> getReadSchema() {
  std::vector<std::shared_ptr<arrow::Field>> schema_fields = {
      arrow::field("first", arrow::utf8(), false),
      arrow::field("last", arrow::utf8(), false),
      arrow::field("zip", arrow::uint32(), false)
  };
  auto schema = std::make_shared<arrow::Schema>(schema_fields, metaMode(fletcher::Mode::READ));
  return schema;
}
std::shared_ptr<arrow::Schema> getWriteSchema() {
  std::vector<std::shared_ptr<arrow::Field>> schema_fields = {
      arrow::field("first", arrow::utf8(), false),
  };
  auto schema = std::make_shared<arrow::Schema>(schema_fields, metaMode(fletcher::Mode::WRITE));
  return schema;
}

Person generateRandomPerson(const std::string &alphabet,
                            int last_name_period,
                            int zip_code_period,
                            const std::string &special_last_name,
                            zip_t special_zip_code,
                            RandomGenerator &len,
                            RandomGenerator &zip) {
  Person ret;

  // First name
  // Determine the length of the resulting string
  auto strlen = static_cast<size_t>(len.next());

  // Create a string with nulls
  ret.first_name = std::string(strlen, '\0');

  // Fill the string with random characters from the alphabet
  for (size_t i = 0; i < strlen; i++) {
    ret.first_name[i] = alphabet[zip.next() % alphabet.length()];
  }

  //Last name
  if (zip.next() % last_name_period == 0) {
    ret.last_name = special_last_name;
  } else {
    // Determine the length of the resulting string
    strlen = static_cast<size_t>(len.next());

    // Create a string with nulls
    ret.last_name = std::string(strlen, '\0');

    // Fill the string with random characters from the alphabet
    for (size_t i = 0; i < strlen; i++) {
      ret.last_name[i] = alphabet[zip.next() % alphabet.length()];
    }
  }

  //Zip code
  if (zip.next() % zip_code_period == 0) {
    ret.zip_code = special_zip_code;
  } else {
    ret.zip_code = (zip_t) (zip.next() % 10000);
  }

  return ret;
}

std::shared_ptr<std::vector<Person>> generateInput(const std::string &special_last_name,
                                                   zip_t special_zip_code,
                                                   const std::string &alphabet,
                                                   uint32_t min_str_len,
                                                   uint32_t max_str_len,
                                                   int32_t rows,
                                                   int last_name_period,
                                                   int zip_code_period,
                                                   bool save_to_file) {
  auto collection = std::make_shared<std::vector<Person>>();
  collection->reserve(static_cast<unsigned long>(rows));

  RandomGenerator rg_zip;
  RandomGenerator rg_len(0, min_str_len, max_str_len);

  for (int32_t i = 0; i < rows; i++) {
    collection->push_back(generateRandomPerson(alphabet,
                                               last_name_period,
                                               zip_code_period,
                                               special_last_name,
                                               special_zip_code,
                                               rg_len,
                                               rg_zip));
  }

  // Used to compare performance with other programs
  if (save_to_file) {
    std::string fname("rows");
    fname += std::to_string(rows);
    fname += ".dat";
    std::ofstream fs(fname);
    if (fs.is_open()) {
      for (size_t i = 0; i < rows; i++) {
        fs << collection->at(i).first_name << ","
           << collection->at(i).last_name << ","
           << std::setw(4) << std::setfill('0') << collection->at(i).zip_code
           << std::endl;
      }
    }
  }
  return collection;
}

std::shared_ptr<arrow::RecordBatch> serialize(std::shared_ptr<std::vector<Person>> dataset) {
  std::shared_ptr<arrow::Array> first_name;
  std::shared_ptr<arrow::Array> last_name;
  std::shared_ptr<arrow::Array> zip_code;

  arrow::StringBuilder fnb;
  arrow::StringBuilder lnb;
  arrow::UInt32Builder zb;

  for (const auto &person : *dataset) {
    fnb.Append(person.first_name);
    lnb.Append(person.last_name);
    zb.Append(person.zip_code);
  }

  fnb.Finish(&first_name);
  lnb.Finish(&last_name);
  zb.Finish(&zip_code);

  auto rb = arrow::RecordBatch::Make(getReadSchema(), dataset->size(), {first_name, last_name, zip_code});
  return rb;
}
