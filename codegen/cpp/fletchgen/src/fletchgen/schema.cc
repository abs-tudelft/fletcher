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

#include "fletchgen/schema.h"

#include <fletcher/common.h>

#include <string>
#include <algorithm>
#include <memory>
#include <utility>
#include <vector>
#include <optional>

#include "fletchgen/bus.h"

namespace fletchgen {

SchemaSet::SchemaSet(std::string name) : Named(std::move(name)) {}

std::shared_ptr<SchemaSet> SchemaSet::Make(const std::string &name) {
  return std::make_shared<SchemaSet>(name);
}

bool SchemaSet::RequiresReading() const {
  for (const auto &fs : schemas_) {
    if (fs->mode() == fletcher::Mode::READ) {
      return true;
    }
  }
  return false;
}

bool SchemaSet::RequiresWriting() const {
  for (const auto &fs : schemas_) {
    if (fs->mode() == fletcher::Mode::WRITE) {
      return true;
    }
  }
  return false;
}

bool SchemaSet::HasSchemaWithName(const std::string &name) const {
  for (const auto &fs : schemas_) {
    if (fs->name() == name) {
      return true;
    }
  }
  return false;
}

void SchemaSet::AppendSchema(const std::shared_ptr<arrow::Schema> &arrow_schema) {
  auto name = fletcher::GetMeta(*arrow_schema, fletcher::meta::NAME);
  if (name.empty()) {
    FLETCHER_LOG(WARNING, "Skipping anonymous schema with the following contents:\n" + arrow_schema->ToString());
    FLETCHER_LOG(WARNING, "Append {'fletcher_name' : '<name>'} kv-metadata to the schema "
                          "to include this schema in hardware generation.");
    return;
  }
  if (!HasSchemaWithName(name)) {
    auto fs = std::make_shared<FletcherSchema>(arrow_schema);
    schemas_.push_back(fs);
  } else {
    // If a schema with this name already exists. If so, check if its equal.
    auto other = GetSchema(name);
    if ((*other)->arrow_schema()->Equals(*arrow_schema)) {
      FLETCHER_LOG(INFO, "Duplicate but equal schema in SchemaSet: " + name);
    }
  }
}
std::optional<std::shared_ptr<FletcherSchema>> SchemaSet::GetSchema(const std::string &name) const {
  for (const auto &fs : schemas_) {
    if (fs->name() == name) {
      return fs;
    }
  }
  return std::nullopt;
}

std::vector<std::shared_ptr<FletcherSchema>> SchemaSet::read_schemas() const {
  std::vector<std::shared_ptr<FletcherSchema>> ret;
  for (const auto &s : schemas_) {
    if (s->mode() == Mode::READ) {
      ret.push_back(s);
    }
  }
  return ret;
}

std::vector<std::shared_ptr<FletcherSchema>> SchemaSet::write_schemas() const {
  std::vector<std::shared_ptr<FletcherSchema>> ret;
  for (const auto &s : schemas_) {
    if (s->mode() == Mode::WRITE) {
      ret.push_back(s);
    }
  }
  return ret;
}

void SchemaSet::Sort() {
  struct {
    bool operator()(const std::shared_ptr<FletcherSchema> &a, const std::shared_ptr<FletcherSchema> &b) {
      return a->name() < b->name();
    }
  } NameSort;

  struct {
    bool operator()(const std::shared_ptr<FletcherSchema> &a, const std::shared_ptr<FletcherSchema> &b) {
      if (a->mode() == b->mode()) {
        return false;
      } else if (a->mode() == Mode::WRITE) {
        return false;
      }
      return true;
    }
  } ModeSort;

  // Sort the schemas by name, then by mode
  std::sort(schemas_.begin(), schemas_.end(), NameSort);
  // Important to keep stable sorting here, else we might lose name order.
  std::stable_sort(schemas_.begin(), schemas_.end(), ModeSort);
}

FletcherSchema::FletcherSchema(const std::shared_ptr<arrow::Schema> &arrow_schema, const std::string &schema_name)
    : arrow_schema_(arrow_schema), mode_(fletcher::GetMode(*arrow_schema)) {

  // Get name from metadata, if available
  name_ = fletcher::GetMeta(*arrow_schema_, fletcher::meta::NAME);
  if (name_.empty()) {
    FLETCHER_LOG(FATAL, "Schema has no name. Append {'fletcher_name' : '<name>'} kv-metadata to the schema. "
                        "Schema: " + arrow_schema->ToString());
  }
  auto bus_spec_val = fletcher::GetMeta(*arrow_schema_, fletcher::meta::BUS_SPEC);
  bus_dims_ = BusDim::FromString(bus_spec_val, BusDim());
  FLETCHER_LOG(DEBUG, "Schema " + name() + ":");
  FLETCHER_LOG(DEBUG, "  Direction : " + cerata::Term::str(mode2dir(mode_)));
  FLETCHER_LOG(DEBUG, "  Bus spec  : " + bus_dims_.ToString());
}

std::shared_ptr<FletcherSchema> FletcherSchema::Make(const std::shared_ptr<arrow::Schema> &arrow_schema,
                                                     const std::string &schema_name) {
  return std::make_shared<FletcherSchema>(arrow_schema, schema_name);
}

}  // namespace fletchgen
