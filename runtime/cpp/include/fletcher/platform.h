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

#include "fletcher/status.h"

#if defined(__MACH__)
#define DYLIB_EXT ".dylib"
#else
#define DYLIB_EXT ".so"
#endif

namespace fletcher {

/// A Fletcher Platform. Links during run-time and abstracts access to lower-level platform-specific libraries / API's.
class Platform {
 public:
  /// @brief Platform destructor.
  ~Platform() {
    if (!terminated) {
      platformTerminate(terminate_data);
    }
  }

  /**
   * @brief Create a new platform instance.
   * @param[in]  name          The name of the platform.
   * @param[out] platform_out  A pointer to a shared pointer that will point to the new platform instance.
   * @param[in]  quiet         Whether to suppress any logging messages
   * @return Status::OK() if successful, otherwise a descriptive error status with platform_out = nullptr.
   */
  static Status Make(const std::string &name, std::shared_ptr<Platform> *platform_out, bool quiet = true);

  /**
   * @brief Create a new platform by attempting to autodetect the platform driver.
   * @param[out] platform_out  A pointer to a shared pointer that will point to the new platform instance.
   * @param[in]  quiet         Suppresses logging messages when true.
   * @return Status::OK() if successful, otherwise a descriptive error status with platform_out = nullptr.
   */
  static Status Make(std::shared_ptr<Platform> *platform_out, bool quiet = true);

  /// @brief Return the name of the platform.
  std::string name();

  /// @brief Print the contents of the MMIO registers within some range.
  Status MmioToString(std::string *str, uint64_t start, uint64_t stop, bool quiet = false);

  /// @brief Initialize the platform.
  inline Status Init() { return Status(platformInit(init_data)); }

  /**
   * @brief Write to an MMIO register.
   * @param[in] offset  Register offset to write to.
   * @param[in] value   Value to write.
   * @return Status::OK() if successful, otherwise a descriptive error status.
   */
  inline Status WriteMMIO(uint64_t offset, uint32_t value) { return Status(platformWriteMMIO(offset, value)); }

  /**
  * @brief Read from an MMIO register.
  * @param[in]  offset  Register offset to read from.
  * @param[out] value   Pointer to a value to store the result.
  * @return Status::OK() if successful, otherwise a descriptive error status.
  */
  inline Status ReadMMIO(uint64_t offset, uint32_t *value) { return Status(platformReadMMIO(offset, value)); }

  /**
  * @brief Read 64 bit value from two successive 32 bit MMIO registers. The lower register will go to the lower bits.
  * @param[in]  offset  Register offset to read from.
  * @param[out] value   Pointer to a value to store the result.
  * @return Status::OK() if successful, otherwise a descriptive error status.
  */
  Status ReadMMIO64(uint64_t offset, uint64_t *value);

  /**
   * @brief Allocate a region of memory on the device.
   * @param[out] device_address  The resulting device address
   * @param[in]  size            The amount of bytes to allocate
   * @return Status::OK() if successful, otherwise a descriptive error status.
   */
  inline Status DeviceMalloc(da_t *device_address, size_t size) {
    return Status(platformDeviceMalloc(device_address, size));
  }

  /**
   * @brief Free a previously allocated memory region on the device.
   * @param[in] device_address  The device address of the memory region.
   * @return Status::OK() if successful, otherwise a descriptive error status.
   */
  inline Status DeviceFree(da_t device_address) { return Status(platformDeviceFree(device_address)); }

  /**
   * @brief Copy data from host memory to device memory.
   * @param[in] host_source         Source pointer in host memory.
   * @param[in] device_destination  Destination pointer in device memory.
   * @param[in] size                The amount of bytes to copy.
   * @return Status::OK() if successful, otherwise a descriptive error status.
   */
  inline Status CopyHostToDevice(uint8_t *host_source, da_t device_destination, uint64_t size) {
    return Status(platformCopyHostToDevice(host_source, device_destination, size));
  }

  /**
   * @brief Copy data from device memory to host memory.
   * @param[in] device_source       Source pointer in device memory.
   * @param[in] host_destination    Destination pointer in host memory.
   * @param[in] size                The amount of bytes to copy.
   * @return Status::OK() if successful, otherwise a descriptive error status.
   */
  inline Status CopyDeviceToHost(da_t device_source, uint8_t *host_destination, uint64_t size) {
    return Status(platformCopyDeviceToHost(device_source, host_destination, size));
  }

  /**
   * @brief Prepare a memory region of the host for use by the device. May or may not involve a copy (see MemType).
   * @param[in]  host_source          Source pointer in host memory.
   * @param[out] device_destination   Destination pointer in device memory.
   * @param[in]  size                 The amount of bytes to copy.
   * @param[out] alloced              Whether or not an allocation was made in device memory (that needs to be freed).
   * @return Status::OK() if successful, otherwise a descriptive error status.
   */
  inline Status PrepareHostBuffer(const uint8_t *host_source, da_t *device_destination, int64_t size, bool *alloced) {
    assert(platformPrepareHostBuffer != nullptr);
    int ll_alloced = 0;
    auto stat = platformPrepareHostBuffer(host_source, device_destination, size, &ll_alloced);
    *alloced = ll_alloced == 1;
    return Status(stat);
  }

  /**
  * @brief Cache a memory region of the host for use by the device. Always causes an allocation and copy.
  * @param[in]  host_source          Source pointer in host memory.
  * @param[out] device_destination   Destination pointer in device memory.
  * @param[in]  size                 The amount of bytes to copy.
  * @return Status::OK() if successful, otherwise a descriptive error status.
  */
  inline Status CacheHostBuffer(const uint8_t *host_source, da_t *device_destination, int64_t size) {
    assert(platformCacheHostBuffer != nullptr);
    return Status(platformCacheHostBuffer(host_source, device_destination, size));
  }

  /**
   * @brief Terminate the platform
   * @return Status::OK() if successful, otherwise a descriptive error status.
   */
  inline Status Terminate() {
    assert(platformTerminate != nullptr);
    terminated = true;
    return Status(platformTerminate(terminate_data));
  }

  /// Data for platform initialization.
  void *init_data = nullptr;
  /// Data for platform termination.
  void *terminate_data = nullptr;

 private:
  // Functions to be linked:
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

  /// @brief Attempt to link all functions using a handle obtained by dlopen.
  Status Link(void *handle, bool quiet = true);

  /// Whether this platform was terminated.
  bool terminated = false;
};

}  // namespace fletcher
