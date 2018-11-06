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

#include <memory>
#include <arrow/type.h>
#include <arrow/builder.h>
#include <arrow/record_batch.h>

#include "../src/common/arrow-utils.h"

#include "test_schemas.h"

namespace fletcher {
namespace test {

std::shared_ptr<arrow::Schema> genListUint8Schema() {
  std::vector<std::shared_ptr<arrow::Field>> schema_fields = {
      arrow::field("list", arrow::list(std::make_shared<arrow::Field>("uint8", arrow::uint8(), false)), false)
  };

  auto schema = std::make_shared<arrow::Schema>(schema_fields,
                                                metaMode(fletcher::Mode::READ));

  return schema;
}

std::shared_ptr<arrow::Schema> genPrimReadSchema() {
  // Create a vector of fields that will form the schema.
  std::vector<std::shared_ptr<arrow::Field>> schema_fields = {
      arrow::field("primread", arrow::uint8(), false)
  };

  // Create the schema
  auto
      schema = std::make_shared<arrow::Schema>(schema_fields, metaMode(Mode::READ));

  return schema;
}

std::shared_ptr<arrow::Schema> genPrimWriteSchema() {
  // Create a vector of fields that will form the schema.
  std::vector<std::shared_ptr<arrow::Field>> schema_fields = {
      arrow::field("primwrite", arrow::uint8(), false)
  };

  // Create some metadata
  auto schema_meta = metaMode(Mode::WRITE);

  // Create the schema
  auto schema = std::make_shared<arrow::Schema>(schema_fields, schema_meta);

  return schema;
}

std::shared_ptr<arrow::Schema> genStringSchema() {
  // Create a vector of fields that will form the schema.
  std::vector<std::shared_ptr<arrow::Field>> schema_fields = {
      arrow::field("Name", arrow::utf8(), false, metaEPC(4))
  };

  // Create some metadata
  auto schema_meta = metaMode(Mode::READ);

  // Create the schema
  auto schema = std::make_shared<arrow::Schema>(schema_fields, schema_meta);

  return schema;
}

std::shared_ptr<arrow::Schema> genStructSchema() {
  std::vector<std::shared_ptr<arrow::Field>> struct_fields = {
      arrow::field("Prim A", arrow::uint16(), false),
      arrow::field("Prim B", arrow::uint32(), false),
  };

  std::vector<std::shared_ptr<arrow::Field>> schema_fields = {
      arrow::field("Struct", arrow::struct_(struct_fields), false)
  };

  auto schema = std::make_shared<arrow::Schema>(schema_fields, metaMode(Mode::READ));

  return schema;

}

std::shared_ptr<arrow::Schema> genBigSchema() {
  std::vector<std::shared_ptr<arrow::Field>> struct_fields = {
      arrow::field("Prim A", arrow::uint16(), false),
      arrow::field("Prim B", arrow::uint32(), false),
      arrow::field("String", arrow::utf8(), false, metaEPC(4))
  };

  std::vector<std::shared_ptr<arrow::Field>> struct2_fields = {
      arrow::field("Prim", arrow::uint64(), false),
      arrow::field("Struct", arrow::struct_(struct_fields), false)
  };

  std::vector<std::shared_ptr<arrow::Field>> schema_fields = {
      arrow::field("Prim", arrow::uint8(), false, metaEPC(4)),
      arrow::field("ListOfFloat", arrow::list(arrow::float64()), false),
      arrow::field("Binary", arrow::binary(), false),
      arrow::field("FixedSizeBinary", arrow::fixed_size_binary(5)),
      arrow::field("Decimal", arrow::decimal(20, 18)),
      arrow::field("String", arrow::utf8(), false, metaEPC(8)),
      arrow::field("Struct", arrow::struct_(struct2_fields), false),
      arrow::field("IgnoreMe", arrow::utf8(), false, metaIgnore())
  };

  auto
      schema = std::make_shared<arrow::Schema>(schema_fields, metaMode(Mode::READ));

  return schema;
}

std::shared_ptr<arrow::Schema> genPairHMMSchema() {

  // Create the struct datatype
  auto strct = arrow::struct_({arrow::field("Basepairs", arrow::uint8(), false),
                               arrow::field("Probabilities", arrow::fixed_size_binary(32), false)
                              });
  // Create the schema fields vector
  std::vector<std::shared_ptr<arrow::Field>> schema_fields = {
      arrow::field("Haplotype", arrow::binary(), false),
      arrow::field("Read", arrow::list(arrow::field("Item", strct, false)), false)
  };

  auto schema = std::make_shared<arrow::Schema>(schema_fields,
                                                metaMode(Mode::READ));

  return schema;
}

}
}
