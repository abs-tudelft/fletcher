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
#include <fletcher/common.h>

#include <vector>
#include <string>
#include <memory>

#include "fletchgen/schema.h"
#include "fletchgen/recordbatch.h"

namespace fletchgen {

using cerata::Port;
using cerata::Component;

/**
 * @brief The Kernel component to be implemented by the user
 */
struct Kernel : Component {
  /// @brief Construct a new kernel.
  explicit Kernel(std::string name,
                  const std::vector<std::shared_ptr<RecordBatch>> &recordbatches,
                  const std::shared_ptr<Component> &mmio);
};

/**
 * @brief Make a kernel component based on RecordBatch and MMIO components.
 * @param name          The name of the kernel.
 * @param recordbatches The recordbatch components to base the kernel on.
 * @param mmio          The MMIO component to base the kernel on.
 * @return              A shared pointer to the new kernel component.
 */
std::shared_ptr<Kernel> kernel(const std::string& name,
                               const std::vector<std::shared_ptr<RecordBatch>> &recordbatches,
                               const std::shared_ptr<Component> &mmio);

}  // namespace fletchgen
