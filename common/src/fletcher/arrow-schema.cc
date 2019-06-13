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

#include <vector>
#include <memory>
#include <string>
#include <utility>
#include <arrow/api.h>

#include "fletcher/logging.h"
#include "fletcher/arrow-schema.h"

namespace fletcher {

bool SchemaAnalyzer::Analyze(const arrow::Schema& schema) {
  // RecordBatch is virtual, i.e. there is no physically stored RecordBatch
  out_->is_virtual = true;
  // Get schema/recordbatch name
  out_->name = fletcher::GetMeta(schema, "fletcher_name");
  // Set number of rows to 0
  out_->rows = 0;
  // Depth-first search every column (arrow::Array) for buffers.
  for (int i = 0; i < schema.num_fields(); ++i) {
    // Analyze every field using a FieldAnalyzer.
    FieldMetadata field_meta;
    std::vector<BufferMetadata> buffers_meta;
    FieldAnalyzer fa(&field_meta, &buffers_meta, schema.field(i)->name());
    fa.Analyze(*schema.field(i));
    // Push back the result.
    out_->fields.push_back(field_meta);
    out_->buffers.insert(out_->buffers.end(), buffers_meta.begin(), buffers_meta.end());
  }
  return true;
}

bool FieldAnalyzer::Analyze(const arrow::Field &field) {
  field_out_->null_count_ = 0;
  field_out_->length_ = 0;
  field_out_->type_ = field.type();
  // Check if the field is nullable. If so, add the validity bitmap buffer as expected buffer.
  // As there is no physical RecordBatch, we don't know whether it is implicit or not, and it is assumed to not be
  // implicit.
  if (field.nullable()) {
    buffers_out_->emplace_back(nullptr, 0, buf_name_ + " (null bitmap)", level, false);
  }
  auto status = VisitType(*field.type());
  if (!status.ok()) {
    FLETCHER_LOG(ERROR, "Could not analyze field. ARROW[" + status.ToString() + "]");
  }
  return true;
}

arrow::Status FieldAnalyzer::VisitField(const arrow::Field &field) {
  // Check if the field is nullable. If so, add the validity bitmap buffer as expected buffer.
  // As there is no physical RecordBatch, we don't know whether it is implicit or not, and it is assumed to not be
  // implicit.
  if (field.nullable()) {
    buffers_out_->emplace_back(nullptr, 0, buf_name_ + " (null bitmap)", level, false);
  }
  return VisitType(*field.type());
}

arrow::Status FieldAnalyzer::VisitType(const arrow::DataType &type) {
  buf_name_ += ":" + type.ToString();
  return type.Accept(this);
}

arrow::Status FieldAnalyzer::VisitBinary(const arrow::BinaryType &type) {
  // Suppress unused warning
  (void)type;
  // Expect an offsets buffer
  buffers_out_->emplace_back(nullptr, 0, buf_name_ + " (offsets)", level);
  // Expect a values buffer
  buffers_out_->emplace_back(nullptr, 0, buf_name_ + " (values)", level);
  return arrow::Status::OK();
}

arrow::Status FieldAnalyzer::Visit(const arrow::ListType &type) {
  // Expect an offsets buffer
  buffers_out_->emplace_back(nullptr, 0, buf_name_ + " (offsets)", level);
  // Advance to the next nesting level.
  level++;
  // A list should only have one child.
  if (type.num_children() != 1) {
    return arrow::Status::TypeError("List type does not have exactly one child.");
  }
  // Visit the nested values array
  return VisitType(*type.child(0)->type());
}

arrow::Status FieldAnalyzer::Visit(const arrow::StructType &type) {
  arrow::Status status;
  // Remember this nesting level name
  std::string struct_name = buf_name_;
  for (int i = 0; i < type.num_children(); i++) {
    std::shared_ptr<arrow::DataType> child_type = type.child(i)->type();
    // Go down one nesting level
    level++;
    // Reset the buffer name
    buf_name_ = struct_name;
    // Visit the child array
    status = VisitType(*child_type);
    if (!status.ok())
      return status;
    level--;
  }
  return arrow::Status::OK();
}

} // namespace fletcher