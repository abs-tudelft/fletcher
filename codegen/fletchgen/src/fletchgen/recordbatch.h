#include <utility>

#include <utility>

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
#include <cerata/api.h>
#include <fletcher/common/api.h>

#include "fletchgen/utils.h"
#include "fletchgen/basic_types.h"

namespace fletchgen {

using cerata::Port;
using cerata::Component;
using cerata::Instance;
using fletcher::Mode;

/**
 * @brief A port derived from an Arrow field
 */
struct FieldPort : public Port {
  enum Function {
    ARROW,
    COMMAND
  } function_;

  std::shared_ptr<arrow::Field> field_;

  FieldPort(std::string name,
            Function function,
            std::shared_ptr<arrow::Field> field,
            std::shared_ptr<cerata::Type> type,
            Port::Dir dir)
      : Port(std::move(name), std::move(type), dir), function_(function), field_(std::move(field)) {}

  static std::shared_ptr<FieldPort> MakeArrowPort(std::shared_ptr<arrow::Field> field, Mode mode) {
    return std::make_shared<FieldPort>(field->name(), ARROW, field, GetStreamType(field, mode), mode2dir(mode));
  }

  static std::shared_ptr<FieldPort> MakeCommandPort(std::shared_ptr<arrow::Field> field, cerata::Term::Dir dir) {
    return std::make_shared<FieldPort>("cmd_" + field->name(), COMMAND, field, cmd(), dir);
  }
};

/**
 * @brief A RecordBatchReader aggregates ArrayReaders for a more clarified hierarchical view.
 *
 * It doesn't do anything in a functional sense, but some features that one might think of in the future are specifying
 * that fields should all be synchronized after supplying a single command stream to duplicate over all ArrayReaders.
 */
struct RecordBatchReader : public Component {
  RecordBatchReader(const std::string &name, const std::shared_ptr<arrow::Schema> &schema);
  static std::shared_ptr<RecordBatchReader> Make(std::string name, const std::shared_ptr<arrow::Schema> &schema) {
    return std::make_shared<RecordBatchReader>(name, schema);
  }
  std::shared_ptr<arrow::Schema> schema;
  std::shared_ptr<FieldPort> GetArrowPort(const std::shared_ptr<arrow::Field> &field);
  std::deque<std::shared_ptr<FieldPort>> GetFieldPorts(const std::optional<FieldPort::Function>& function={});
  std::deque<Instance*> readers_;
  std::deque<Instance*> writers_;
};

} // namespace fletchgen