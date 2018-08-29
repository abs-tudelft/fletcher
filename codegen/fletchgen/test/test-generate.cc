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

#include "test_schemas.h"

int main(int argc, char* argv[]) {
  std::shared_ptr<arrow::Schema> schema;

  schema = fletchgen::test::genPrimReadSchema();
  fletchgen::writeSchemaToFile(schema, "primread.fbs");

  schema = fletchgen::test::genPrimWriteSchema();
  fletchgen::writeSchemaToFile(schema, "primwrite.fbs");

  schema = fletchgen::test::genStringSchema();
  fletchgen::writeSchemaToFile(schema, "stringread.fbs");

  return EXIT_SUCCESS;
}