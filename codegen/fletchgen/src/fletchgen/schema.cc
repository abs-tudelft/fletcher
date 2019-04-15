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

std::shared_ptr<SchemaSet> SchemaSet::Make(std::string name, std::deque<std::shared_ptr<arrow::Schema>> schema_list) {
  return std::make_shared<SchemaSet>(name, schema_list);
}

std::shared_ptr<SchemaSet> SchemaSet::Make(std::string name, std::vector<std::shared_ptr<arrow::Schema>> schema_list) {
  std::deque<std::shared_ptr<arrow::Schema>> dq;
  for (const auto& schema : schema_list) {
    dq.push_back(schema);
  }
  return Make(name, dq);
}

}  // namespace fletchgen
