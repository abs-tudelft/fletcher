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

#include <arrow/api.h>
#include <cstdlib>

#include "fletcher/test_schemas.h"
#include "fletcher/test_recordbatches.h"
#include "fletcher/arrow-utils.h"

// Define extensions for files
#define SCH_FILE(X) std::string("schemas/") + X + ".as"
#define RB_FILE(X) std::string("recordbatches/") + X + ".rb"

namespace fletcher {

void GenerateDebugFiles() {
  // TODO(johanpel): Create directories in a portable manner
  int ret = system("mkdir -p schemas");
  if (ret == -1) {
    throw std::runtime_error("Could not create directory for schemas");
  }
  ret = system("mkdir -p recordbatches");
  if (ret == -1) {
    throw std::runtime_error("Could not create directory for recordbatches");
  }

  std::shared_ptr<arrow::Schema> schema;
  std::shared_ptr<arrow::RecordBatch> recordbatch;

  /* Primitive */
  schema = fletcher::GetPrimReadSchema();
  fletcher::WriteSchemaToFile(SCH_FILE("primread"), *schema);
  recordbatch = fletcher::GetIntRB();
  fletcher::WriteRecordBatchesToFile(RB_FILE("primread"), {recordbatch});

  schema = fletcher::GetPrimWriteSchema();
  fletcher::WriteSchemaToFile(SCH_FILE("primwrite"), *schema);

  schema = fletcher::GetTwoPrimReadSchema();
  fletcher::WriteSchemaToFile(SCH_FILE("twoprimread"), *schema);
  schema = fletcher::GetTwoPrimWriteSchema();
  fletcher::WriteSchemaToFile(SCH_FILE("twoprimwrite"), *schema);
  fletcher::WriteRecordBatchesToFile(RB_FILE("twoprimread"), {GetTwoPrimReadRB()});

  /* String */
  schema = fletcher::GetStringReadSchema();
  fletcher::WriteSchemaToFile(SCH_FILE("stringread"), *schema);
  recordbatch = fletcher::GetStringRB();
  fletcher::WriteRecordBatchesToFile(RB_FILE("names"), {recordbatch});

  schema = fletcher::GetStringWriteSchema();
  fletcher::WriteSchemaToFile(SCH_FILE("stringwrite"), *schema);

  /* List of UInt8 */
  schema = fletcher::GetListUint8Schema();
  fletcher::WriteSchemaToFile(SCH_FILE("listuint8"), *schema);
  recordbatch = fletcher::GetListUint8RB();
  fletcher::WriteRecordBatchesToFile(RB_FILE("listuint8"), {recordbatch});

  /* List of Float64 */
  schema = fletcher::GetListFloatSchema();
  fletcher::WriteSchemaToFile(SCH_FILE("listfloat64"), *schema);
  recordbatch = fletcher::GetFloat64RB();
  fletcher::WriteRecordBatchesToFile(RB_FILE("floatlist"), {recordbatch});

  /* List of Int64 (length 2) */
  schema = fletcher::GetListIntSchema();
  fletcher::WriteSchemaToFile(SCH_FILE("listint64short"), *schema);
  recordbatch = fletcher::GetInt64RB();
  fletcher::WriteRecordBatchesToFile(RB_FILE("intlist"), {recordbatch});

  /* List of Int64 (length 8) */
  schema = fletcher::GetListIntSchema();
  fletcher::WriteSchemaToFile(SCH_FILE("listint64long"), *schema);
  recordbatch = fletcher::GetInt64ListWideRB();
  fletcher::WriteRecordBatchesToFile(RB_FILE("intlistwide"), {recordbatch});

  /* Filter example */
  schema = fletcher::GetFilterReadSchema();
  fletcher::WriteSchemaToFile(SCH_FILE("filter_read"), *schema);
  schema = fletcher::GetFilterWriteSchema();
  fletcher::WriteSchemaToFile(SCH_FILE("filter_write"), *schema);
  recordbatch = fletcher::GetFilterRB();
  fletcher::WriteRecordBatchesToFile(RB_FILE("filter"), {recordbatch});

  /* SodaBeer example */
  auto hobbits_sch = fletcher::GetSodaBeerSchema("Hobbits", fletcher::Mode::READ);
  auto soda_sch = fletcher::GetSodaBeerSchema("Soda", fletcher::Mode::WRITE);
  auto beer_sch = fletcher::GetSodaBeerSchema("Beer", fletcher::Mode::WRITE);
  std::vector<std::string> hobbit_names = {"Bilbo", "Sam", "Rosie", "Frodo", "Elanor", "Lobelia", "Merry", "Pippin"};
  std::vector<uint8_t> hobbit_ages = {111, 35, 32, 33, 1, 80, 37, 29};
  auto hobbits_rb = fletcher::GetSodaBeerRB(hobbits_sch, hobbit_names, hobbit_ages);

  fletcher::WriteSchemaToFile(SCH_FILE("Hobbits"), *hobbits_sch);
  fletcher::WriteSchemaToFile(SCH_FILE("Soda"), *soda_sch);
  fletcher::WriteSchemaToFile(SCH_FILE("Beer"), *beer_sch);
  fletcher::WriteRecordBatchesToFile(RB_FILE("Hobbits"), {hobbits_rb});
}

}

int main(int argc, char** argv) {
  std::cout << argv[0];
  fletcher::GenerateDebugFiles();
  return 0;
}
