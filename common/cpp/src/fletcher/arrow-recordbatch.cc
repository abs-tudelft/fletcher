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

#include <iomanip>
#include <sstream>

#include "fletcher/arrow-recordbatch.h"

namespace fletcher {

std::string RecordBatchDescription::ToString() {
  std::stringstream str;
  for (const auto &b : buffers) {
    str << std::setfill(' ') << std::setw(2 * b.level_) << ':' << b.desc_ << '\n';
  }
  return str.str();
}

arrow::Status RecordBatchAnalyzer::VisitArray(const arrow::Array &arr) {
  arr_name = arr.type()->ToString();
  if (arr.null_count() > 0) {
    out_->buffers.emplace_back(arr.null_bitmap(), arr_name + " (null bitmap)", level);
  } else {
    out_->buffers.emplace_back(std::make_shared<arrow::Buffer>(nullptr, 0), arr_name + " (empty null bitmap)", level);
  }
  return arr.Accept(this);
}

bool RecordBatchAnalyzer::Analyze(const arrow::RecordBatch &batch) {
  // Depth-first search every column (arrow::Array) for buffers.
  for (int i = 0; i < batch.num_columns(); ++i) {
    auto arr = batch.column(i);
    out_->fields.emplace_back(arr->type(), arr->length(), arr->null_count());
    if (!VisitArray(*arr).ok()) {
      return false;
    }
  }
  return true;
}

arrow::Status RecordBatchAnalyzer::VisitBinary(const arrow::BinaryArray &array) {
  out_->buffers.emplace_back(array.value_offsets(), arr_name + " (offsets)", level);
  out_->buffers.emplace_back(array.value_data(), arr_name + " (values)", level);
  return arrow::Status::OK();
}

arrow::Status RecordBatchAnalyzer::Visit(const arrow::ListArray &array) {
  out_->buffers.emplace_back(array.value_offsets(), arr_name + " (offsets)", level);
  level++;
  return VisitArray(*array.values());
}

arrow::Status RecordBatchAnalyzer::Visit(const arrow::StructArray &array) {
  for (int i = 0; i < array.num_fields(); ++i) {
    std::shared_ptr<arrow::Array> field = array.field(i);
    level++;
    RETURN_NOT_OK(VisitArray(*field));
    level--;
  }
  return arrow::Status::OK();
}
} // namespace fletcher