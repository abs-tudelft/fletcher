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

#include <cstdlib>
#include <string>
#include <iostream>

#include <fletcher/fletcher.h>

namespace fletcher {

struct Status {
  fstatus_t val = static_cast<fstatus_t>(FLETCHER_STATUS_ERROR);
  std::string message;

  Status() = default;

  explicit Status(fstatus_t val, std::string msg = "") : val(val), message(std::move(msg)) {}

  inline bool ok() { return val == FLETCHER_STATUS_OK; }

  /// @brief Exit when fail
  inline void ewf(const std::string &msg = "") {
    if (!ok()) {
      std::cerr << msg << std::endl;
      exit(EXIT_FAILURE);
    }
  }

  inline bool operator==(const Status &rhs) const {
    return val == rhs.val;
  }

  inline static Status OK() { return Status(FLETCHER_STATUS_OK); }
  inline static Status ERROR(std::string msg = "") {
    return Status(static_cast<fstatus_t>(FLETCHER_STATUS_ERROR), std::move(msg));
  }
  inline static Status NO_PLATFORM() {
    return Status(static_cast<fstatus_t>(FLETCHER_STATUS_NO_PLATFORM),
                  "No platform.");
  }
  inline static Status DEVICE_OUT_OF_MEMORY() {
    return Status(static_cast<fstatus_t>(FLETCHER_STATUS_NO_PLATFORM),
                  "Device out of memory.");
  }
};

} // namespace fletcher
