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
#include <vector>
#include <utility>

#include "./stream/stream.h"

namespace fletchgen {

class Design {
 public:
  explicit Design(std::vector<std::shared_ptr<arrow::Schema>> schemas)
      : configs(config::fromSchemas(schemas)), schemas_(std::move(schemas)) {

  }

  std::shared_ptr<arrow::Schema> schema(int i) { return schemas_[i]; }
 private:
  std::vector<config::Config> configs;
  std::vector<std::shared_ptr<arrow::Schema>> schemas_;
};

}