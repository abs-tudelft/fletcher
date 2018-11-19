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

#include "../src/arrow-utils.h"
#include "../src/srec/recordbatch.h"

#include "test_schemas.h"
#include "test_recordbatches.h"

int main(int argc, char* argv[]) {
  std::shared_ptr<arrow::Schema> schema;
  std::shared_ptr<arrow::RecordBatch> recordbatch;

  /* Primitive */
  schema = fletchgen::test::genPrimReadSchema();
  fletchgen::writeSchemaToFile(schema, "schemas/primread.fbs");
  recordbatch = fletchgen::test::getUint8RB();
  fletchgen::srec::writeRecordBatchToFile(*recordbatch, "recordbatches/primread.rb");

  schema = fletchgen::test::genPrimWriteSchema();
  fletchgen::writeSchemaToFile(schema, "schemas/primwrite.fbs");

  /* String */
  schema = fletchgen::test::genStringSchema();
  fletchgen::writeSchemaToFile(schema, "schemas/stringread.fbs");
  recordbatch = fletchgen::test::getStringRB();
  fletchgen::srec::writeRecordBatchToFile(*recordbatch, "recordbatches/names.rb");

  /* Float List */
  schema = fletchgen::test::genFloatListSchema();
  fletchgen::writeSchemaToFile(schema, "schemas/floatlistread.fbs");
  recordbatch = fletchgen::test::getFloat64ListRB();
  fletchgen::srec::writeRecordBatchToFile(*recordbatch, "recordbatches/floatlist.rb");

  /* Number List */
  schema = fletchgen::test::genIntListSchema();
  fletchgen::writeSchemaToFile(schema, "schemas/intlistread.fbs");
  recordbatch = fletchgen::test::getInt64ListRB();
  fletchgen::srec::writeRecordBatchToFile(*recordbatch, "recordbatches/intlist.rb");

  /* Number List Widde */
  schema = fletchgen::test::genIntListSchema();
  fletchgen::writeSchemaToFile(schema, "schemas/intlistread.fbs");
  recordbatch = fletchgen::test::getInt64ListWideRB();
  fletchgen::srec::writeRecordBatchToFile(*recordbatch, "recordbatches/intlistwide.rb");

  return EXIT_SUCCESS;
}
