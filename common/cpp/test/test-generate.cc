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

#include "../src/common/arrow-utils.h"

#include "./test_schemas.h"
#include "./test_recordbatches.h"

int main(int argc, char *argv[]) {
  std::shared_ptr<arrow::Schema> schema;
  std::shared_ptr<arrow::RecordBatch> recordbatch;

  // TODO(johanpel): Create directories in a portable manner
  system("mkdir -p schemas");
  system("mkdir -p recordbatches");

  /* Primitive */
  schema = fletcher::test::genPrimReadSchema();
  fletcher::writeSchemaToFile(schema, "schemas/primread.fbs");
  recordbatch = fletcher::test::getUint8RB();
  fletcher::writeRecordBatchToFile(recordbatch, "recordbatches/primread.rb");

  schema = fletcher::test::genPrimWriteSchema();
  fletcher::writeSchemaToFile(schema, "schemas/primwrite.fbs");

  /* String */
  schema = fletcher::test::genStringSchema();
  fletcher::writeSchemaToFile(schema, "schemas/stringread.fbs");
  recordbatch = fletcher::test::getStringRB();
  fletcher::writeRecordBatchToFile(recordbatch, "recordbatches/names.rb");

  /* List of UInt8 */
  schema = fletcher::test::genListUint8Schema();
  fletcher::writeSchemaToFile(schema, "schemas/listuint8.fbs");
  recordbatch = fletcher::test::getListUint8RB();
  fletcher::writeRecordBatchToFile(recordbatch, "recordbatches/listuint8.rb");

  return EXIT_SUCCESS;
}
