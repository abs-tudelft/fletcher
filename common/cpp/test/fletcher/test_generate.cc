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
}

}

int main() {
  fletcher::generateDebugFiles();
  return EXIT_SUCCESS;
}
