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

#include "../src/fletcher/common/arrow-utils.h"

#include "./test_schemas.h"
#include "./test_recordbatches.h"

int main() {
  std::shared_ptr<arrow::Schema> schema;
  std::shared_ptr<arrow::RecordBatch> recordbatch;

  // TODO(johanpel): Create directories in a portable manner
  system("mkdir -p schemas");
  system("mkdir -p recordbatches");

  /* Primitive */
  schema = fletcher::test::GetPrimReadSchema();
  fletcher::writeSchemaToFile(schema, "schemas/primread.fbs");
  recordbatch = fletcher::test::getUint8RB();
  fletcher::writeRecordBatchToFile(recordbatch, "recordbatches/primread.rb");

  schema = fletcher::test::GetPrimWriteSchema();
  fletcher::writeSchemaToFile(schema, "schemas/primwrite.fbs");

  /* String */
  schema = fletcher::test::GetStringReadSchema();
  fletcher::writeSchemaToFile(schema, "schemas/stringread.fbs");
  recordbatch = fletcher::test::getStringRB();
  fletcher::writeRecordBatchToFile(recordbatch, "recordbatches/names.rb");

  schema = fletcher::test::GetStringWriteSchema();
  fletcher::writeSchemaToFile(schema, "schemas/stringwrite.fbs");

  /* List of UInt8 */
  schema = fletcher::test::GetListUint8Schema();
  fletcher::writeSchemaToFile(schema, "schemas/listuint8.fbs");
  recordbatch = fletcher::test::getListUint8RB();
  fletcher::writeRecordBatchToFile(recordbatch, "recordbatches/listuint8.rb");

  /* List of Float64 */
  schema = fletcher::test::genFloatListSchema();
  fletcher::writeSchemaToFile(schema, "schemas/listfloat64.fbs");
  recordbatch = fletcher::test::getFloat64ListRB();
  fletcher::writeRecordBatchToFile(recordbatch, "recordbatches/floatlist.rb");

  /* List of Int64 (length 2) */
  schema = fletcher::test::genIntListSchema();
  fletcher::writeSchemaToFile(schema, "schemas/listint64short.fbs");
  recordbatch = fletcher::test::getInt64ListRB();
  fletcher::writeRecordBatchToFile(recordbatch, "recordbatches/intlist.rb");

  /* List of Int64 (length 8) */
  schema = fletcher::test::genIntListSchema();
  fletcher::writeSchemaToFile(schema, "schemas/listint64long.fbs");
  recordbatch = fletcher::test::getInt64ListWideRB();
  fletcher::writeRecordBatchToFile(recordbatch, "recordbatches/intlistwide.rb");

  /* Filter example */
  schema = fletcher::test::genFilterReadSchema();
  fletcher::writeSchemaToFile(schema, "schemas/filter_read.fbs");
  schema = fletcher::test::genFilterWriteSchema();
  fletcher::writeSchemaToFile(schema, "schemas/filter_write.fbs");
  recordbatch = fletcher::test::getFilterRB();
  fletcher::writeRecordBatchToFile(recordbatch, "recordbatches/filter.rb");

  return EXIT_SUCCESS;
}
