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

#include "./context.h"

namespace fletcher {

DeviceArray::DeviceArray(const std::shared_ptr<arrow::Array> &array, DeviceArray::mode_t mode)
    : host_array(array), mode(mode) {
  std::vector<arrow::Buffer *> host_buffers;
  common::flattenArrayBuffers(&host_buffers, host_array);
  buffers.reserve(buffers.size());
  for (const auto &buf : host_buffers) {
    buffers.emplace_back(buf->data(), buf->size());
  }
  mode = DeviceArray::PREPARE;
}

Status Context::Make(std::shared_ptr<Context> *context, std::shared_ptr<Platform> platform) {
  (*context) = std::make_shared<Context>(platform);
  return Status::OK();
}

Status Context::prepareArray(const std::shared_ptr<arrow::Array> &array) {
  // Check if this Array was already queued (cached or prepared).
  // If so, we can refer to the cached version. Since Arrow Arrays are immutable, we don't have to make a copy.
  for (const auto &a : device_arrays) {
    if (array == a->host_array) {
      ARROW_LOG(WARNING) << array->type()->ToString() + " array already queued to device. Duplicating reference.";
      device_arrays.push_back(a);
      return Status::OK();
    }
  }
  // Otherwise add it to the queue
  device_arrays.emplace_back(std::make_shared<DeviceArray>(array, DeviceArray::PREPARE));
  return Status::OK();
}

Status Context::cacheArray(const std::shared_ptr<arrow::Array> &array) {
  // Check if this Array is already referred to in the queue
  size_t array_cnt = device_arrays.size();
  bool queued = false;
  for (size_t i = 0; i < array_cnt && !queued; i++) {
    if (array == device_arrays[i]->host_array) {
      ARROW_LOG(WARNING) << array->type()->ToString() + " array already queued to device."
                                                        " Ensuring caching and duplicating reference.";
      device_arrays[i]->mode = DeviceArray::CACHE;
      device_arrays.push_back(device_arrays[i]);
      queued = true;
    }
  }

  // Otherwise add it to the queue
  if (!queued) {
    device_arrays.emplace_back(std::make_shared<DeviceArray>(array, DeviceArray::CACHE));
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

Status Context::writeBufferConfig() {
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

  return Status::OK();
}

}  // namespace fletcher
