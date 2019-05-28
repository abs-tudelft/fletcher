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
#include <arrow/api.h>
#include <arrow/ipc/api.h>
#include <arrow/io/api.h>
#include <arrow/ipc/writer.h>

#include "fletchgen/options.h"

namespace fletchgen::srec {

/**
 * @brief Generate and save an SREC file from a bunch of recordbatches and schemas.
 * @param options       Fletchgen options.
 * @param schemas       Schemas.
 * @param first_last_idx  A vector to store Fletcher command stream first and last indices of a RecordBatch.
 * @return              A vector of buffer addresses in the SREC.
 */
std::vector<uint64_t> GenerateSREC(const std::shared_ptr<fletchgen::Options> &options,
                                   const std::vector<std::shared_ptr<arrow::Schema>> &schemas,
                                   std::vector<std::pair<uint32_t, uint32_t>> *first_last_idx = nullptr);

/**
 * @brief Calculate buffer offsets if all buffers would be stored contiguously.
* @param buffers   The buffers.
 * @return          The required size of the contiguous space.
 */
std::vector<uint64_t> GetBufferOffsets(std::vector<arrow::Buffer *> &buffers);

/**
 * Write SREC formatted RecordBatches to an output stream.
 * @param output        The output stream to write to.
 * @param recordbatches The RecordBatches
 * @return              SREC buffer offsets of the flattened buffers of the RecordBatches
 */
std::vector<uint64_t> WriteRecordBatchesToSREC(std::ostream *output,
                                               const std::deque<std::shared_ptr<arrow::RecordBatch>> &recordbatches);

/**
 * @brief Read an SREC formatted input stream and turn it into a RecordBatch
 *
 * Buffer offsets should follow
 *
 * @param input         The input stream to read from.
 * @param schemas       A deque of Arrow Schemas.
 * @param num_rows      Number of rows for each RecordBatch.
 * @param buf_offsets   The offsets of the flattened buffer.
 * @return              A deque of Arrow RecordBatches filled with contents from the SREC input stream.
 */
std::deque<std::shared_ptr<arrow::RecordBatch>> ReadRecordBatchesFromSREC(std::istream *input,
                                                                          const std::deque<std::shared_ptr<arrow::Schema>> &schemas,
                                                                          const std::vector<uint64_t> &num_rows,
                                                                          const std::vector<uint64_t> &buf_offsets);

/**
 * aaaaaaaaaaaabstraaaaaaaaaaactiiiiiiioooooooooooonnnnnnnn
 */

struct Payload {
  //Message::Type type;
  std::shared_ptr<arrow::Buffer> metadata;
  std::vector<std::shared_ptr<arrow::Buffer>> body_buffers;
  int64_t body_length;
};

struct FieldMetadata {
  int64_t length;
  int64_t null_count;
  int64_t offset;
};

struct BufferMetadata {
  int64_t offset;
  int64_t length;
};

static inline int64_t PaddedLength(int64_t nbytes, int32_t alignment = 64) {
  return ((nbytes + alignment - 1) / alignment) * alignment;
}

static inline bool NeedTruncate(int64_t offset, const arrow::Buffer *buffer, int64_t min_length) {
  // buffer can be NULL
  if (buffer == nullptr) {
    return false;
  }
  return offset != 0 || min_length < buffer->size();
}

/**
 * fgljdfghdglasfjik;uhasdfgjkl;hfgsdlkjsdfghsdfglkj
 */
class AlignedRecordBatchSerializer : public arrow::ArrayVisitor {
 public:

  AlignedRecordBatchSerializer(int64_t buffer_start_offset,
                               int64_t alignment,
                               uint8_t max_recursion_depth,
                               Payload *out)
      : out_(out),
        max_recursion_depth_(max_recursion_depth),
        buffer_start_offset_(buffer_start_offset),
        alignment_(alignment) {}

  ~AlignedRecordBatchSerializer() override = default;

  arrow::Status VisitArray(const arrow::Array &arr) {
    if (max_recursion_depth_ <= 0) {
      return arrow::Status::Invalid("Max recursion depth reached");
    }
    if (arr.length() > std::numeric_limits<int32_t>::max()) {
      return arrow::Status::CapacityError("Cannot write arrays larger than 2^31 - 1 in length");
    }
    field_nodes_.push_back({arr.length(), arr.null_count(), 0});
    if (arr.null_count() > 0) {
      out_->body_buffers.emplace_back(arr.null_bitmap());
    } else {
      out_->body_buffers.emplace_back(std::make_shared<arrow::Buffer>(nullptr, 0));
    }
    return arr.Accept(this);
  }

  void Assemble(const arrow::RecordBatch &batch) {
    if (!field_nodes_.empty()) {
      field_nodes_.clear();
      buffer_meta_.clear();
      out_->body_buffers.clear();
    }
    // Perform depth-first traversal of the row-batch
    for (int i = 0; i < batch.num_columns(); ++i) {
      if (!VisitArray(*batch.column(i)).ok()) {
        throw std::runtime_error("pls halp");
      }
    }
    int64_t offset = buffer_start_offset_;
    buffer_meta_.reserve(out_->body_buffers.size());
    // Construct the buffer metadata for the record batch header
    for (auto &body_buffer : out_->body_buffers) {
      const arrow::Buffer *buffer = body_buffer.get();
      int64_t size = 0;
      int64_t padding = 0;
      if (buffer) {
        size = buffer->size();
        padding = arrow::BitUtil::RoundUpToMultipleOf64(size) - size;
      }
      buffer_meta_.push_back({offset, size + padding});
      offset += size + padding;
    }

    out_->body_length = offset - buffer_start_offset_;
    if (!arrow::BitUtil::IsMultipleOf64(out_->body_length)) {
      throw std::runtime_error("oh noes");
    }
  }

 protected:
  template<typename ArrayType>
  arrow::Status VisitFixedWidth(const ArrayType &array) {
    std::shared_ptr<arrow::Buffer> data = array.values();

    const auto &fw_type = dynamic_cast<arrow::FixedWidthType *>(array.type().get());
    const int64_t type_width = fw_type->bit_width() / 8;
    int64_t min_length = PaddedLength(array.length() * type_width);

    if (NeedTruncate(array.offset(), data.get(), min_length)) {
      // Non-zero offset, slice the buffer
      const int64_t byte_offset = array.offset() * type_width;

      // Send padding if it's available
      const int64_t buffer_length =
          std::min(arrow::BitUtil::RoundUpToMultipleOf64(array.length() * type_width),
                   data->size() - byte_offset);
      data = SliceBuffer(data, byte_offset, buffer_length);
    }
    out_->body_buffers.emplace_back(data);
    return arrow::Status::OK();
  }

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

  //arrow::Status Visit(const arrow::BooleanArray &array) override {}
  //arrow::Status Visit(const arrow::NullArray &array) override {}
  //arrow::Status Visit(const arrow::StringArray &array) override {}
  //arrow::Status Visit(const arrow::BinaryArray &array) override {}
  //arrow::Status Visit(const arrow::ListArray &array) override {}
  //arrow::Status Visit(const arrow::StructArray &array) override {}
  //arrow::Status Visit(const UnionArray& array) override {}
  //arrow::Status Visit(const DictionaryArray& array) override {}
  //arrow::Status Visit(const ExtensionArray& array) override {}

  Payload *out_;
  std::vector<FieldMetadata> field_nodes_;
  std::vector<BufferMetadata> buffer_meta_;
  uint8_t max_recursion_depth_;
  int64_t buffer_start_offset_;
  int64_t alignment_;

};

} // namespace fletchgen::srec


