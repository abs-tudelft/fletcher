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

#include <deque>
#include <string>
#include <memory>

#include "fletchgen/schema.h"
#include "fletchgen/recordbatch.h"

namespace fletchgen {

using cerata::Port;
using cerata::Component;

/// Fletchgen metadata for mmio-controlled kernel ports.
constexpr char MMIO_KERNEL[] = "fletchgen_mmio_kernel";
/// Fletchgen metadata for mmio-controlled buffer address ports.
constexpr char MMIO_BUFFER[] = "fletchgen_mmio_buffer";

/**
 * @brief The Kernel component to be implemented by the user
 */
struct Kernel : Component {
  /// @brief Construct a new kernel.
  explicit Kernel(std::string name, Component *nucleus);

  /// @brief Make a kernel component based on RecordBatch components. Returns a shared pointer to the new Kernel.
  static std::shared_ptr<Kernel> Make(const std::string &name, Component *nucleus);
};

}  // namespace fletchgen
