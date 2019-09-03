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
#include <fletcher/common.h>

#include <utility>
#include <string>
#include <deque>
#include <memory>

#include "fletchgen/utils.h"
#include "fletchgen/basic_types.h"
#include "fletchgen/schema.h"
#include "fletchgen/bus.h"

namespace fletchgen {

using cerata::Port;
using cerata::Component;
using cerata::Instance;
using fletcher::Mode;
using cerata::default_domain;

/**
 * @brief A port derived from an Arrow field
 *
 * We currently derive ports with three different functions from Arrow fields;
 *  - a data port for reading/writing from/to Arrow Arrays.
 *  - a command port to issue a command to an ArrayReader/Writer .
 *  - an unlock port to know a command sent to an ArrayReader/Writer was completed.
 *
 * This structure just helps us remember what function the port has and from what field it was derived.
 * If a FlatType of the type of this port was marked with "array_data" in the Type metadata, it signifies that this
 * FlatType constitutes to the data width on an ArrayReader/Writer. I.e. the port is not a dvalid or last but some
 * other type concatenated onto the ArrayReader/Writer data output/input.
 */
struct FieldPort : public Port {
  /// Enumeration of FieldPort functions.
  enum Function {
    ARROW,      ///< Port with Arrow data
    COMMAND,    ///< Port to issue commands to the generated interface.
    UNLOCK      ///< Port that signals the kernel a command was completed.
  } function_;  ///< The function of this FieldPort.

  /// The Arrow field this port was derived from.
  std::shared_ptr<arrow::Field> field_;

  /**
   * @brief Construct a new port derived from an Arrow field.
   * @param name      The name of the field-derived port.
   * @param function  The function of the field-derived port.
   * @param field     The Arrow field to derive the port from.
   * @param type      The Cerata type of the port.
   * @param dir       The port direction.
   */
  FieldPort(std::string name,
            Function function,
            std::shared_ptr<arrow::Field> field,
            std::shared_ptr<cerata::Type> type,
            Port::Dir dir,
            std::shared_ptr<ClockDomain> domain)
      : Port(std::move(name), std::move(type), dir, std::move(domain)), function_(function), field_(std::move(field)) {}

  /**
   * @brief Construct a field-derived port for Arrow data.
   * @param fletcher_schema  The Fletcher-derived schema.
   * @param field            The Arrow field to derive the port from.
   * @param mode             The mode of the port, whether to read or write.
   * @param invert           Invert the direction of the port.
   * @param domain           The clock domain of this port.
   * @return                 A shared pointer to a new FieldPort.
   */
  static std::shared_ptr<FieldPort> MakeArrowPort(const FletcherSchema &fletcher_schema,
                                                  const std::shared_ptr<arrow::Field> &field,
                                                  Mode mode,
                                                  bool invert,
                                                  const std::shared_ptr<ClockDomain> &domain = default_domain());
  /**
   * @brief Construct a field-derived command port.
   * @param fletcher_schema  The Fletcher-derived schema.
   * @param field            The Arrow field to derive the port from.
   * @return                 A shared pointer to a new FieldPort.
   */
  static std::shared_ptr<FieldPort> MakeCommandPort(const FletcherSchema &fletcher_schema,
                                                    const std::shared_ptr<arrow::Field> &field,
                                                    const std::shared_ptr<ClockDomain> &domain = default_domain());

  /**
   * @brief Construct a field-derived unlock port.
   * @param fletcher_schema  The Fletcher-derived schema.
   * @param field            The Arrow field to derive the port from.
   * @return                 A shared pointer to a new FieldPort.
   */
  static std::shared_ptr<FieldPort> MakeUnlockPort(const FletcherSchema &fletcher_schema,
                                                   const std::shared_ptr<arrow::Field> &field,
                                                   const std::shared_ptr<ClockDomain> &domain = default_domain());

  /// @brief Create a deep-copy of the FieldPort.
  std::shared_ptr<Object> Copy() const override;

  /// @brief Return the width of the data of this field.
  std::shared_ptr<Node> data_width();
};

/**
 * @brief A RecordBatch aggregating ArrayReaders/Writers
 *
 * We implement this component to obtain a hardware structure that is logically consistent with the input of Fletchgen.
 * That is, the user supplies a Schema for each RecordBatch, and therefore it is logical to generate a level of
 * hierarchy representing the Schema itself.
 *
 * It doesn't do anything in a functional sense, but some features that one might think of in the future are:
 * - operate all ArrayReaders/Writers with a single Command stream.
 * - profile bus utilization at the RecordBatch level
 * - ...
 */
struct RecordBatch : public Component {
 public:
  /// @brief Make a new RecordBatch(Reader/Writer) component, based on a Fletcher schema.
  static std::shared_ptr<RecordBatch> Make(const std::shared_ptr<FletcherSchema> &fletcher_schema);

  /// @brief Obtain all ports derived from an Arrow field with a specific function.
  std::deque<std::shared_ptr<FieldPort>> GetFieldPorts(const std::optional<FieldPort::Function> &function = {}) const;
  /// @brief Obtain the data port derived from a specific Arrow field. Field must point to the exact same field object.
  std::shared_ptr<FieldPort> GetArrowPort(const arrow::Field &field) const;

  /// @brief Return the Fletcher schema this RecordBatch(Reader/Writer) is based on.
  std::shared_ptr<FletcherSchema> fletcher_schema() const { return fletcher_schema_; }
  /// @brief Return pointers to all Array(Reader/Writer) instances of this component.
  std::deque<Instance *> reader_instances() const { return array_instances_; }
  /// @brief Return the Fletcher schema this RecordBatch(Reader/Writer) is based on.
  std::deque<std::shared_ptr<BusPort>> bus_ports() const { return bus_ports_; }

 protected:
  /// @brief RecordBatch constructor.
  explicit RecordBatch(const std::shared_ptr<FletcherSchema> &fletcher_schema);

  /**
   * @brief Adds all ArrayReaders/Writers, unconcatenates ports and connects it to the top-level of this component.
   * @param fletcher_schema   A Fletcherized version of the Arrow Schema that this RecordBatch component will access.
   *
   * Fletcher's hardware implementation concatenates each subsignal of potentially multiple streams of an
   * ArrayReader/Writer onto a single subsignal. This function must unconcatenate these streams.
   */
  void AddArrays(const FletcherSchema &fletcher_schema);

  /// Fletcher schema implemented by this RecordBatch(Reader/Writer)
  std::shared_ptr<FletcherSchema> fletcher_schema_;
  /// Array(Readers/Writers) instantiated
  std::deque<Instance *> array_instances_ = {};
  /// Bus ports
  std::deque<std::shared_ptr<BusPort>> bus_ports_ = {};
  /// Mode
  Mode mode_ = Mode::READ;
};

}  // namespace fletchgen
