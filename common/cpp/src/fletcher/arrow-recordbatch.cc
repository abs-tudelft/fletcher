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

#include "fletcher/common.h"

namespace fletcher {

std::string RecordBatchDescription::ToString() const {
  std::stringstream str;
  for (const auto &b : buffers) {
    str << std::setfill(' ') << std::setw(2 * b.level_) << ':' << b.desc_ << ':' << b.size_ << '\n';
  }
  return str.str();
}

arrow::Status RecordBatchAnalyzer::VisitArray(const arrow::Array &arr) {
  buf_name += ":" + arr.type()->ToString();
  // Check if the field is nullable. If so, add the (implicit) validity bitmap buffer
  if (field->nullable()) {
    if (arr.null_count() > 0) {
      out_->buffers.emplace_back(arr.null_bitmap()->data(),
                                 arr.null_bitmap()->size(),
                                 buf_name + " (null bitmap)",
                                 level);
    } else {
      auto dummy = std::make_shared<arrow::Buffer>(nullptr, 0);
      out_->buffers.emplace_back(dummy->data(), dummy->size(), buf_name + " (empty null bitmap)", level, true);
    }
  }
  return arr.Accept(this);
}

bool RecordBatchAnalyzer::Analyze(const arrow::RecordBatch &batch) {
  out_->name = fletcher::GetMeta(*batch.schema(), "fletcher_name");
  out_->rows = batch.num_rows();
  // Depth-first search every column (arrow::Array) for buffers.
  for (int i = 0; i < batch.num_columns(); ++i) {
    auto arr = batch.column(i);
    // Remember what field we are at
    field = batch.schema()->field(i);
    buf_name = field->name();
    out_->fields.emplace_back(arr->type(), arr->length(), arr->null_count());
    if (!VisitArray(*arr).ok()) {
      return false;
    }
  }
  return true;
}

arrow::Status RecordBatchAnalyzer::VisitBinary(const arrow::BinaryArray &array) {
  out_->buffers.emplace_back(array.value_offsets()->data(),
                             array.value_offsets()->size(),
                             buf_name + " (offsets)",
                             level);
  out_->buffers.emplace_back(array.value_data()->data(), array.value_data()->size(), buf_name + " (values)", level);
  return arrow::Status::OK();
}

arrow::Status RecordBatchAnalyzer::Visit(const arrow::ListArray &array) {
  out_->buffers.emplace_back(array.value_offsets()->data(),
                             array.value_offsets()->size(),
                             buf_name + " (offsets)",
                             level);
  // Advance to the next nesting level.
  level++;
  // A list should only have one child.
  if (field->type()->num_children() != 1) {
    return arrow::Status::TypeError("List type does not have exactly one child.");
  }
  field = field->type()->child(0);
  // Visit the nested values array
  return VisitArray(*array.values());
}

arrow::Status RecordBatchAnalyzer::Visit(const arrow::StructArray &array) {
  arrow::Status status;
  // Remember this field and name
  std::shared_ptr<arrow::Field> struct_field = field;
  std::string struct_name = buf_name;
  // Check if number of child arrays is the same as the number of child fields in the struct type.
  if (array.num_fields() != struct_field->type()->num_children()) {
    return arrow::Status::TypeError(
        "Number of child arrays for struct does not match number of child fields for field type.");
  }
  for (int i = 0; i < array.num_fields(); ++i) {
    std::shared_ptr<arrow::Array> child_array = array.field(i);
    // Go down one nesting level
    level++;
    // Select the struct field
    field = struct_field->type()->child(i);
    buf_name = struct_name;
    // Visit the child array
    status = VisitArray(*child_array);
    if (!status.ok())
      return status;
    level--;
  }
  return arrow::Status::OK();
}
} // namespace fletcher