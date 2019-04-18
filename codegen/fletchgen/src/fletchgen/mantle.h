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

#include "kernel.h"

namespace fletchgen {

using cerata::Instance;

/**
 * @brief A component that wraps a Kernel and all ArrayReaders/Writers resulting from a Schema set.
 */
struct Mantle : Component {
  /// The Kernel to be instantiated by this Mantle
  std::shared_ptr<Kernel> kernel_;
  /// The actual instantiated Kernel
  Instance *kernel_inst_;
  /// The schema set on which this Mantle is based
  std::shared_ptr<SchemaSet> schema_set_;

  /// The RecordBatchReader instances
  std::vector<Instance *> readers_;
  /// The ArrayWriter instances
  std::vector<Instance *> writers_;

  /// @brief Construct a Mantle based on a SchemaSet
  explicit Mantle(std::string name, std::shared_ptr<SchemaSet> schema_set);

  /// @brief Construct a Mantle and return a shared pointer to it.
  static std::shared_ptr<Mantle> Make(std::string name, const std::shared_ptr<SchemaSet> &schema_set);
  /// @brief Construct a Mantle and return a shared pointer to it.
  static std::shared_ptr<Mantle> Make(const std::shared_ptr<SchemaSet> &schema_set);
};

}  // namespace fletchgen
