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
#include <utility>
#include <vector>

#include "../../../common/cpp/src/fletcher/common/arrow-utils.h"

#include "./types.h"
#include "./graphs.h"
#include "./fletcher_types.h"

namespace fletchgen {

using TypeList = std::deque<std::shared_ptr<Type>>;
using ArrowFieldList = std::deque<std::shared_ptr<arrow::Field>>;

std::shared_ptr<Type> GetStreamType(const std::shared_ptr<arrow::Field> &field, int level = 0);

/**
 * @brief A port derived from an Arrow field
 */
struct ArrowPort : public Port {
  std::shared_ptr<arrow::Field> field_;
  ArrowPort(std::string name, std::shared_ptr<arrow::Field> field, Port::Dir dir);
  static std::shared_ptr<ArrowPort> Make(std::shared_ptr<arrow::Field> field, Port::Dir dir);
};

/**
 * @brief A named set of schemas.
 */
struct SchemaSet : public Named {
  std::deque<std::shared_ptr<arrow::Schema>> schema_list_;

  SchemaSet(std::string name, std::deque<std::shared_ptr<arrow::Schema>> schema_list)
      : Named(std::move(name)), schema_list_(std::move(schema_list)) {}

  static std::shared_ptr<SchemaSet> Make(std::string name, std::deque<std::shared_ptr<arrow::Schema>> schema_list);
};

/**
 * @brief The UserCore component to be implemented by the user
 */
struct UserCore : Component {
  std::shared_ptr<SchemaSet> schema_set_;

  explicit UserCore(std::string name, std::shared_ptr<SchemaSet> schemas);
  static std::shared_ptr<UserCore> Make(std::shared_ptr<SchemaSet> schemas);

  std::shared_ptr<ArrowPort> GetArrowPort(std::shared_ptr<arrow::Field> field);
  std::deque<std::shared_ptr<ArrowPort>> GetAllArrowPorts();
};

/**
 * @brief A FletcherCore component that instantiates all ColumnReaders/Writers resulting from a Schema set.
 */
struct FletcherCore : Component {
  std::shared_ptr<UserCore> user_core_;
  std::shared_ptr<Instance> user_core_inst_;
  std::shared_ptr<SchemaSet> schema_set_;

  std::vector<std::shared_ptr<Instance>> column_readers;
  std::vector<std::shared_ptr<Instance>> column_writers;

  explicit FletcherCore(std::string name, const std::shared_ptr<SchemaSet> &schema_set);
  static std::shared_ptr<FletcherCore> Make(std::string name, const std::shared_ptr<SchemaSet> &schema_set);
  static std::shared_ptr<FletcherCore> Make(const std::shared_ptr<SchemaSet> &schema_set);
};

std::shared_ptr<Component> BusReadArbiter();
std::shared_ptr<Component> ColumnReader();

}  // namespace fletchgen
