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
#include <vector>
#include <string>
#include <memory>

#include "fletchgen/schema.h"
#include "fletchgen/recordbatch.h"
#include "fletchgen/kernel.h"
#include "fletchgen/array.h"
#include "fletchgen/mmio.h"

namespace fletchgen {

using cerata::Port;
using cerata::Component;

/// @brief Return the ArrayCmdCtrlMerger component.
Component *accm();

/// @brief It's like a kernel, but there is a kernel inside.
struct Nucleus : Component {
  /// @brief Construct a new Nucleus.
  explicit Nucleus(const std::string &name,
                   const std::vector<std::shared_ptr<RecordBatch>> &recordbatches,
                   const std::shared_ptr<Kernel> &kernel,
                   const std::shared_ptr<Component> &mmio);

  /// @brief Return all field-derived ports with a specific function.
  std::vector<FieldPort *> GetFieldPorts(FieldPort::Function fun) const;

  /// @brief Profile any Arrow data streams that require profiling.
  void ProfileDataStreams(Instance *mmio_inst);

  /// The kernel component.
  std::shared_ptr<Kernel> kernel;
  /// The kernel instance.
  Instance *kernel_inst;
};

/// @brief Make an Nucleus component based on RecordBatch components. Returns a shared pointer to the new Nucleus.
std::shared_ptr<Nucleus> nucleus(const std::string &name,
                                 const std::vector<std::shared_ptr<RecordBatch>> &recordbatches,
                                 const std::shared_ptr<Kernel> &kernel,
                                 const std::shared_ptr<Component> &mmio);

}  // namespace fletchgen
