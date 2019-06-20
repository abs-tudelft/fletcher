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

#include <cerata/api.h>

#include <string>
#include <unordered_map>
#include <memory>
#include <deque>

#include "fletchgen/kernel.h"
#include "fletchgen/bus.h"

namespace fletchgen {

using cerata::Instance;

/**
 * @brief A component that wraps a Kernel and all ArrayReaders/Writers resulting from a Schema set.
 */
class Mantle : public Component {
 public:
  /// @brief Construct a Mantle and return a shared pointer to it.
  static std::shared_ptr<Mantle> Make(std::string name, const std::shared_ptr<SchemaSet> &schema_set);
  /// @brief Construct a Mantle and return a shared pointer to it.
  static std::shared_ptr<Mantle> Make(const std::shared_ptr<SchemaSet> &schema_set);

  /// @brief Return the SchemaSet on which this Mantle is based.
  std::shared_ptr<SchemaSet> schema_set() const { return schema_set_; }

  std::shared_ptr<Kernel> kernel() const { return kernel_; }
  std::deque<Instance *> recordbatch_instances() const { return recordbatch_instances_; }
  std::deque<std::shared_ptr<RecordBatch>> recordbatch_components() const { return recordbatch_components_; }

 protected:
  /// @brief Construct a Mantle based on a SchemaSet
  explicit Mantle(std::string name, std::shared_ptr<SchemaSet> schema_set);

  /// The Kernel to be instantiated by this Mantle.
  std::shared_ptr<Kernel> kernel_;
  /// Shortcut to the instantiated kernel.
  Instance *kernel_inst_;
  /// The schema set on which this Mantle is based.
  std::shared_ptr<SchemaSet> schema_set_;
  /// The bus arbiters instantiated by this mantle for a specific bus specification.
  std::unordered_map<BusSpec, Instance *> arbiters_;
  /// The RecordBatch instances.
  std::deque<Instance *> recordbatch_instances_;
  /// The RecordBatch components.
  std::deque<std::shared_ptr<RecordBatch>> recordbatch_components_;
};

}  // namespace fletchgen
