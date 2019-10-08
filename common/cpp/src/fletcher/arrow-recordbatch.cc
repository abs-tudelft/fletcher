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
  for (const auto &f : fields) {
    for (const auto &b : f.buffers) {
      str << std::setfill(' ') << std::setw(2 * b.level_) << ':'
          << ::fletcher::ToString(b.desc_) << ':' << b.size_ << '\n';
    }
  }
  return str.str();
}

arrow::Status RecordBatchAnalyzer::VisitArray(const arrow::Array &arr) {
  // buf_name += ":" + arr.type()->ToString();
  // buf_name.push_back(arr.type()->ToString());
  // Check if the field is nullable. If so, add the (implicit) validity bitmap buffer
  if (field->nullable()) {
    auto desc = buf_name;
    desc.emplace_back("validity");
    if (arr.null_count() > 0) {
      out_->fields.back().buffers.emplace_back(arr.null_bitmap()->data(), arr.null_bitmap()->size(), desc, level);
    } else {
      auto dummy = std::make_shared<arrow::Buffer>(nullptr, 0);
      out_->fields.back().buffers.emplace_back(dummy->data(), dummy->size(), desc, level, true);
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
    buf_name = {field->name()};
    out_->fields.emplace_back(arr->type(), arr->length(), arr->null_count());
    if (!VisitArray(*arr).ok()) {
      return false;
    }
  }
  return true;
}

arrow::Status RecordBatchAnalyzer::VisitBinary(const arrow::BinaryArray &array) {
  auto odesc = buf_name;
  odesc.emplace_back("offsets");
  auto vdesc = buf_name;
  vdesc.emplace_back("values");
  out_->fields.back().buffers.emplace_back(array.value_offsets()->data(), array.value_offsets()->size(), odesc, level);
  out_->fields.back().buffers.emplace_back(array.value_data()->data(), array.value_data()->size(), vdesc, level);
  return arrow::Status::OK();
}

arrow::Status RecordBatchAnalyzer::Visit(const arrow::ListArray &array) {
  auto desc = buf_name;
  desc.emplace_back("offsets");
  out_->fields.back().buffers.emplace_back(array.value_offsets()->data(), array.value_offsets()->size(), desc, level);
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
  auto struct_name = buf_name;
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
    buf_name.push_back(field->name());
    // Visit the child array
    status = VisitArray(*child_array);
    if (!status.ok())
      return status;
    level--;
  }
  return arrow::Status::OK();
}

}  // namespace fletcher
