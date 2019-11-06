#include <utility>

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

#include <arrow/api.h>

#include <vector>
#include <memory>
#include <string>

#include "fletcher/arrow-utils.h"

namespace fletcher {

class FieldAnalyzer : public arrow::TypeVisitor {
 public:
  explicit FieldAnalyzer(FieldMetadata *field, std::vector<std::string> prefix = {})
      : field_out_(field), buf_name_(std::move(prefix)) {}
  bool Analyze(const arrow::Field &field);

 protected:
  arrow::Status VisitField(const arrow::Field &field);
  arrow::Status VisitType(const arrow::DataType &type);
  template<typename T>
  arrow::Status VisitFixedWidth(const T &type) {
    // Suppress unused warning
    (void) type;
    auto desc = buf_name_;
    desc.emplace_back("values");
    field_out_->buffers.emplace_back(nullptr, 0, desc, level);
    return arrow::Status::OK();
  }

  arrow::Status VisitBinary(const arrow::BinaryType &type);
  arrow::Status Visit(const arrow::StringType &type) override { return VisitBinary(type); }
  arrow::Status Visit(const arrow::BinaryType &type) override { return VisitBinary(type); }
  arrow::Status Visit(const arrow::ListType &type) override;
  arrow::Status Visit(const arrow::StructType &type) override;

#define VISIT_FIXED_WIDTH(TYPE) \
  arrow::Status Visit(const TYPE& type) override { return VisitFixedWidth<TYPE>(type); }
  VISIT_FIXED_WIDTH(arrow::Int8Type)
  VISIT_FIXED_WIDTH(arrow::Int16Type)
  VISIT_FIXED_WIDTH(arrow::Int32Type)
  VISIT_FIXED_WIDTH(arrow::Int64Type)
  VISIT_FIXED_WIDTH(arrow::UInt8Type)
  VISIT_FIXED_WIDTH(arrow::UInt16Type)
  VISIT_FIXED_WIDTH(arrow::UInt32Type)
  VISIT_FIXED_WIDTH(arrow::UInt64Type)
  VISIT_FIXED_WIDTH(arrow::HalfFloatType)
  VISIT_FIXED_WIDTH(arrow::FloatType)
  VISIT_FIXED_WIDTH(arrow::DoubleType)
  VISIT_FIXED_WIDTH(arrow::Date32Type)
  VISIT_FIXED_WIDTH(arrow::Date64Type)
  VISIT_FIXED_WIDTH(arrow::TimestampType)
  VISIT_FIXED_WIDTH(arrow::Time32Type)
  VISIT_FIXED_WIDTH(arrow::Time64Type)
  VISIT_FIXED_WIDTH(arrow::FixedSizeBinaryType)
  VISIT_FIXED_WIDTH(arrow::Decimal128Type)
#undef VISIT_FIXED_WIDTH

  // TODO(johanpel): Not implemented yet:
  // arrow::Status Visit(const arrow::BooleanType &type) override {}
  // arrow::Status Visit(const arrow::NullType &type) override {}
  // arrow::Status Visit(const UnionType& type) override {}
  // arrow::Status Visit(const DictionaryType& type) override {}
  // arrow::Status Visit(const ExtensionType& type) override {}

  int level = 0;
  FieldMetadata *field_out_;
  std::vector<std::string> buf_name_;
};

/**
 * @brief Class to analyze a Type.
 *
 * This class can generate a virtual RecordBatchDescription; that is, a RecordBatchDescription that describes the
 * expected buffers from an arrow::Schema, but is not present anywhere physically, and thus any pointers inside this
 * structure are invalid. This is useful during generation of specific hardware structures, such as simulation
 * top-levels that don't use Fletcher's memory models.
 */
class SchemaAnalyzer : public arrow::TypeVisitor {
 public:
  explicit SchemaAnalyzer(RecordBatchDescription *out) : out_(out) {}
  ~SchemaAnalyzer() override = default;
  bool Analyze(const arrow::Schema &schema);
 protected:
  RecordBatchDescription *out_{};
};

}  // namespace fletcher
