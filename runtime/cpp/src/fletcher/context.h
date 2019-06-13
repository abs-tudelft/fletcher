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
#include <fletcher/common.h>

#include "fletcher/platform.h"
#include "fletcher/status.h"

namespace fletcher {

using fletcher::Mode;

enum class MemType {
  /**
   * @brief Apply the least effort to make the data available to the device.
   *
   * For platforms where the device may access host memory directly, ANY will not copy data to device on-board
   * memory to make it available to the device. If the platform requires a copy to on-board memory, then this will
   * behave the same as the CACHE option.
   */
      ANY,

  /**
   * @brief Cache the data to on-board memory of the device.
   *
   * If available, this forces the data to be copied to device on-board memory (e.g. some seperate DRAM chips sitting
   * on the accelerator PCB next to the FPGA, but it could be HBM on top of the FPGA fabric in the same chip, or
   * BRAM. This depends on the platform).
   *
   * Selecting CACHE may result in higher performance if there is data reuse by the kernel, but may result in lower
   * performance if the data is not reused by the kernel (for example fully streamable kernels).
   */
      CACHE
};

/**
 * A buffer on the device
 */
struct DeviceBuffer {
  const uint8_t *host_address = nullptr;
  da_t device_address = D_NULLPTR;
  int64_t size = 0;

  MemType memory = MemType::CACHE;
  Mode mode = Mode::READ;

  bool available_to_device = false;
  bool was_alloced = false;

  DeviceBuffer() = default;

  DeviceBuffer(const uint8_t *host_address, int64_t size, MemType type, Mode access_mode)
      : host_address(host_address), size(size), memory(type), mode(access_mode) {}
};

/**
 * @brief A Context for a platform where a RecordBatches can be prepared for processing by the Kernel.
 */
class Context {
 public:

  explicit Context(std::shared_ptr<Platform> platform) : platform_(std::move(platform)) {}
  ~Context();

  /**
   * @brief Create a new context on a specific platform.
   * @param context     The new context.
   * @param platform    The platform to create it on.
   * @return            Status::OK() if successful, Status::ERROR() otherwise.
   */
  static Status Make(std::shared_ptr<Context> *context, const std::shared_ptr<Platform> &platform);

  /**
   * @brief Enqueue an arrow::RecordBatch for usage on the device.
   *
   * This function utilizes Arrow metadata in the schema of the RecordBatch to determine whether or not some field
   * (i.e. some Array in the internal structure) will be used on the device.
   *
   * @param record_batch  The arrow::RecordBatch to queue
   * @param mem_type      Force caching; i.e. the RecordBatch is guaranteed to be copied to on-board memory.
   * @return              Status::OK() if successful, Status::ERROR() otherwise.
   */
  Status QueueRecordBatch(const std::shared_ptr<arrow::RecordBatch> &record_batch,
                          MemType mem_type = MemType::ANY);

  /// @brief Obtain the size (in bytes) of all buffers currently enqueued.
  size_t GetQueueSize() const;

  /// @brief Enable the usage of the enqueued buffers by the device
  Status Enable();

  /// @brief Return the number of buffers in this context.
  uint64_t num_buffers() const;

  std::shared_ptr<Platform> platform() const { return platform_; }

  DeviceBuffer device_buffer(size_t i) const { return device_buffers_[i]; }

 protected:
  bool written_ = false;
  /// The platform this context is running on.
  std::shared_ptr<Platform> platform_;
  std::vector<std::shared_ptr<arrow::RecordBatch>> host_batches_;
  std::vector<RecordBatchDescription> host_batch_desc_;
  std::vector<MemType> host_batch_memtype_;
  std::vector<std::shared_ptr<arrow::Buffer>> device_batch_desc_;
  std::vector<DeviceBuffer> device_buffers_;
};

}  // namespace fletcher
