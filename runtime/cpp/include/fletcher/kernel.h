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

/// The Kernel class is used to manage the computational kernel of the accelerator.
class Kernel {
 public:
  /**
   * @brief Construct a new kernel that can operate within a specific context.
   * @param[in] context The context to operate in.
   */
  explicit Kernel(std::shared_ptr<Context> context);

  /**
   * @brief Returns true if the kernel implements an operation over a set of arrow::Schemas. Not implemented.
   * @param[in] schema_set A vector of shared pointers to arrow::Schemas to check.
   * @return Returns true if the kernel implements an operation over a set of arrow::Schemas.
   */
  bool ImplementsSchemaSet(const std::vector<std::shared_ptr<arrow::Schema>> &schema_set);

  /**
   * @brief Reset the Kernel.
   * @return Status::OK() if successful, otherwise a descriptive error status.
   */
  Status Reset();

  /**
   * @brief Set the first (inclusive) and last (exclusive) row to process of some RecordBatch.
   * @param[in] recordbatch_index The index of the RecordBatch to set the range for.
   * @param[in] first             The first index of the range (inclusive).
   * @param[in] last              The last index of the range (exclusive).
   * @return Status::OK() if successful, otherwise a descriptive error status.
   */
  Status SetRange(size_t recordbatch_index, int32_t first, int32_t last);

  /**
   * @brief Set custom arguments to the kernel. Writes consecutive MMIO registers starting from custom register offset.
   * @param[in] arguments A vector of arguments to write.
   * @return Status::OK() if successful, otherwise a descriptive error status.
   */
  Status SetArguments(const std::vector<uint32_t> &arguments);

  /**
   * @brief Start the kernel.
   * @return Status::OK() if successful, otherwise a descriptive error status.
   */
  Status Start();

  /**
   * @brief Read the status register of the Kernel.
   * @param[out] status_out A pointer to a value to store the status.
   * @return Status::OK() if successful, otherwise a descriptive error status.
   */
  Status GetStatus(uint32_t *status_out);

  /**
   * @brief Read the return registers of the Kernel. If ret1 is nullptr, REG_RETURN1 is ignored.
   * @param[out] ret0 A pointer to a value to store return value 0.
   * @param[out] ret1 A pointer to a value to store return value 1.
   * @return Status::OK() if successful, otherwise a descriptive error status.
   */
  Status GetReturn(uint32_t *ret0, uint32_t *ret1 = nullptr);

  /**
   * @brief Wait for the kernel to finish (blocking).
   * @param[in] poll_interval_usec The interval at which to poll the Kernel.
   * @return Status::OK() when the kernel is finished, otherwise a descriptive error status.
   */
  Status WaitForFinish(unsigned int poll_interval_usec);

  /**
   * @brief Wait for the kernel to finish (blocking). Polls at maximum speed.
   * @return Status::OK() when the kernel is finished, otherwise a descriptive error status.
   */
  Status WaitForFinish();

  /// @brief Return the context of this Kernel.
  std::shared_ptr<Context> context();

  /**
   * @brief Write RecordBatch metadata from the Context to the Kernel MMIO registers.
   * @return Status::OK() if successful, otherwise a descriptive error status.
   */
  Status WriteMetaData();

  // Default control and status values:
  /// Control register start command value.
  uint32_t ctrl_start = 1ul << FLETCHER_REG_CONTROL_START;
  /// Control register reset command value.
  uint32_t ctrl_reset = 1ul << FLETCHER_REG_CONTROL_RESET;
  /// Status register done value.
  uint32_t done_status = 1ul << FLETCHER_REG_STATUS_DONE;
  /// Status register done mask bits.
  uint32_t done_status_mask = 1ul << FLETCHER_REG_STATUS_DONE;

 protected:
  /// Whether RecordBatch metadata was written.
  bool metadata_written = false;
  /// The context that this kernel should operate on.
  std::shared_ptr<Context> context_;
};

}  // namespace fletcher
