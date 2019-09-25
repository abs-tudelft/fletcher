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
#include <fletcher/common.h>

#include <vector>
#include <deque>
#include <string>
#include <memory>

#include "fletchgen/schema.h"
#include "fletchgen/recordbatch.h"
#include "fletchgen/kernel.h"
#include "fletchgen/array.h"

namespace fletchgen {

using cerata::Port;
using cerata::Component;

/// @brief Merges the address of a command stream with the rest of the command stream.
struct ArrayCmdCtrlMerger : Component {
  ArrayCmdCtrlMerger();
};

/// @brief Create an instance of an ArrayCmdCtrlMerger.
std::unique_ptr<Instance> ArrayCmdCtrlMergerInstance(const std::string& name);

/// @brief It's like a kernel, but there is a kernel inside.
struct Nucleus : Component {
  /// @brief Construct a new Nucleus.
  explicit Nucleus(const std::string &name,
                   const std::deque<RecordBatch *> &recordbatches,
                   const std::vector<fletcher::RecordBatchDescription> &batch_desc);

  /// @brief Make an Nucleus component based on RecordBatch components. Returns a shared pointer to the new Nucleus.
  static std::shared_ptr<Nucleus> Make(const std::string &name,
                                       const std::deque<RecordBatch *> &recordbatches,
                                       const std::vector<fletcher::RecordBatchDescription> &batch_desc);

  std::shared_ptr<Kernel> kernel;
  Instance *kernel_inst;
};

}  // namespace fletchgen
