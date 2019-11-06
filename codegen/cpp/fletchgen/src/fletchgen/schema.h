// Copyright 2018-2019 Delft University of Technology
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

#include <arrow/api.h>
#include <cerata/api.h>

#include <memory>
#include <vector>
#include <optional>
#include <string>

#include "fletchgen/bus.h"
#include "fletchgen/utils.h"

namespace fletchgen {

using fletcher::Mode;

/**
 * An Arrow schema augmented with Fletcher specific data and functions.
 */
class FletcherSchema {
 public:
  /// @brief Construct a new Fletcher schema.
  explicit FletcherSchema(const std::shared_ptr<arrow::Schema> &arrow_schema, const std::string &schema_name = "");

  /**
   * @brief Make a new FletcherSchema, returning a shared pointer to it.
   * @param arrow_schema  The Arrow schema to derive this FletcherSchema from.
   * @param schema_name   The name of the FletcherSchema.
   * @return              A shared pointer to a new FletcherSchema.
   */
  static std::shared_ptr<FletcherSchema> Make(const std::shared_ptr<arrow::Schema> &arrow_schema,
                                              const std::string &schema_name = "");

  /// @brief Return the Arrow schema that this FletcherSchema was based on.
  [[nodiscard]] std::shared_ptr<arrow::Schema> arrow_schema() const { return arrow_schema_; }

  /// @brief Return the access mode of the RecordBatch this schema represents.
  [[nodiscard]] Mode mode() const { return mode_; }
  /// @brief Return the name of this FletcherSchema.
  [[nodiscard]] std::string name() const { return name_; }

 private:
  /// The Arrow schema this FletcherSchema is based on.
  std::shared_ptr<arrow::Schema> arrow_schema_;
  /// The access mode for the RecordBatch represented by this schema.
  Mode mode_;
  /// The name of this schema used to identify the components generated from it.
  std::string name_;
  /// The bus dimensions for the RecordBatch resulting from this schema.
  BusDim bus_dims_;
};

/**
 * @brief A named set of schemas.
 */
class SchemaSet : public cerata::Named {
 public:
  /// @brief SchemaSet constructor.
  explicit SchemaSet(std::string name);
  /// @brief Make a new, empty SchemaSet, and return a shared pointer to it.
  static std::shared_ptr<SchemaSet> Make(const std::string &name);
  /// @brief Determine whether any schema in this set requires reading from memory.
  [[nodiscard]] bool RequiresReading() const;
  /// @brief Determine whether any schema in this set requires writing to memory.
  [[nodiscard]] bool RequiresWriting() const;
  /// @brief Return true if set contains schema with some name, false otherwise.
  [[nodiscard]] bool HasSchemaWithName(const std::string &name) const;
  /// @brief Optionally return a schema with name, if it exists.
  [[nodiscard]] std::optional<std::shared_ptr<FletcherSchema>> GetSchema(const std::string &name) const;
  /// @brief Append a schema
  void AppendSchema(const std::shared_ptr<arrow::Schema> &schema);
  /// @brief Return all schemas of this schemaset.
  [[nodiscard]] std::vector<std::shared_ptr<FletcherSchema>> schemas() const { return schemas_; }
  /// @brief Return all schemas with read mode.
  [[nodiscard]] std::vector<std::shared_ptr<FletcherSchema>> read_schemas() const;
  /// @brief Return all schemas with write mode.
  [[nodiscard]] std::vector<std::shared_ptr<FletcherSchema>> write_schemas() const;
  /// @brief Sort the schemas by name, then by read/write mode.
  void Sort();

 private:
  /// @brief Schemas of RecordBatches.
  std::vector<std::shared_ptr<FletcherSchema>> schemas_;
};

}  // namespace fletchgen
