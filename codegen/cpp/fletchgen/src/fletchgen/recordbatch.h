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

#pragma once

#include <arrow/api.h>
#include <cerata/api.h>
#include <fletcher/common.h>

#include <utility>
#include <string>
#include <vector>
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

  /// The Fletcher schema this port was derived from.
  std::shared_ptr<FletcherSchema> fletcher_schema_;
  /// The Arrow field this port was derived from.
  std::shared_ptr<arrow::Field> field_;
  /// Whether this field port should be profiled.
  bool profile_ = false;

  /**
   * @brief Construct a new port derived from an Arrow field.
   * @param name            The name of the field-derived port.
   * @param function        The function of the field-derived port.
   * @param field           The Arrow field to derive the port from.
   * @param fletcher_schema The Fletcher Schema.
   * @param type            The Cerata type of the port.
   * @param dir             The port direction.
   * @param domain          The clock domain.
   * @param profile         Whether this Field-derived Port should be profiled.
   */
  FieldPort(std::string name,
            Function function,
            std::shared_ptr<arrow::Field> field,
            std::shared_ptr<FletcherSchema> fletcher_schema,
            std::shared_ptr<cerata::Type> type,
            Port::Dir dir,
            std::shared_ptr<ClockDomain> domain,
            bool profile)
      : Port(std::move(name), std::move(type), dir, std::move(domain)),
        function_(function),
        fletcher_schema_(std::move(fletcher_schema)),
        field_(std::move(field)),
        profile_(profile) {}

  /// @brief Create a deep-copy of the FieldPort.
  std::shared_ptr<Object> Copy() const override;
};

/**
 * @brief Construct a field-derived port for Arrow data.
 * @param fletcher_schema  The Fletcher-derived schema.
 * @param field            The Arrow field to derive the port from.
 * @param reverse          Reverse the direction of the port.
 * @param domain           The clock domain of this port.
 * @return                 A shared pointer to a new FieldPort.
 */
std::shared_ptr<FieldPort> arrow_port(const std::shared_ptr<FletcherSchema> &fletcher_schema,
                                      const std::shared_ptr<arrow::Field> &field,
                                      bool reverse,
                                      const std::shared_ptr<ClockDomain> &domain = default_domain());
/**
 * @brief Construct a field-derived command port.
 * @param schema  The Fletcher-derived schema.
 * @param field            The Arrow field to derive the port from.
 * @param index_width      Type generic node for index field width.
 * @param tag_width        Type generic node for tag field width.
 * @param addr_width       Optionally, width of addresses in the ctrl field. If not used, no ctrl field is generated.
 * @param domain           The clock domain.
 * @return                 A shared pointer to a new FieldPort.
 */
std::shared_ptr<FieldPort> command_port(const std::shared_ptr<FletcherSchema> &schema,
                                        const std::shared_ptr<arrow::Field> &field,
                                        const std::shared_ptr<Node> &index_width,
                                        const std::shared_ptr<Node> &tag_width,
                                        std::optional<std::shared_ptr<Node>> addr_width = std::nullopt,
                                        const std::shared_ptr<ClockDomain> &domain = default_domain());

/**
 * @brief Construct a field-derived unlock port.
 * @param schema    The Fletcher-derived schema.
 * @param field     The Arrow field to derive the port from.
 * @param tag_width The width of the tag field.
 * @param domain    The clock domain.
 * @return          A shared pointer to a new FieldPort.
 */
std::shared_ptr<FieldPort> unlock_port(const std::shared_ptr<FletcherSchema> &schema,
                                       const std::shared_ptr<arrow::Field> &field,
                                       const std::shared_ptr<Node> &tag_width,
                                       const std::shared_ptr<ClockDomain> &domain = default_domain());

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
  /// @brief RecordBatch constructor.
  RecordBatch(const std::string &name,
              const std::shared_ptr<FletcherSchema> &fletcher_schema,
              fletcher::RecordBatchDescription batch_desc);
  /// @brief Obtain all ports derived from an Arrow field with a specific function.
  std::vector<std::shared_ptr<FieldPort>> GetFieldPorts(const std::optional<FieldPort::Function> &function = {}) const;
  /// @brief Return the description of the RecordBatch this component is based on.
  fletcher::RecordBatchDescription batch_desc() const { return batch_desc_; }
  /// @brief Return the Fletcher schema this RecordBatch component is based on.
  FletcherSchema *schema() { return fletcher_schema_.get(); }
  /// @brief Return the mode (read or write) of this RecordBatch.
  Mode mode() const { return mode_; }

 protected:
  /**
   * @brief Adds all ArrayReaders/Writers, un-concatenates ports and connects it to the top-level of this component.
   * @param fletcher_schema   A Fletcherized version of the Arrow Schema that this RecordBatch component will access.
   *
   * Fletcher's hardware implementation concatenates each sub-signal of potentially multiple streams of an
   * ArrayReader/Writer onto a single sub-signal. This function must un-concatenate these streams.
   */
  void AddArrays(const std::shared_ptr<FletcherSchema> &fletcher_schema);

  /// A mapping from ArrayReader/Writer instances to their bus ports.
  std::vector<Instance *> array_instances_;
  /// Fletcher schema implemented by this RecordBatch(Reader/Writer)
  std::shared_ptr<FletcherSchema> fletcher_schema_;
  /// Whether to read or write from/to the in-memoRecordBatch
  Mode mode_ = Mode::READ;
  /// The RecordBatch description.
  fletcher::RecordBatchDescription batch_desc_;

 private:
  void ConnectBusPorts(Instance *array, const std::string &prefix, cerata::NodeMap *rebinding);
};

/// @brief Make a new RecordBatch(Reader/Writer) component, based on a Fletcher schema.
std::shared_ptr<RecordBatch> record_batch(const std::string &name,
                                          const std::shared_ptr<FletcherSchema> &fletcher_schema,
                                          const fletcher::RecordBatchDescription &batch_desc);

}  // namespace fletchgen
