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

#include <dlfcn.h>
#include <iostream>
#include <memory>
#include <string>

#include "fletcher.h"

using namespace std;

namespace fletcher {

struct Status {
  fstatus_t val = static_cast<fstatus_t>(-1);
  Status() = default;
  explicit Status(fstatus_t val) : val(val) {}
  bool ok() { return val == 0; }
  void check() {
    if (!ok()) { exit(EXIT_FAILURE); }
  }
  static Status OK() { return Status(0); }
  static Status FAIL() { return Status(static_cast<fstatus_t>(-1)); }
};

class Platform {
 public:
  static Status create(const std::string &name, std::shared_ptr<Platform> *platform, bool quiet = true);
  static Status create(std::shared_ptr<Platform> *platform);
  std::string getName();

  inline Status writeMMIO(uint64_t offset, uint32_t value) {
    return Status(platformWriteMMIO(offset, value));
  }

  inline Status readMMIO(uint64_t offset, uint32_t *value) {
    return Status(platformReadMMIO(offset, value));
  }

  inline Status copyHostToDevice(ha_t host_source, da_t device_destination, uint64_t size) {
    return Status(platformCopyHostToDevice(host_source, device_destination, size));
  }

  inline Status copyDeviceToHost(da_t device_source, ha_t host_destination, uint64_t size) {
    return Status(platformCopyDeviceToHost(device_source, host_destination, size));
  }

 private:
  fstatus_t (*platformGetName)(char *name, size_t size);
  fstatus_t (*platformWriteMMIO)(uint64_t offset, uint32_t value);
  fstatus_t (*platformReadMMIO)(uint64_t offset, uint32_t *value);
  fstatus_t (*platformCopyHostToDevice)(ha_t host_source, da_t device_destination, uint64_t size);
  fstatus_t (*platformCopyDeviceToHost)(da_t device_source, ha_t host_destination, uint64_t size);

  Status link(void *handle, bool quiet = true);
};

}//namespace fletcher
