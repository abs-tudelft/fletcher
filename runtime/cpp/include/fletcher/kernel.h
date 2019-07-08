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
#include <fletcher/fletcher.h>

#include <cstdint>
#include <vector>
#include <memory>

#include "fletcher/context.h"
#include "fletcher/platform.h"

namespace fletcher {

/**
 * @brief Abstract class for Kernel management
 */
class Kernel {
 public:
  explicit Kernel(std::shared_ptr<Context> context);

  /**
   * @brief Returns true if the kernel implements an operation over a set of arrow::Schemas. Not implemented.
   * @param[in] schema_set A vector of shared pointers to arrow::Schemas to check.
   * @return Returns true if the kernel implements an operation over a set of arrow::Schemas.
   */
  [[deprecated]] bool ImplementsSchemaSet(const std::vector<std::shared_ptr<arrow::Schema>> &schema_set);

  /// @brief Reset the Kernel
  Status Reset();

  /// @brief Set the first (inclusive) and last (exclusive) row to process
  Status SetRange(size_t recordbatch_index, int32_t first, int32_t last);

  /// @brief Set the parameters of the Kernel
  Status SetArguments(std::vector<uint32_t> arguments);

  /// @brief Start the Kernel
  Status Start();

  /// @brief Read the status register of the Kernel
  Status GetStatus(uint32_t *status);

  /// @brief Read the return registers of the Kernel. If ret1 is nullptr, REG_RETURN1 is ignored.
  Status GetReturn(uint32_t *ret0, uint32_t *ret1 = nullptr);

  /**
   * @brief A blocking function that waits for the Kernel to finish
   *
   * Polls with an interval of poll_interval_usec microseconds.
   */
  Status WaitForFinish(unsigned int poll_interval_usec);

  /**
   * @brief A blocking function that waits for the Kernel to finish
   *
   * Polls at maximum speed.
   */
  Status WaitForFinish();

  /// @brief Return the context of this Kernel
  std::shared_ptr<Context> context();

  /// @brief Write RecordBatch metadata from the context to the kernel MMIO registers.
  Status WriteMetaData();

  // Default control and status values:
  uint32_t ctrl_start = 1ul << FLETCHER_REG_CONTROL_START;
  uint32_t ctrl_reset = 1ul << FLETCHER_REG_CONTROL_RESET;
  uint32_t done_status = 1ul << FLETCHER_REG_STATUS_DONE;
  uint32_t done_status_mask = 1ul << FLETCHER_REG_STATUS_DONE;

 protected:
  bool metadata_written = false;
  /// @brief The context that this kernel should operate on.
  std::shared_ptr<Context> context_;
};

}
