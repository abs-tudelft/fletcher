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

#include <memory>
#include <vector>

#include <arrow/buffer.h>
#include <arrow/array.h>
#include <iostream>

#include "./arrow-utils.h"

namespace fletcher {
namespace common {

void flattenArrayBuffers(std::vector<arrow::Buffer *> *buffers, const std::shared_ptr<arrow::ArrayData>& array_data) {
  for (const auto &buf : array_data->buffers) {
    auto addr = buf.get();
    if (addr != nullptr) {
      buffers->push_back(addr);
    }
  }
  for (const auto &child : array_data->child_data) {
    flattenArrayBuffers(buffers, child);
  }
}

void flattenArrayBuffers(std::vector<arrow::Buffer *> *buffers, const std::shared_ptr<arrow::Array>& array) {
  // Because Arrow buffer order seems to be by convention and not by specification, handle these special cases:
  // This is to reverse the order of offset and values buffer to correspond with the hardware implementation.
  if (array->type() == arrow::binary()) {
    auto ba = std::dynamic_pointer_cast<arrow::BinaryArray>(array);
    buffers->push_back(ba->value_data().get());
    buffers->push_back(ba->value_offsets().get());
  } else if (array->type() == arrow::utf8()) {
    auto sa = std::dynamic_pointer_cast<arrow::StringArray>(array);
    buffers->push_back(sa->value_data().get());
    buffers->push_back(sa->value_offsets().get());
  } else {
    for (const auto &buf : array->data()->buffers) {
      auto addr = buf.get();
      if (addr != nullptr) {
        buffers->push_back(addr);
      }
    }
    for (const auto &child : array->data()->child_data) {
      flattenArrayBuffers(buffers, child);
    }
  }
}

}  // namespace common
}  // namespace fletcher
