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

#include <fletcher/common.h>

#include "fletcher/test_schemas.h"

#include <arrow/api.h>
#include <memory>
#include <vector>

namespace fletcher {

std::shared_ptr<arrow::Schema> GetListUint8Schema() {
  std::vector<std::shared_ptr<arrow::Field>> schema_fields = {
      arrow::field("list", arrow::list(std::make_shared<arrow::Field>("number", arrow::uint8(), false)), false)
  };

  auto schema = std::make_shared<arrow::Schema>(schema_fields, metaMode(fletcher::Mode::READ));

  return schema;
}

std::shared_ptr<arrow::Schema> GetPrimReadSchema() {
  // Create a vector of fields that will form the schema.
  std::vector<std::shared_ptr<arrow::Field>> schema_fields = {
      arrow::field("number", arrow::uint8(), false)
  };
  auto schema = std::make_shared<arrow::Schema>(schema_fields, fletcher::MakeRequiredMeta("PrimRead", Mode::READ));
  return schema;
}

std::shared_ptr<arrow::Schema> GetPrimWriteSchema() {
  // Create a vector of fields that will form the schema.
  std::vector<std::shared_ptr<arrow::Field>> schema_fields = {
      arrow::field("number", arrow::uint8(), false)
  };
  // Create the schema
  auto schema = std::make_shared<arrow::Schema>(schema_fields, fletcher::MakeRequiredMeta("PrimWrite", Mode::WRITE));
  return schema;
}

std::shared_ptr<arrow::Schema> GetStringReadSchema() {
  std::vector<std::shared_ptr<arrow::Field>> schema_fields = {arrow::field("Name", arrow::utf8(), false, metaEPC(4))};
  auto schema = std::make_shared<arrow::Schema>(schema_fields, fletcher::MakeRequiredMeta("StringRead", Mode::READ));
  return schema;
}

std::shared_ptr<arrow::Schema> GetStringWriteSchema() {
  std::vector<std::shared_ptr<arrow::Field>> schema_fields = {arrow::field("Str", arrow::utf8(), false, metaEPC(64))};
  auto schema_meta = metaMode(Mode::WRITE);
  schema_meta->Append("fletcher_num_user_regs", "4");
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

std::shared_ptr<arrow::Schema> GetBigSchema() {
  std::vector<std::shared_ptr<arrow::Field>> struct_fields = {
      arrow::field("Xuint16", arrow::uint16(), false),
      arrow::field("Yuint32", arrow::uint32(), false),
      arrow::field("Zutf8", arrow::utf8(), false, metaEPC(4))
  };

  std::vector<std::shared_ptr<arrow::Field>> struct2_fields = {
      arrow::field("Quint64", arrow::uint64(), false),
      arrow::field("Rstruct", arrow::struct_(struct_fields), false)
  };

  std::vector<std::shared_ptr<arrow::Field>> schema_fields = {
      arrow::field("Auint8", arrow::uint8(), false, metaEPC(4)),
      arrow::field("Blist", arrow::list(arrow::float64()), false),
      arrow::field("Cbinary", arrow::binary(), false),
      arrow::field("Dutf8", arrow::utf8(), false, metaEPC(8)),
      arrow::field("Estruct", arrow::struct_(struct2_fields), false),
      arrow::field("Fignore", arrow::utf8(), false, metaIgnore())
      // arrow::field("G", arrow::fixed_size_binary(5)),
      // arrow::field("H", arrow::decimal(20, 18)),
  };

  auto schema = std::make_shared<arrow::Schema>(schema_fields, metaMode(Mode::READ));

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

  auto schema = std::make_shared<arrow::Schema>(schema_fields, metaMode(Mode::READ));

  return schema;
}

std::shared_ptr<arrow::Schema> genFloatListSchema() {
  std::vector<std::shared_ptr<arrow::Field>> schema_fields = {
      arrow::field("ListOfFloat", arrow::list(arrow::float64()), false),
  };

  auto schema = std::make_shared<arrow::Schema>(schema_fields, fletcher::metaMode(fletcher::Mode::READ));

  return schema;
}

std::shared_ptr<arrow::Schema> genIntListSchema() {
  std::vector<std::shared_ptr<arrow::Field>> schema_fields = {
      arrow::field("ListOfNumber", arrow::list(arrow::int64()), false),
  };

  auto schema = std::make_shared<arrow::Schema>(schema_fields, fletcher::metaMode(fletcher::Mode::READ));

  return schema;
}

std::shared_ptr<arrow::Schema> genFilterReadSchema() {
  std::vector<std::shared_ptr<arrow::Field>> schema_fields = {
      arrow::field("read_first_name", arrow::utf8(), false),
      arrow::field("read_last_name", arrow::utf8(), false),
      arrow::field("read_zipcode", arrow::uint32(), false)
  };
  auto schema = std::make_shared<arrow::Schema>(schema_fields, metaMode(Mode::READ));
  return schema;
}

std::shared_ptr<arrow::Schema> genFilterWriteSchema() {
  std::vector<std::shared_ptr<arrow::Field>> schema_fields = {
      arrow::field("write_first_name", arrow::utf8(), false),
  };
  auto schema = std::make_shared<arrow::Schema>(schema_fields, metaMode(Mode::WRITE));
  return schema;
}

}  // namespace fletcher
