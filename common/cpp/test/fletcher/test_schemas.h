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

#pragma once

#include <fletcher/common.h>

#include <arrow/api.h>
#include <memory>
#include <vector>
#include <string>

namespace fletcher {

inline std::shared_ptr<arrow::Schema> GetListUint8Schema() {
  std::vector<std::shared_ptr<arrow::Field>> schema_fields = {
      arrow::field("L", arrow::list(std::make_shared<arrow::Field>("number", arrow::uint8(), false)), false)
  };

  auto schema = std::make_shared<arrow::Schema>(schema_fields);
  return WithMetaRequired(*schema, "ListUint8", Mode::READ);
}

inline std::shared_ptr<arrow::Schema> GetPrimReadSchema() {
  // Create a vector of fields that will form the schema.
  std::vector<std::shared_ptr<arrow::Field>> schema_fields = {
      WithMetaProfile(*arrow::field("number", arrow::int8(), false))
  };
  auto schema = std::make_shared<arrow::Schema>(schema_fields);
  return WithMetaRequired(*schema, "PrimRead", Mode::READ);
}

inline std::shared_ptr<arrow::Schema> GetPrimWriteSchema() {
  std::vector<std::shared_ptr<arrow::Field>> schema_fields = {
      WithMetaProfile(*arrow::field("number", arrow::uint8(), false))
  };
  auto schema = std::make_shared<arrow::Schema>(schema_fields);
  return WithMetaRequired(*schema, "PrimWrite", Mode::WRITE);
}

inline std::shared_ptr<arrow::Schema> GetTwoPrimReadSchema() {
  // Create a vector of fields that will form the schema.
  std::vector<std::shared_ptr<arrow::Field>> schema_fields = {
      WithMetaProfile(*arrow::field("A", arrow::int8(), false)),
      WithMetaProfile(*arrow::field("B", arrow::int8(), false))
  };
  auto schema = std::make_shared<arrow::Schema>(schema_fields);
  return WithMetaRequired(*schema, "R", Mode::READ);
}

inline std::shared_ptr<arrow::Schema> GetTwoPrimWriteSchema() {
  // Create a vector of fields that will form the schema.
  std::vector<std::shared_ptr<arrow::Field>> schema_fields = {
      WithMetaProfile(*arrow::field("C", arrow::int8(), false)),
      WithMetaProfile(*arrow::field("D", arrow::int8(), false))
  };
  auto schema = std::make_shared<arrow::Schema>(schema_fields);
  return WithMetaRequired(*schema, "W", Mode::WRITE);
}

inline std::shared_ptr<arrow::Schema> GetNullablePrimReadSchema() {
  // Create a vector of fields that will form the schema.
  std::vector<std::shared_ptr<arrow::Field>> schema_fields = {
      arrow::field("number", arrow::int8(), true)
  };
  auto schema = std::make_shared<arrow::Schema>(schema_fields);
  return WithMetaRequired(*schema, "PrimRead", Mode::READ);
}

inline std::shared_ptr<arrow::Schema> GetStringReadSchema() {
  auto name_field = WithMetaEPC(*arrow::field("Name", arrow::utf8(), false), 4);
  std::vector<std::shared_ptr<arrow::Field>> schema_fields = {name_field};
  auto schema = std::make_shared<arrow::Schema>(schema_fields);
  return WithMetaRequired(*schema, "StringRead", Mode::READ);
}

inline std::shared_ptr<arrow::Schema> GetStringWriteSchema() {
  auto string_field = arrow::field("String", arrow::utf8(), false);
  string_field = WithMetaEPC(*string_field, 64);
  std::vector<std::shared_ptr<arrow::Field>> schema_fields = {string_field};
  auto schema = std::make_shared<arrow::Schema>(schema_fields);
  return WithMetaRequired(*schema, "StringWrite", Mode::WRITE);
}

inline std::shared_ptr<arrow::Schema> GetStructSchema() {
  std::vector<std::shared_ptr<arrow::Field>> struct_fields = {
      arrow::field("A", arrow::uint16(), false),
      arrow::field("B", arrow::uint32(), false),
  };
  std::vector<std::shared_ptr<arrow::Field>> schema_fields = {
      arrow::field("S", arrow::struct_(struct_fields), false)
  };
  return WithMetaRequired(*std::make_shared<arrow::Schema>(schema_fields), "StructBatch", Mode::READ);
}

inline std::shared_ptr<arrow::Schema> GetBigSchema() {
  std::vector<std::shared_ptr<arrow::Field>> struct_fields = {
      arrow::field("Xuint16", arrow::uint16(), false),
      arrow::field("Yuint32", arrow::uint32(), false),
      WithMetaEPC(*arrow::field("Zutf8", arrow::utf8(), false), 4)
  };
  std::vector<std::shared_ptr<arrow::Field>> struct2_fields = {
      arrow::field("Quint64", arrow::uint64(), false),
      arrow::field("Rstruct", arrow::struct_(struct_fields), false)
  };
  std::vector<std::shared_ptr<arrow::Field>> schema_fields = {
      WithMetaEPC(*arrow::field("Auint8", arrow::uint8(), false), 4),
      arrow::field("Blist", arrow::list(arrow::float64()), false),
      arrow::field("Cbinary", arrow::binary(), false),
      WithMetaEPC(*arrow::field("Dutf8", arrow::utf8(), false), 8),
      arrow::field("Estruct", arrow::struct_(struct2_fields), false),
      WithMetaIgnore(*arrow::field("Fignore", arrow::utf8(), false))
      // arrow::field("G", arrow::fixed_size_binary(5)),
      // arrow::field("H", arrow::decimal(20, 18)),
  };
  auto schema = std::make_shared<arrow::Schema>(schema_fields);
  return WithMetaRequired(*schema, "Big", Mode::READ);
}

inline std::shared_ptr<arrow::Schema> GetListFloatSchema() {
  std::vector<std::shared_ptr<arrow::Field>> schema_fields = {
      arrow::field("ListOfFloat", arrow::list(arrow::float64()), false),
  };
  auto schema = std::make_shared<arrow::Schema>(schema_fields);
  return WithMetaRequired(*schema, "ListFloat", Mode::READ);
}

inline std::shared_ptr<arrow::Schema> GetListIntSchema() {
  std::vector<std::shared_ptr<arrow::Field>> schema_fields = {
      arrow::field("ListOfNumber", arrow::list(arrow::int64()), false),
  };
  auto schema = std::make_shared<arrow::Schema>(schema_fields);
  return WithMetaRequired(*schema, "ListInt", Mode::READ);
}

inline std::shared_ptr<arrow::Schema> GetFilterReadSchema() {
  std::vector<std::shared_ptr<arrow::Field>> schema_fields = {
      arrow::field("read_first_name", arrow::utf8(), false),
      arrow::field("read_last_name", arrow::utf8(), false),
      arrow::field("read_zipcode", arrow::uint32(), false)
  };
  auto schema = std::make_shared<arrow::Schema>(schema_fields);
  return WithMetaRequired(*schema, "FilterRead", Mode::READ);
}

inline std::shared_ptr<arrow::Schema> GetFilterWriteSchema() {
  std::vector<std::shared_ptr<arrow::Field>> schema_fields = {
      arrow::field("write_first_name", arrow::utf8(), false),
  };
  auto schema = std::make_shared<arrow::Schema>(schema_fields);
  return WithMetaRequired(*schema, "FilterWrite", Mode::WRITE);
}

inline std::shared_ptr<arrow::Schema> GetSodaBeerSchema(const std::string &name = "", Mode mode = Mode::READ) {
  std::vector<std::shared_ptr<arrow::Field>> schema_fields = {
      arrow::field("name", arrow::utf8(), false),
      arrow::field("age", arrow::uint8(), false)
  };
  auto schema = std::make_shared<arrow::Schema>(schema_fields);
  auto fletcher_schema = WithMetaRequired(*schema, name, mode);
  return fletcher_schema;
}

}  // namespace fletcher
