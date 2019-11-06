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

#include <cerata/api.h>

#include <string>
#include <unordered_map>
#include <memory>
#include <vector>
#include <utility>

#include "fletchgen/kernel.h"
#include "fletchgen/bus.h"
#include "fletchgen/nucleus.h"

namespace fletchgen {

using cerata::Instance;

/**
 * @brief A component that wraps a Kernel and all ArrayReaders/Writers resulting from a Schema set.
 */
class Mantle : public Component {
 public:
  /// @brief Construct a Mantle based on a SchemaSet
  explicit Mantle(std::string name,
                  const std::vector<std::shared_ptr<RecordBatch>> &recordbatches,
                  const std::shared_ptr<Nucleus> &nucleus,
                  BusDim bus_dim);
  /// @brief Return the kernel component of this Mantle.
  std::shared_ptr<Nucleus> nucleus() const { return nucleus_; }
  /// @brief Return all RecordBatch(Reader/Writer) instances of this Mantle.
  std::vector<Instance *> recordbatch_instances() const { return recordbatch_instances_; }
  /// @brief Return all RecordBatch(Reader/Writer) components of this Mantle.
  std::vector<std::shared_ptr<RecordBatch>> recordbatch_components() const { return recordbatch_components_; }

 protected:
  /// Top-level bus dimensions.
  BusDim bus_dim_;
  /// The Nucleus to be instantiated by this Mantle.
  std::shared_ptr<Nucleus> nucleus_;
  /// Shortcut to the instantiated Nucleus.
  Instance *nucleus_inst_;
  /// The RecordBatch instances.
  std::vector<Instance *> recordbatch_instances_;
  /// The RecordBatch components.
  std::vector<std::shared_ptr<RecordBatch>> recordbatch_components_;
  /// A mapping of bus port (containing the bus parameters and function) to arbiter instances.
  std::unordered_map<BusPort *, Instance *> arbiters_;
};

/**
 * @brief Construct the mantle component and return a shared pointer to it.
 * @param name          The name of the mantle.
 * @param recordbatches The RecordBatch components to instantiate.
 * @param nucleus       The Nucleus to instantiate.
 * @param bus_spec      The specification of the top-level bus.
 * @return              A shared pointer to the mantle component.
 */
std::shared_ptr<Mantle> mantle(const std::string &name,
                               const std::vector<std::shared_ptr<RecordBatch>> &recordbatches,
                               const std::shared_ptr<Nucleus> &nucleus,
                               BusDim bus_spec);

}  // namespace fletchgen
