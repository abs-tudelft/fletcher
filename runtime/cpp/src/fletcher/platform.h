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

#include "common/status.h"

namespace fletcher {

class Platform {
 public:
  ~Platform() {
    if (!terminated) {
      platformTerminate(terminate_data);
    }
  }

  /**
   * @brief Create a new platform instance.
   * @param name        The name of the platform.
   * @param platform    The platform
   * @param quiet       Whether to surpress any logging messages
   * @return            Status::OK() if successful, Status::ERROR() otherwise.
   */
  static Status Make(const std::string &name, std::shared_ptr<Platform> *platform, bool quiet = true);

  /**
   * @brief Create a new platform by attempting to autodetect the platform driver.
   * @param platform    The platform
   * @return            Status::OK() if successful, Status::ERROR() otherwise.
   */
  static Status Make(std::shared_ptr<Platform> *platform);

  /// @brief Return the name of the platform
  std::string getName();

  /// @brief Print the contents of the MMIO registers within some range
  Status printMMIO(uint64_t start, uint64_t stop, bool quiet=false);

  /// @brief Initialize the platform
  inline Status init() { return Status(platformInit(init_data)); }

  /**
   * @brief Write to MMIO register
   * @param offset      Register offset
   * @param value       Value to write
   * @return            Status::OK() if successful, Status::ERROR() otherwise.
   */
  inline Status writeMMIO(uint64_t offset, uint32_t value) { return Status(platformWriteMMIO(offset, value)); }

  /**
  * @brief Read from MMIO register
  * @param offset      Register offset
  * @param value       Value to read to
  * @return            Status::OK() if successful, Status::ERROR() otherwise.
  */
  inline Status readMMIO(uint64_t offset, uint32_t *value) { return Status(platformReadMMIO(offset, value)); }

  /**
   * @brief Allocate a region of memory on the device
   * @param device_address  The resulting device address
   * @param size            The amount of bytes to allocate
   * @return                Status::OK() if successful, Status::ERROR() otherwise.
   */
  inline Status deviceMalloc(da_t *device_address, size_t size) {
    return Status(platformDeviceMalloc(device_address, size));
  }

  /**
   * @brief Free a previously allocated memory region on the device.
   * @param device_address  The device address of the memory region.
   * @return                Status::OK() if successful, Status::ERROR() otherwise.
   */
  inline Status deviceFree(da_t device_address) { return Status(platformDeviceFree(device_address)); }

  /**
   * @brief Copy a memory region from host memory to device memory
   * @param host_source         Source in host memory
   * @param device_destination  Destination in device meomry
   * @param size                The amount of bytes
   * @return                    Status::OK() if successful, Status::ERROR() otherwise.
   */
  inline Status copyHostToDevice(uint8_t *host_source, da_t device_destination, uint64_t size) {
    return Status(platformCopyHostToDevice(host_source, device_destination, size));
  }

  /**
   * @brief Copy a memory region from device memory to host memory
   * @param device_source       Source in device meomry
   * @param host_destination    Destination in host memory
   * @param size                The amount of bytes
   * @return                    Status::OK() if successful, Status::ERROR() otherwise
   */
  inline Status copyDeviceToHost(da_t device_source, uint8_t *host_destination, uint64_t size) {
    return Status(platformCopyDeviceToHost(device_source, host_destination, size));
  }

  /**
   * @brief Prepare a memory region of the host for use by the device. May or may not involve a copy.
   * @param host_source         Source in host memory
   * @param device_destination  Pointer to buffer that can be used in device
   * @param size                Amount of bytes
   * @param alloced             Whether or not an allocation was made in device memory
   * @return                    Status::OK() if successful, Status::ERROR() otherwise
   */
  inline Status prepareHostBuffer(const uint8_t *host_source, da_t *device_destination, int64_t size, bool *alloced) {
    assert(platformPrepareHostBuffer != nullptr);
    int ll_alloced = 0;
    auto stat = platformPrepareHostBuffer(host_source, device_destination, size, &ll_alloced);
    *alloced = ll_alloced == 1;
    return Status(stat);
  }

  /**
  * @brief Cache a memory region of the host for use by the device. Always causes an allocation / copy.
  * @param host_source         Source in host memory
  * @param device_destination  Pointer to buffer that can be used in device
  * @param size                Amount of bytes
  * @return                    Status::OK() if successful, Status::ERROR() otherwise
  */
  inline Status cacheHostBuffer(const uint8_t *host_source, da_t *device_destination, int64_t size) {
    assert(platformCacheHostBuffer != nullptr);
    return Status(platformCacheHostBuffer(host_source, device_destination, size));
  }

  /// @brief Terminate the platform
  inline Status terminate() {
    assert(platformTerminate != nullptr);
    terminated = true;
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
  fstatus_t (*platformDeviceMalloc)(da_t *device_address, int64_t size) = nullptr;
  fstatus_t (*platformDeviceFree)(da_t device_address) = nullptr;
  fstatus_t (*platformCopyHostToDevice)(const uint8_t *host_source, da_t device_destination, int64_t size) = nullptr;
  fstatus_t (*platformCopyDeviceToHost)(const da_t device_source, uint8_t *host_destination, int64_t size) = nullptr;
  fstatus_t (*platformPrepareHostBuffer)(const uint8_t *host_source,
                                         da_t *device_destination,
                                         int64_t size,
                                         int *alloced) = nullptr;
  fstatus_t (*platformCacheHostBuffer)(const uint8_t *host_source, da_t *device_destination, int64_t size) = nullptr;
  fstatus_t (*platformTerminate)(void *arg) = nullptr;

  /// @brief Attempt to link all functions using a handle obtained by dlopen
  Status link(void *handle, bool quiet = true);

  bool terminated = false;

};

}  // namespace fletcher
