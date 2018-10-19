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

#include <algorithm>
#include <vector>
#include <memory>

#include <arrow/util/logging.h>
#include <arrow/record_batch.h>

#include "./context.h"

namespace fletcher {

DeviceArray::DeviceArray(const std::shared_ptr<arrow::Array> &array,
                         const std::shared_ptr<arrow::Field> &field,
                         DeviceArray::mode_t mode)
    : host_array(array), field(field), mode(mode) {
  std::vector<arrow::Buffer *> host_buffers;
  if (field != nullptr) {
    common::flattenArrayBuffers(&host_buffers, host_array, field);
  } else {
    ARROW_LOG(WARNING) << "Flattening of array buffers without field specification may lead to discrepancy between "
                          "hardware and software implementation.";
    common::flattenArrayBuffers(&host_buffers, host_array);
  }
  buffers.reserve(buffers.size());
  for (const auto &buf : host_buffers) {
    if (buf != nullptr) {
      buffers.emplace_back(buf->data(), buf->size());
    } else {
      buffers.emplace_back(nullptr, 0);
    }
  }
  mode = DeviceArray::PREPARE;
}

Status Context::Make(std::shared_ptr<Context> *context, std::shared_ptr<Platform> platform) {
  (*context) = std::make_shared<Context>(platform);
  return Status::OK();
}

Status Context::prepareArray(const std::shared_ptr<arrow::Array> &array, const std::shared_ptr<arrow::Field> &field) {
  // Check if this Array was already queued (cached or prepared).
  // If so, we can refer to the cached version. Since Arrow Arrays are immutable, we don't have to make a copy.
  for (const auto &a : device_arrays) {
    if (array == a->host_array) {
      ARROW_LOG(WARNING) << array->type()->ToString() + " array already queued to device. Duplicating reference.";
      device_arrays.push_back(a);
      device_arrays.back()->field = field;
      return Status::OK();
    }
  }
  // Otherwise add it to the queue
  device_arrays.emplace_back(std::make_shared<DeviceArray>(array, field, DeviceArray::PREPARE));
  return Status::OK();
}

Status Context::cacheArray(const std::shared_ptr<arrow::Array> &array, const std::shared_ptr<arrow::Field> &field) {
  // Check if this Array is already referred to in the queue
  size_t array_cnt = device_arrays.size();
  bool queued = false;
  for (size_t i = 0; i < array_cnt && !queued; i++) {
    if (array == device_arrays[i]->host_array) {
      ARROW_LOG(WARNING) << array->type()->ToString() + " array already queued to device."
                                                        " Ensuring caching and duplicating reference.";
      device_arrays[i]->mode = DeviceArray::CACHE;
      device_arrays.push_back(device_arrays[i]);
      device_arrays.back()->field = field;
      queued = true;
    }
  }

  // Otherwise add it to the queue
  if (!queued) {
    device_arrays.emplace_back(std::make_shared<DeviceArray>(array, field, DeviceArray::CACHE));
  }
  return Status::OK();
}

Context::~Context() {
  for (const auto &array : device_arrays) {
    if (array->on_device) {
      for (const auto &buf : array->buffers) {
        if (buf.was_alloced) {
          platform->deviceFree(buf.device_address);
        }
      }
    }
  }
}

Status Context::enable() {
  written = true;

  for (const auto &array : device_arrays) {
    if (array->mode == DeviceArray::PREPARE) {
      if (!array->on_device) {
        for (auto &buffer : array->buffers) {
          platform->prepareHostBuffer(buffer.host_address,
                                      &buffer.device_address,
                                      buffer.size,
                                      &buffer.was_alloced).ewf();
        }
      }
      array->on_device = true;
    } else {
      if (!array->on_device) {
        for (auto &buffer : array->buffers) {
          platform->cacheHostBuffer(buffer.host_address,
                                    &buffer.device_address,
                                    buffer.size).ewf();
          buffer.was_alloced = true;
        }
      }
      array->on_device = true;
    }
  }

  uint64_t off = FLETCHER_REG_BUFFER_OFFSET;
  for (const auto &array: device_arrays) {
    for (const auto &buf : array->buffers) {
      dau_t address;
      address.full = buf.device_address;
      platform->writeMMIO(off, address.lo);
      off++;
      platform->writeMMIO(off, address.hi);
      off++;
    }
  }
  return Status::OK();
}

Status Context::queueArray(const std::shared_ptr<arrow::Array> &array,
                           const std::shared_ptr<arrow::Field> &field,
                           bool cache) {
  if (cache) {
    return cacheArray(array, field);
  } else {
    return prepareArray(array, field);
  }
}

Status Context::queueRecordBatch(const std::shared_ptr<arrow::RecordBatch> &record_batch, bool cache) {
  if (record_batch != nullptr) {
    for (int c = 0; c < record_batch->num_columns(); c++) {
      queueArray(record_batch->column(c), record_batch->schema()->field(c), cache);
    }
    return Status::OK();
  } else {
    return Status::ERROR();
  }
}

uint64_t Context::num_buffers() {
  uint64_t cnt = 0;
  for (const auto &arr : device_arrays) {
    cnt += arr->buffers.size();
  }
  return cnt;
}

}  // namespace fletcher
