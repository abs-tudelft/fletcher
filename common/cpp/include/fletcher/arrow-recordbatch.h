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
#include <string>
#include <utility>
#include <arrow/api.h>

#include "fletcher/arrow-utils.h"

namespace fletcher {

/**
 * @brief Class to analyze a RecordBatch.
 *
 * Follows the general approach of the RecordBatchSerializer in arrow::ipc, but is more simplified as it only has to
 * figure out where all the buffers are.
 */
class RecordBatchAnalyzer : public arrow::ArrayVisitor {
 public:
  explicit RecordBatchAnalyzer(RecordBatchDescription *out) : out_(out) {}
  ~RecordBatchAnalyzer() override = default;
  bool Analyze(const arrow::RecordBatch &batch);

 protected:
  arrow::Status VisitArray(const arrow::Array &arr);

  template<typename ArrayType>
  arrow::Status VisitFixedWidth(const ArrayType &array) {
    std::shared_ptr<arrow::Buffer> buf = array.values();
    auto desc = buf_name;
    desc.emplace_back("values");
    out_->fields.back().buffers.emplace_back(buf->data(), buf->size(), desc, level);
    return arrow::Status::OK();
  }

  arrow::Status VisitBinary(const arrow::BinaryArray &array);
  arrow::Status Visit(const arrow::StringArray &array) override { return VisitBinary(array); }
  arrow::Status Visit(const arrow::BinaryArray &array) override { return VisitBinary(array); }
  arrow::Status Visit(const arrow::ListArray &array) override;
  arrow::Status Visit(const arrow::StructArray &array) override;

#define VISIT_FIXED_WIDTH(TYPE) \
  arrow::Status Visit(const TYPE& array) override { return VisitFixedWidth<TYPE>(array); }
  VISIT_FIXED_WIDTH(arrow::Int8Array)
  VISIT_FIXED_WIDTH(arrow::Int16Array)
  VISIT_FIXED_WIDTH(arrow::Int32Array)
  VISIT_FIXED_WIDTH(arrow::Int64Array)
  VISIT_FIXED_WIDTH(arrow::UInt8Array)
  VISIT_FIXED_WIDTH(arrow::UInt16Array)
  VISIT_FIXED_WIDTH(arrow::UInt32Array)
  VISIT_FIXED_WIDTH(arrow::UInt64Array)
  VISIT_FIXED_WIDTH(arrow::HalfFloatArray)
  VISIT_FIXED_WIDTH(arrow::FloatArray)
  VISIT_FIXED_WIDTH(arrow::DoubleArray)
  VISIT_FIXED_WIDTH(arrow::Date32Array)
  VISIT_FIXED_WIDTH(arrow::Date64Array)
  VISIT_FIXED_WIDTH(arrow::TimestampArray)
  VISIT_FIXED_WIDTH(arrow::Time32Array)
  VISIT_FIXED_WIDTH(arrow::Time64Array)
  VISIT_FIXED_WIDTH(arrow::FixedSizeBinaryArray)
  VISIT_FIXED_WIDTH(arrow::Decimal128Array)
#undef VISIT_FIXED_WIDTH

  // TODO(johanpel): Not implemented yet:
  //arrow::Status Visit(const arrow::BooleanArray &array) override {}
  //arrow::Status Visit(const arrow::NullArray &array) override {}
  //arrow::Status Visit(const UnionArray& array) override {}
  //arrow::Status Visit(const DictionaryArray& array) override {}
  //arrow::Status Visit(const ExtensionArray& array) override {}

  std::vector<std::string> buf_name;
  int level = 0;
  RecordBatchDescription *out_{};
  std::shared_ptr<arrow::Field> field;
};

}