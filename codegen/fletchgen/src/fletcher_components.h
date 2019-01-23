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

#pragma once

#include <arrow/api.h>
#include <deque>
#include <memory>
#include <string>
#include <iostream>

#include "../../../common/cpp/src/fletcher/common/arrow-utils.h"

#include "./types.h"
#include "graphs.h"
#include "./fletcher_types.h"

namespace fletchgen {

std::shared_ptr<Type> GetStreamType(const std::shared_ptr<arrow::Field> &field, int level = 0);

struct UserCore : Component {
  using SchemaList = std::deque<std::shared_ptr<arrow::Schema>>;
  using TypeList = std::deque<std::shared_ptr<Type>>;
  using ArrowFieldList = std::deque<std::shared_ptr<arrow::Field>>;

  SchemaList schemas;

  explicit UserCore(std::string name, SchemaList schemas);
  static std::shared_ptr<UserCore> Make(SchemaList schemas);
};

std::shared_ptr<Component> BusReadArbiter();
std::shared_ptr<Component> ColumnReader();

}