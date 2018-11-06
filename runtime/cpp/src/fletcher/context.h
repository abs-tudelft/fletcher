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

#include <utility>
#include <vector>
#include <memory>
#include <iostream>

#include <arrow/array.h>
#include <arrow/record_batch.h>

#include "common/status.h"
#include "common/arrow-utils.h"

#include "./platform.h"

namespace fletcher {

/**
 * A buffer on the device
 */
struct DeviceBuffer {
  DeviceBuffer(const uint8_t *host_address, int64_t size, Mode access_mode)
      : host_address(host_address), size(size), mode(access_mode) {}
  const uint8_t *host_address = nullptr;
  da_t device_address = D_NULLPTR;
  int64_t size = 0;
  bool was_alloced = false;
  Mode mode = Mode::READ;
};

/**
 * An Arrow Array and its corresponding buffers on a device.
 */
struct DeviceArray {
  typedef enum { PREPARE, CACHE } memory_t;
  DeviceArray(const std::shared_ptr<arrow::Array> &array,
              const std::shared_ptr<arrow::Field> &field,
              Mode access_mode,
              memory_t memory);
  const std::shared_ptr<arrow::Array> host_array;
  std::shared_ptr<arrow::Field> field;
  std::vector<DeviceBuffer> buffers;
  Mode mode = Mode::READ;
  memory_t memory = CACHE;
  bool on_device = false;
};

/**
 * @brief A Context for a platform where arrow::Arrays can be prepared for processing on a platform device.
 */
class Context {
 public:

  explicit Context(std::shared_ptr<Platform> platform) : platform(std::move(platform)) {}
  ~Context();

  /// The platform this context is running on.
  std::shared_ptr<Platform> platform;

  /// The [arrow::Array]s that have been added to the context.
  std::vector<std::shared_ptr<DeviceArray>> device_arrays;

  /**
   * @brief Create a new context on a specific platform.
   * @param context     The new context.
   * @param platform    The platform to create it on.
   * @return            Status::OK() if successful, Status::ERROR() otherwise.
   */
  static Status Make(std::shared_ptr<Context> *context, const std::shared_ptr<Platform> &platform);

  /**
   * @brief Enqueue an arrow::Array for usage preparation on the device.
   *
   * This function enqueues any buffers in the underlying structure of the Array. If hardware was generated to not
   * contain validity bitmap support, while arrow implementation provides a validity bitmap anyway, discrepancies
   * between device hardware and host software may occur. Therefore, it is recommended to use queueArray with the
   * field argument.
   *
   * @param array       The arrow::Array to queue
   * @param access_mode Whether to read or write from/to this array.
   * @param cache       Force caching; i.e. the Array is guaranteed to be copied to on-board memory.
   * @return            Status::OK() if successful, Status::ERROR() otherwise.
   */
  [[deprecated]] Status queueArray(const std::shared_ptr<arrow::Array> &array, Mode access_mode, bool cache = false) {
    return queueArray(array, nullptr, access_mode, cache);
  }

  /**
   * @brief Enqueue an arrow::Array for usage preparation on the device.
   *
   * If @param field is nullptr, any null bitmap buffers that are present in the structure due to the specfic
   * Arrow implementation will also be included. This may cause a discrepancy between the hardware implementation
   * and the run-time. It is therefore always recommended to supply the field.
   *
   * @param array       The arrow::Array to queue
   * @param field       Potential arrow::Schema field that corresponds to this array.
   * @param access_mode Whether to read or write from/to this array.
   * @param cache       Force caching; i.e. the Array is guaranteed to be copied to on-board memory.
   * @return            Status::OK() if successful, Status::ERROR() otherwise.
   */
  Status queueArray(const std::shared_ptr<arrow::Array> &array,
                    const std::shared_ptr<arrow::Field> &field,
                    Mode access_mode,
                    bool cache = false);

  /**
   * @brief Enqueue an arrow::RecordBatch for usage preparation on the device.
   *
   * This function utilizes Arrow metadata in the schema of the RecordBatch to determine whether or not some field
   * (i.e. some Array in the internal structure) will be used on the device.
   *
   * @param record_batch  The arrow::RecordBatch to queue
   * @param cache         Force caching; i.e. the RecordBatch is guaranteed to be copied to on-board memory.
   * @return              Status::OK() if successful, Status::ERROR() otherwise.
   */
  Status queueRecordBatch(const std::shared_ptr<arrow::RecordBatch> &record_batch, bool cache = false);

  /// @brief Obtain the size (in bytes) of all buffers currently enqueued.
  size_t getQueueSize();

  /// @brief Enable the usage of the enqueued buffers by the device
  Status enable();

  /// @brief Return the number of buffers in this context.
  uint64_t num_buffers();

 private:

  bool written = false;

  /**
 * @brief Prepare all buffers of an Arrow Array to be used within this context.
 *
 * May or may not cause a copy to the platform device on-board memory, depending on the capabilities of the platform.
 *
 * @param array         The arrow::Array to prepare.
 * @param access_mode Whether to read or write from/to this array.
 * @param field         Potential schema field that corresponds to this array.
 * @return              Status::OK() if successful, Status::ERROR() otherwise.
 */
  Status prepareArray(const std::shared_ptr<arrow::Array> &array,
                      Mode access_mode,
                      const std::shared_ptr<arrow::Field> &field = nullptr);

  /**
   * @brief Explicitly cache the buffers of an Arrow Array to the platform device on-board memory.
   *
   * Always creates a copy to the platform device on-board memory.
   *
   * @param array       The arrow::Array to cache.
   * @param access_mode Whether to read or write from/to this array.
   * @param field       Potential schema field that corresponds to this array.
   * @return            Status::OK() if successful, Status::ERROR() otherwise.
   */
  Status cacheArray(const std::shared_ptr<arrow::Array> &array,
                    Mode access_mode,
                    const std::shared_ptr<arrow::Field> &field = nullptr);
};

}  // namespace fletcher
