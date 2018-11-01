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

#include <vector>
#include <memory>

#include <arrow/buffer.h>
#include <arrow/array.h>

namespace fletcher {
namespace common {

/**
 * @brief Append a vector of buffers with the buffers contained within an Arrow::array
 * @param buffers   The buffers to append to
 * @param array     The Arrow::array to append buffers from
 */
void flattenArrayBuffers(std::vector<arrow::Buffer *> *buffers, const std::shared_ptr<arrow::Array> &array);

/**
 * @brief Append a vector of buffers with the buffers contained within an Arrow::ArrayData
 * @param buffers   The buffers to append to
 * @param array     The Arrow::ArrayData to append buffers from
 */
void flattenArrayBuffers(std::vector<arrow::Buffer *> *buffers, const std::shared_ptr<arrow::ArrayData> &array_data);

/**
 * @brief Given an arrow::Field, and corresponding arrow::Array, append the buffers of the array.
 *
 * This is useful in case the Arrow implementation allocated a validity bitmap buffer even though the field (or any
 * child) was defined to be non-nullable. In this case, the flattened buffers will not contain a validity bitmap buffer.
 *
 * @param buffers   The buffers to append to
 * @param array     The Arrow::Array to append buffers from
 * @param field     The arrow::Field from a schema.
 */
void flattenArrayBuffers(std::vector<arrow::Buffer *> *buffers,
                         const std::shared_ptr<arrow::Array> &array,
                         const std::shared_ptr<arrow::Field> &field);

/**
 * @brief Given an arrow::Field, and corresponding arrow::ArrayData, append the buffers of the array.
 *
 * @param buffers   The buffers to append to
 * @param array     The Arrow::ArrayData to append buffers from
 * @param field     The arrow::Field from a schema.
 */
void flattenArrayBuffers(std::vector<arrow::Buffer *> *buffers,
                         const std::shared_ptr<arrow::ArrayData> &array_data,
                         const std::shared_ptr<arrow::Field> &field);

}  // namespace common
}  // namespace fletcher
