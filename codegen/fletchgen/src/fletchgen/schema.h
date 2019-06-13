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

#include <memory>
#include <deque>
#include <optional>
#include <arrow/api.h>
#include <cerata/api.h>

#include "fletchgen/utils.h"

namespace fletchgen {

using fletcher::Mode;

/**
 * @brief An schema augmented with Fletcher specific functions and data
 */
class FletcherSchema {
 public:
  explicit FletcherSchema(const std::shared_ptr<arrow::Schema> &arrow_schema, const std::string &schema_name = "");
  static std::shared_ptr<FletcherSchema> Make(const std::shared_ptr<arrow::Schema> &arrow_schema,
                                              const std::string &schema_name = "") {
    return std::make_shared<FletcherSchema>(arrow_schema, schema_name);
  }
  std::shared_ptr<arrow::Schema> arrow_schema() const { return arrow_schema_; }
  Mode mode() const { return mode_; }
  std::string name() const { return name_; }
 private:
  std::shared_ptr<arrow::Schema> arrow_schema_;
  Mode mode_;
  std::string name_;
};

/**
 * @brief A named set of schemas.
 */
class SchemaSet : public cerata::Named {
 public:
  explicit SchemaSet(std::string name);
  static std::shared_ptr<SchemaSet> Make(std::string name);
  /// @brief Determine whether any schema in this set requires reading from memory.
  bool RequiresReading() const;
  /// @brief Determine whether any schema in this set requires writing to memory.
  bool RequiresWriting() const;
  /// @brief Return true if set contains schema with some name, false otherwise.
  bool HasSchemaWithName(const std::string& name) const;
  /// @brief Optionally return a schema with name, if it exists.
  std::optional<std::shared_ptr<FletcherSchema>> GetSchema(const std::string& name) const;
  /// @brief Append a schema
  void AppendSchema(std::shared_ptr<arrow::Schema> schema);
  /// @brief Return all schemas of this schemaset.
  std::deque<std::shared_ptr<FletcherSchema>> schemas() const { return schemas_; }
  /// @brief Return all schemas with read mode.
  std::deque<std::shared_ptr<FletcherSchema>> read_schemas() const;
  /// @brief Return all schemas with write mode.
  std::deque<std::shared_ptr<FletcherSchema>> write_schemas() const;
  /// @brief Sort the schemas by name, then by read/write mode.
  void Sort();
 private:
  /// @brief Schemas of RecordBatches.
  std::deque<std::shared_ptr<FletcherSchema>> schemas_;
};

}  // namespace fletchgen
