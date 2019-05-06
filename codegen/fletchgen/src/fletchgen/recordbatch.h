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

#include <utility>
#include <arrow/api.h>
#include <cerata/api.h>
#include <fletcher/common/api.h>

#include "fletchgen/utils.h"
#include "fletchgen/basic_types.h"
#include "fletchgen/schema.h"

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

  static std::shared_ptr<FieldPort> MakeArrowPort(std::shared_ptr<arrow::Field> field, Mode mode, bool invert);
  static std::shared_ptr<FieldPort> MakeCommandPort(std::shared_ptr<arrow::Field> field, cerata::Term::Dir dir);

  /// @brief Return the width of the data of this field.
  std::shared_ptr<Node> data_width();
};

/**
 * @brief A RecordBatchReader aggregating ArrayReaders
 *
 * We implement this component to obtain a hardware structure that is logically consistent with the input of Fletchgen.
 * That is, the user supplies a Schema for each RecordBatch, and therefore it seems logical to generate a level of
 * hierarchy representing the Schema itself.
 *
 * It doesn't do anything in a functional sense, but some features that one might think of in the future are:
 * - operate all ArrayReaders with a single Command stream.
 * - profile at the RecordBatch level
 * - ...
 */
struct RecordBatchReader : public Component {
  std::shared_ptr<FletcherSchema> schema_;
  std::deque<Instance *> readers_;

  explicit RecordBatchReader(const std::shared_ptr<FletcherSchema> &fletcher_schema);

  void AddKernelSidePorts(const std::shared_ptr<arrow::Schema> &as, const Mode &mode);
  void AddBusInterfaces();

  static std::shared_ptr<RecordBatchReader> Make(const std::shared_ptr<FletcherSchema> &fletcher_schema);

  std::deque<std::shared_ptr<FieldPort>> GetFieldPorts(const std::optional<FieldPort::Function> &function = {});
  std::shared_ptr<FieldPort> GetArrowPort(const std::shared_ptr<arrow::Field> &field);

};

} // namespace fletchgen