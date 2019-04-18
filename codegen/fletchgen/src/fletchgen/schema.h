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
#include <arrow/api.h>
#include <cerata/api.h>

#include "fletchgen/utils.h"

namespace fletchgen {

/**
 * @brief An schema augmented with Fletcher specific functions and data
 */
class FletcherSchema {
 public:
  explicit FletcherSchema(const std::shared_ptr<arrow::Schema> &arrow_schema, const std::string &schema_name = "");
  std::shared_ptr<arrow::Schema> arrow_schema() { return arrow_schema_; }
  fletcher::Mode mode() const { return mode_; }
  std::string name() const { return name_; }
 private:
  std::shared_ptr<arrow::Schema> arrow_schema_;
  fletcher::Mode mode_;
  std::string name_;
};

/**
 * @brief A named set of schemas.
 */
struct SchemaSet : public cerata::Named {
  SchemaSet(std::string name, const std::deque<std::shared_ptr<arrow::Schema>> &schema_list);
  static std::shared_ptr<SchemaSet> Make(std::string name, std::deque<std::shared_ptr<arrow::Schema>> schema_list);
  static std::shared_ptr<SchemaSet> Make(std::string name,
                                         const std::vector<std::shared_ptr<arrow::Schema>> &schema_list);
  /// @brief Schemas of RecordBatches to read from.
  std::deque<std::shared_ptr<FletcherSchema>> read_schemas;
  /// @brief Schemas of RecordBatches to write to.
  std::deque<std::shared_ptr<FletcherSchema>> write_schemas;
};

}  // namespace fletchgen
