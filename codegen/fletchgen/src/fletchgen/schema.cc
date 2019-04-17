#include <utility>

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

#include "fletchgen/schema.h"

#include <memory>

namespace fletchgen {

SchemaSet::SchemaSet(std::string name, const std::deque<std::shared_ptr<arrow::Schema>>& schema_list)
    : Named(std::move(name)) {
  for (const auto &s : schema_list) {
    auto fs = std::make_shared<FletcherSchema>(s);
    if (fs->mode() == fletcher::Mode::READ) {
      read_schemas.push_back(fs);
    } else {
      write_schemas.push_back(fs);
    }
  }
}

std::shared_ptr<SchemaSet> SchemaSet::Make(std::string name, std::deque<std::shared_ptr<arrow::Schema>> schema_list) {
  return std::make_shared<SchemaSet>(name, schema_list);
}

std::shared_ptr<SchemaSet> SchemaSet::Make(std::string name,
                                           const std::vector<std::shared_ptr<arrow::Schema>> &schema_list) {
  std::deque<std::shared_ptr<arrow::Schema>> dq;
  for (const auto &schema : schema_list) {
    dq.push_back(schema);
  }
  return Make(std::move(name), dq);
}

FletcherSchema::FletcherSchema(const std::shared_ptr<arrow::Schema> &arrow_schema, const std::string &schema_name)
    : arrow_schema_(arrow_schema), mode_(fletcher::getMode(arrow_schema)) {
  // If no name given
  if (schema_name.empty()) {
    // Get name from metadata, if available
    name_ = fletcher::getMeta(arrow_schema_, "fletcher_name");
    if (name_.empty()) {
      name_ = "<AnonSchema>";
    }
  }
  // Show some debug information about the schema
  LOG(DEBUG, "Schema " + name() + ", Direction: " + cerata::Term::ToString(mode2dir(mode_)));
}
}  // namespace fletchgen
