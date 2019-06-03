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
#include <ostream>

#include <arrow/api.h>
#include <arrow/buffer.h>
#include <cerata/api.h>
#include <fletcher/common.h>

#include "fletchgen/options.h"
#include "fletchgen/srec/recordbatch.h"
#include "fletchgen/srec/srec.h"

namespace fletchgen::srec {

std::vector<uint64_t> GenerateSREC(const std::shared_ptr<fletchgen::Options> &options,
                                   const std::vector<std::shared_ptr<arrow::Schema>> &schemas,
                                   std::vector<std::pair<uint32_t, uint32_t>> *first_last_idx) {
  if (options->recordbatch_paths.size() != schemas.size()) {
    throw std::runtime_error("Number of schemas does not correspond to number of RecordBatches.");
  }

  std::deque<std::shared_ptr<arrow::RecordBatch>> recordbatches;
  for (size_t i = 0; i < schemas.size(); i++) {
    // Only read RecordBatch files for Read schemas, and add their contents to the SREC file
    if (fletcher::GetMode(schemas[i]) == fletcher::Mode::READ) {
      auto rb = fletcher::ReadRecordBatchFromFile(options->recordbatch_paths[i], schemas[i]);
      recordbatches.push_back(rb);
      if (first_last_idx != nullptr) {
        // Read schemas are assumed to go over the whole range for automatic simulation top-level generation.
        (*first_last_idx).emplace_back(0, rb->num_rows());
      }
    } else {
      // Write schemas just get firstidx and lastidx set to 0.
      if (first_last_idx != nullptr) {
        (*first_last_idx).emplace_back(0, 0);
      }
    }
  }

  auto ofs = std::ofstream(options->srec_out_path);
  if (!ofs.good()) {
    FLETCHER_LOG(ERROR, "Could not open " + options->srec_out_path + " for writing.");
  }
  std::vector<uint64_t> offsets = fletchgen::srec::WriteRecordBatchesToSREC(&ofs, recordbatches);
  return offsets;
}

std::vector<uint64_t> GetBufferOffsets(std::vector<arrow::Buffer *> &buffers) {
  size_t addr = 0;
  std::vector<size_t> ret;

  for (const auto &buf : buffers) {
    // Push back the current address.
    ret.push_back(addr);
    // Calculate the next address.
    addr += (buf->size() / 64) * 64;
    if ((buf->size() % 64) != 0) {
      addr += 64;
    }
  }
  // Push back the last next address. Useful to know the total contiguous size.
  ret.push_back(addr);
  return ret;
}

std::vector<uint64_t> WriteRecordBatchesToSREC(std::ostream *output,
                                               const std::deque<std::shared_ptr<arrow::RecordBatch>> &recordbatches) {

  std::vector<arrow::Buffer *> buffers;

  // Get pointers to all buffers of all recordbatches
  for (const auto &rb : recordbatches) {
    for (int c = 0; c < rb->num_columns(); c++) {
      auto column = rb->column(c);
      fletcher::FlattenArrayBuffers(&buffers, column);
    }
  }

  FLETCHER_LOG(DEBUG, "RecordBatches have " + std::to_string(buffers.size()) + " Arrow Buffers.");
  auto offsets = GetBufferOffsets(buffers);
  FLETCHER_LOG(DEBUG, "Contiguous size: " + std::to_string(offsets.back()));

  // Generate a warning when buffers get larger than a 42 kibibytes.
  if (offsets.back() > 42 * 1024) {
    FLETCHER_LOG(WARNING, "The RecordBatch you are trying to serialize is rather large (greater than 42 KiB)."
                          "The SREC utility is meant for functional verification purposes in simulation only."
                          "Consider making your RecordBatch smaller.");
  }

  unsigned int i = 0;
  for (const auto &buf : buffers) {
    fletcher::HexView hv(0);
    hv.AddData(buf->data(), static_cast<size_t>(buf->size()));
    FLETCHER_LOG(DEBUG, "Buffer " + std::to_string(i) + " : " + std::to_string(buf->size()) + " bytes. " +
        "Start address: " + std::to_string(offsets[i]) + "\n" +
        hv.ToString());
    i++;
  }

  // Serialize all the buffers into one contiguous buffer.
  auto srecbuf = (uint8_t *) calloc(1, offsets.back());
  for (i = 0; i < buffers.size(); i++) {
    memcpy(&srecbuf[offsets[i]], buffers[i]->data(), static_cast<size_t>(buffers[i]->size()));
  }

  srec::File sr(0, srecbuf, offsets.back());
  if (output->good()) {
    sr.write(output);
  } else {
    FLETCHER_LOG(ERROR, "Output stream unavailable. SREC was not written.");
  }
  free(srecbuf);
  return offsets;
}

std::deque<std::shared_ptr<arrow::RecordBatch>> ReadRecordBatchesFromSREC(std::istream *input,
                                                                          const std::deque<std::shared_ptr<arrow::Schema>> &schemas,
                                                                          const std::vector<uint64_t> &num_rows,
                                                                          const std::vector<uint64_t> &buf_offsets) {
  std::deque<std::shared_ptr<arrow::RecordBatch>> ret;
  // TODO(johanpel): implement this
  FLETCHER_LOG(ERROR, "SREC to RecordBatch not yet implemented.");
  return ret;
}

} // namespace fletchgen::srec
