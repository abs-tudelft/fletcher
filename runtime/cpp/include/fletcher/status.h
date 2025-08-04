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

#include <fletcher/fletcher.h>
#include <cstdlib>
#include <string>
#include <iostream>

namespace fletcher {

/// Status return value of all Fletcher run-time functions
struct Status {
  /// The raw status value.
  fstatus_t val = FLETCHER_STATUS_ERROR;
  /// Optional message.
  std::string message;

  /// @brief Construct a new status.
  explicit Status(const fstatus_t val, std::string msg) : val(val), message(std::move(msg)) {}
  explicit Status(const fstatus_t val = FLETCHER_STATUS_ERROR) : val(val) {}

  /// @brief Return true if the status is OK.
  [[nodiscard]] bool ok() const { return val == FLETCHER_STATUS_OK; }

  /// @brief Exit the program on a failure status, with some message. If no message is supplied, use the status message.
  void ewf(const std::string &msg = "") const {
    if (!ok()) {
      if (!msg.empty()) {
        std::cerr << msg << std::endl;
      } else {
        std::cerr << message << std::endl;
      }
      exit(EXIT_FAILURE);
    }
  }

  /// @brief Compare raw status values for equality.
  bool operator==(const Status &rhs) const {
    return val == rhs.val;
  }

  /// @brief Return an OK status.
  static Status OK() { return Status(FLETCHER_STATUS_OK); }

  /// @brief Return an ERROR status with some message.
  static Status ERROR(std::string msg = "") {
    return Status(FLETCHER_STATUS_ERROR, std::move(msg));
  }

  // Helper macro for error states.
#define STATUS_FACTORY(RAW_ID, MESSAGE)                                       \
  static Status RAW_ID() {                                                    \
    return Status(FLETCHER_STATUS_##RAW_ID, MESSAGE); \
  }

  // Other error states:
  STATUS_FACTORY(NO_PLATFORM, "Could not detect platform.")
  STATUS_FACTORY(DEVICE_OUT_OF_MEMORY, "Device out of memory.")
};

}  // namespace fletcher
