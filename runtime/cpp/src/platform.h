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
#include <cassert>

#include "fletcher.h"

namespace fletcher {

struct Status {
  fstatus_t val = static_cast<fstatus_t>(FLETCHER_STATUS_ERROR);
  Status() = default;
  explicit Status(fstatus_t val) : val(val) {}
  bool ok() { return val == FLETCHER_STATUS_OK; }
  void check() {
    if (!ok()) { exit(EXIT_FAILURE); }
  }
  static Status OK() { return Status(0); }
  static Status ERROR() { return Status(static_cast<fstatus_t>(FLETCHER_STATUS_ERROR)); }
};

class Platform {
 public:
  ~Platform() {
    platformTerminate(terminate_data);
  }

  static Status create(const std::string &name, std::shared_ptr<Platform> *platform, bool quiet = true);
  static Status create(std::shared_ptr<Platform> *platform);

  std::string getName();

  inline Status init() {
    assert(platformInit != nullptr);
    return Status(platformInit(init_data));
  }

  inline Status writeMMIO(uint64_t offset, uint32_t value) {
    assert(platformWriteMMIO != nullptr);
    return Status(platformWriteMMIO(offset, value));
  }

  inline Status readMMIO(uint64_t offset, uint32_t *value) {
    assert(platformReadMMIO != nullptr);
    return Status(platformReadMMIO(offset, value));
  }

  inline Status deviceMalloc(da_t *device_address, size_t size) {
    assert(platformDeviceMalloc != nullptr);
    return Status(platformDeviceMalloc(device_address, size));
  }

  inline Status deviceFree(da_t device_address) {
    assert(platformDeviceFree != nullptr);
    return Status(platformDeviceFree(device_address));
  }

  inline Status copyHostToDevice(ha_t host_source, da_t device_destination, uint64_t size) {
    assert(platformCopyHostToDevice != nullptr);
    return Status(platformCopyHostToDevice(host_source, device_destination, size));
  }

  inline Status copyDeviceToHost(da_t device_source, ha_t host_destination, uint64_t size) {
    assert(platformCopyDeviceToHost != nullptr);
    return Status(platformCopyDeviceToHost(device_source, host_destination, size));
  }

  inline Status terminate() {
    assert(platformTerminate != nullptr);
    return Status(platformTerminate(terminate_data));
  }

  void *terminate_data = nullptr;
  void *init_data = nullptr;

 private:
  // Functions to be linked
  fstatus_t (*platformGetName)(char *name, size_t size) = nullptr;
  fstatus_t (*platformInit)(void *arg) = nullptr;
  fstatus_t (*platformWriteMMIO)(uint64_t offset, uint32_t value) = nullptr;
  fstatus_t (*platformReadMMIO)(uint64_t offset, uint32_t *value) = nullptr;
  fstatus_t (*platformDeviceMalloc)(da_t *device_address, size_t size) = nullptr;
  fstatus_t (*platformDeviceFree)(da_t device_address) = nullptr;
  fstatus_t (*platformCopyHostToDevice)(ha_t host_source, da_t device_destination, uint64_t size) = nullptr;
  fstatus_t (*platformCopyDeviceToHost)(da_t device_source, ha_t host_destination, uint64_t size) = nullptr;
  fstatus_t (*platformPrepareHostBuffer)(ha_t host_source, da_t *device_destination, uint64_t size) = nullptr;
  fstatus_t (*platformCacheHostBuffer)(ha_t host_source, da_t *device_destination, uint64_t size) = nullptr;
  fstatus_t (*platformTerminate)(void *arg) = nullptr;

  /// @brief Attempt to link all functions using a handle obtained by dlopen
  Status link(void *handle, bool quiet = true);

};

}  // namespace fletcher
