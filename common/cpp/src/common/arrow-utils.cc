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

void flattenArrayBuffers(std::vector<arrow::Buffer *> *buffers, const std::shared_ptr<arrow::ArrayData> &array_data) {
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

void flattenArrayBuffers(std::vector<arrow::Buffer *> *buffers, const std::shared_ptr<arrow::Array> &array) {
  // Because Arrow buffer order seems to be by convention and not by specification, handle these special cases:
  // This is to reverse the order of offset and values buffer to correspond with the hardware implementation.
  if (array->type() == arrow::binary()) {
    auto ba = std::static_pointer_cast<arrow::BinaryArray>(array);
    buffers->push_back(ba->value_data().get());
    buffers->push_back(ba->value_offsets().get());
  } else if (array->type() == arrow::utf8()) {
    auto sa = std::static_pointer_cast<arrow::StringArray>(array);
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

void flattenArrayBuffers(std::vector<arrow::Buffer *> *buffers,
                         const std::shared_ptr<arrow::ArrayData> &array_data,
                         const std::shared_ptr<arrow::Field> &field) {
  size_t b = 0;
  if (!field->nullable()) {
    b = 1;
  } else if (array_data->null_count == 0) {
    buffers->push_back(nullptr);
    b = 1;
  }
  for (; b < array_data->buffers.size(); b++) {
    auto addr = array_data->buffers[b].get();
    if (addr != nullptr) {
      buffers->push_back(addr);
    }
    for (size_t c = 0; c < array_data->child_data.size(); c++) {
      flattenArrayBuffers(buffers, array_data->child_data[c], field->type()->child(static_cast<int>(c)));
    }
  }
}

void flattenArrayBuffers(std::vector<arrow::Buffer *> *buffers,
                         const std::shared_ptr<arrow::Array> &array,
                         const std::shared_ptr<arrow::Field> &field) {
  if (field->type()->id() != array->type()->id()) {
    throw std::runtime_error("Incompatible schema.");
  }
  if (array->type() == arrow::binary()) {
    auto ba = std::static_pointer_cast<arrow::BinaryArray>(array);
    if (field->nullable() && (ba->null_count() == 0)) {
      buffers->push_back(nullptr);
    }
    buffers->push_back(ba->value_data().get());
    buffers->push_back(ba->value_offsets().get());
  } else if (array->type() == arrow::utf8()) {
    auto sa = std::static_pointer_cast<arrow::StringArray>(array);
    if (field->nullable() && (sa->null_count() == 0)) {
      buffers->push_back(nullptr);
    }
    buffers->push_back(sa->value_data().get());
    buffers->push_back(sa->value_offsets().get());
  } else {
    size_t b = 0;
    if (!field->nullable()) {
      b = 1;
    } else if (array->null_count() == 0) {
      buffers->push_back(nullptr);
      b = 1;
    }
    for (; b < array->data()->buffers.size(); b++) {
      auto addr = array->data()->buffers[b].get();
      if (addr != nullptr) {
        buffers->push_back(addr);
      }
    }
    for (size_t c = 0; c < array->data()->child_data.size(); c++) {
      flattenArrayBuffers(buffers, array->data()->child_data[c], field->type()->child(static_cast<int>(c)));
    }
  }
}

}  // namespace common
}  // namespace fletcher
