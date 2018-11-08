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

#include <cstdint>
#include <vector>
#include <memory>

#include <arrow/api.h>

#include "./context.h"
#include "./platform.h"

#include "fletcher/fletcher.h"

namespace fletcher {

/**
 * @brief Abstract class for UserCore management
 */
class UserCore {
 public:
  explicit UserCore(std::shared_ptr<Context> context);

  /// @brief Check if the Schema of this UserCore is compatible with another Schema
  bool implementsSchema(const std::shared_ptr<arrow::Schema> &schema);

  /// @brief Reset the UserCore
  Status reset();

  /// @brief Set the first (inclusive) and last (exclusive) column to process
  Status setRange(int32_t first, int32_t last);

  /// @brief Set the parameters of the UserCore
  Status setArguments(std::vector<uint32_t> arguments);

  /// @brief Start the UserCore
  Status start();

  /// @brief Read the status register of the UserCore
  Status getStatus(uint32_t *status);

  /// @brief Read the return registers of the UserCore
  Status getReturn(uint32_t *ret0, uint32_t *ret1);

  /**
   * @brief A blocking function that waits for the UserCore to finish
   *
   * Polls with an interval of poll_interval_usec microseconds.
   */
  Status waitForFinish(unsigned int poll_interval_usec);

  /**
   * @brief A blocking function that waits for the UserCore to finish
   *
   * Polls at maximum speed.
   */
  Status waitForFinish();

  std::shared_ptr<Platform> platform();
  std::shared_ptr<Context> context();

  // Default control and status values:
  uint32_t ctrl_start = 1UL << FLETCHER_REG_CONTROL_START;
  uint32_t ctrl_reset = 1UL << FLETCHER_REG_CONTROL_RESET;
  uint32_t done_status = 1UL << FLETCHER_REG_STATUS_DONE;
  uint32_t done_status_mask = 1UL << FLETCHER_REG_STATUS_DONE;

 private:
  std::shared_ptr<Context> _context;
};

}
