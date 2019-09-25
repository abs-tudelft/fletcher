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

#include <arrow/api.h>

#include <vector>
#include <memory>
#include <string>

#include "fletcher/logging.h"
#include "fletcher/arrow-schema.h"

namespace fletcher {

bool SchemaAnalyzer::Analyze(const arrow::Schema &schema) {
  // RecordBatch is virtual, i.e. there is no physically stored RecordBatch
  out_->is_virtual = true;
  // Get schema/recordbatch name
  out_->name = fletcher::GetMeta(schema, "fletcher_name");
  // Set number of rows to 0
  out_->rows = 0;

  // Analyze every field using a FieldAnalyzer.
  for (int i = 0; i < schema.num_fields(); ++i) {
    FieldMetadata field_meta;
    FieldAnalyzer fa(&field_meta, {schema.field(i)->name()});
    fa.Analyze(*schema.field(i));
    out_->fields.push_back(field_meta);
  }
  return true;
}

bool FieldAnalyzer::Analyze(const arrow::Field &field) {
  field_out_->null_count = 0;
  field_out_->length = 0;
  field_out_->type_ = field.type();
  // Check if the field is nullable. If so, add the validity bitmap buffer as expected buffer.
  // As there is no physical RecordBatch, we don't know whether it is implicit or not, and it is assumed to not be
  // implicit.
  if (field.nullable()) {
    auto desc = buf_name_;
    desc.emplace_back("validity");
    field_out_->buffers.emplace_back(nullptr, 0, desc, level, false);
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
    auto desc = buf_name_;
    desc.emplace_back("validity");
    field_out_->buffers.emplace_back(nullptr, 0, desc, level, false);
  }
  return VisitType(*field.type());
}

arrow::Status FieldAnalyzer::VisitType(const arrow::DataType &type) {
  // buf_name_.push_back(type.ToString());
  // buf_name_ += ":" + type.ToString();
  return type.Accept(this);
}

arrow::Status FieldAnalyzer::VisitBinary(const arrow::BinaryType &type) {
  // Suppress unused warning
  (void) type;
  // Expect an offsets buffer
  auto odesc = buf_name_;
  odesc.emplace_back("offsets");
  field_out_->buffers.emplace_back(nullptr, 0, odesc, level);
  // Expect a values buffer
  auto vdesc = buf_name_;
  vdesc.emplace_back("values");
  field_out_->buffers.emplace_back(nullptr, 0, vdesc, level);
  return arrow::Status::OK();
}

arrow::Status FieldAnalyzer::Visit(const arrow::ListType &type) {
  // Expect an offsets buffer
  auto desc = buf_name_;
  desc.emplace_back("offsets");
  field_out_->buffers.emplace_back(nullptr, 0, desc, level);
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
  auto struct_name = buf_name_;
  for (int i = 0; i < type.num_children(); i++) {
    std::shared_ptr<arrow::DataType> child_type = type.child(i)->type();
    // Go down one nesting level
    level++;
    // Reset the buffer name
    buf_name_ = struct_name;
    buf_name_.push_back(type.child(i)->name());
    // Visit the child array
    status = VisitType(*child_type);
    if (!status.ok())
      return status;
    level--;
  }
  return arrow::Status::OK();
}

}  // namespace fletcher
