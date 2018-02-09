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

#include <arrow/api.h>

#include "common.h"
#include "FPGAPlatform.h"

namespace fletcher {

// Return values for UserCore functions
typedef enum {
  FAILURE,
  SUCCESS
} uc_stat;

/**
 * \class UserCore
 * \brief Abstract class for UserCore management
 * 
 * This class should be implemented for a specific accelerator 
 * implementation.
 * You don't -have- to use this class, but it could be used as a way to
 * interface on the software side of Fletcher in a similar way.
 */
class UserCore {
 public:
  UserCore(std::shared_ptr<FPGAPlatform> platform);

  /**
   * \brief Check if the Schema of this UserCore is compatible with another Schema
   */
  bool implements_schema(const std::shared_ptr<arrow::Schema>& schema);

  /**
   * \brief Reset the UserCore
   */
  uc_stat reset();

  /**
   * \brief Set the parameters of the UserCore
   */
  uc_stat set_arguments(std::vector<fr_t> arguments);

  /**
   * \brief Start the UserCore
   */
  uc_stat start();

  /**
   * \brief Read the status register of the UserCore
   */
  fr_t get_status();

  /**
   * \brief Read the result register of the UserCore
   */
  fr_t get_return();

  /**
   * \brief  A blocking function that waits for the UserCore to finish
   * 
   * Polls with an interval of poll_interval_usec microseconds.
   */
  uc_stat wait_for_finish(unsigned int poll_interval_usec);

  /**
   * \brief A blocking function that waits for the UserCore to finish
   * 
   * Polls at maximum speed
   */
  uc_stat wait_for_finish();

 protected:
  /**
   * Get the platform this UserCore is attached to.
   */
  std::shared_ptr<FPGAPlatform> platform();

  // Default control and status values:
  fr_t ctrl_start = 1L << UC_REG_CONTROL_START;
  fr_t ctrl_reset = 1L << UC_REG_CONTROL_RESET;
  fr_t done_status = 1L << UC_REG_STATUS_DONE;
  fr_t done_status_mask = 1L << UC_REG_STATUS_DONE;

 private:
  std::shared_ptr<FPGAPlatform> _platform;

  uint64_t arg_offset;
};

}
