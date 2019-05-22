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

#include <cstdlib>
#include <arrow/api.h>

#include "fletcher/arrow-utils.h"

#include "fletcher/test_schemas.h"
#include "fletcher/test_recordbatches.h"

namespace fletcher {

void generateDebugFiles() {
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
  fletcher::WriteSchemaToFile(schema, "schemas/primread.fbs");
  recordbatch = fletcher::getInt8RB();
  fletcher::WriteRecordBatchToFile(recordbatch, "recordbatches/primread.rb");

  schema = fletcher::GetPrimWriteSchema();
  fletcher::WriteSchemaToFile(schema, "schemas/primwrite.fbs");

  /* String */
  schema = fletcher::GetStringReadSchema();
  fletcher::WriteSchemaToFile(schema, "schemas/stringread.fbs");
  recordbatch = fletcher::getStringRB();
  fletcher::WriteRecordBatchToFile(recordbatch, "recordbatches/names.rb");

  schema = fletcher::GetStringWriteSchema();
  fletcher::WriteSchemaToFile(schema, "schemas/stringwrite.fbs");

  /* List of UInt8 */
  schema = fletcher::GetListUint8Schema();
  fletcher::WriteSchemaToFile(schema, "schemas/listuint8.fbs");
  recordbatch = fletcher::getListUint8RB();
  fletcher::WriteRecordBatchToFile(recordbatch, "recordbatches/listuint8.rb");

  /* List of Float64 */
  schema = fletcher::GetListFloatSchema();
  fletcher::WriteSchemaToFile(schema, "schemas/listfloat64.fbs");
  recordbatch = fletcher::getFloat64ListRB();
  fletcher::WriteRecordBatchToFile(recordbatch, "recordbatches/floatlist.rb");

  /* List of Int64 (length 2) */
  schema = fletcher::GetListIntSchema();
  fletcher::WriteSchemaToFile(schema, "schemas/listint64short.fbs");
  recordbatch = fletcher::getInt64ListRB();
  fletcher::WriteRecordBatchToFile(recordbatch, "recordbatches/intlist.rb");

  /* List of Int64 (length 8) */
  schema = fletcher::GetListIntSchema();
  fletcher::WriteSchemaToFile(schema, "schemas/listint64long.fbs");
  recordbatch = fletcher::getInt64ListWideRB();
  fletcher::WriteRecordBatchToFile(recordbatch, "recordbatches/intlistwide.rb");

  /* Filter example */
  schema = fletcher::GetFilterReadSchema();
  fletcher::WriteSchemaToFile(schema, "schemas/filter_read.fbs");
  schema = fletcher::GetFilterWriteSchema();
  fletcher::WriteSchemaToFile(schema, "schemas/filter_write.fbs");
  recordbatch = fletcher::getFilterRB();
  fletcher::WriteRecordBatchToFile(recordbatch, "recordbatches/filter.rb");

  /* SodaBeer example */
  auto hobbiton_sch = fletcher::GetSodaBeerSchema("Hobbiton", fletcher::Mode::READ);
  auto bywater_sch = fletcher::GetSodaBeerSchema("Bywater", fletcher::Mode::READ);
  auto soda_sch = fletcher::GetSodaBeerSchema("Soda", fletcher::Mode::WRITE);
  auto beer_sch = fletcher::GetSodaBeerSchema("Beer", fletcher::Mode::WRITE);
  std::vector<std::string> hobbiton_names = {"Bilbo", "Rosie", "Frodo", "Sam", "Elanor"};
  std::vector<uint8_t> hobbiton_ages = {111, 34, 33, 35, 1};
  std::vector<std::string> bywater_names = {"Lobelia", "Merry", "Pippin"};
  std::vector<uint8_t> bywater_ages = {80, 37, 29};
  auto hobbiton_rb = fletcher::getSodaBeerRB(hobbiton_names, hobbiton_ages);
  auto bywater_rb = fletcher::getSodaBeerRB(bywater_names, bywater_ages);

  fletcher::WriteSchemaToFile(hobbiton_sch, "schemas/Hobbiton.fbs");
  fletcher::WriteSchemaToFile(bywater_sch, "schemas/Bywater.fbs");
  fletcher::WriteSchemaToFile(soda_sch, "schemas/Soda.fbs");
  fletcher::WriteSchemaToFile(beer_sch, "schemas/Beer.fbs");
  fletcher::WriteRecordBatchToFile(hobbiton_rb, "recordbatches/Hobbiton.rb");
  fletcher::WriteRecordBatchToFile(bywater_rb, "recordbatches/Bywater.rb");
}

}

int main() {
  fletcher::generateDebugFiles();
  return EXIT_SUCCESS;
}
