// Copyright 2018-2019 Delft University of Technology
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

#include "fletchgen/srec/recordbatch.h"

#include <arrow/api.h>
#include <fletcher/common.h>

#include <vector>
#include <memory>
#include <ostream>
#include <fstream>

#include "fletchgen/srec/srec.h"

namespace fletchgen::srec {

static inline size_t PaddedLength(size_t size, size_t alignment) {
  return ((size + alignment - 1) / alignment) * alignment;
}

void GenerateReadSREC(const std::vector<fletcher::RecordBatchDescription> &meta_in,
                      std::vector<fletcher::RecordBatchDescription> *meta_out,
                      std::ofstream *out,
                      int64_t buffer_align) {
  // We need to align each buffer into the SREC stream.
  // We start at offset 0.
  uint64_t offset = 0;
  for (const auto &desc_in : meta_in) {
    fletcher::RecordBatchDescription desc_out = desc_in;
    // We can only copy data from physically existing recordbatches into the SREC
    if (!desc_in.is_virtual) {
      desc_out.fields.clear();
      for (const auto &f : desc_in.fields) {
        desc_out.fields.emplace_back(f.type_, f.length, f.null_count);
        FLETCHER_LOG(DEBUG, "RecordBatch " + desc_in.name + " buffers: \n" + desc_in.ToString());
        for (const auto &buf : f.buffers) {
          // May the force be with us
          auto srec_buf_address = reinterpret_cast<uint8_t *>(offset);
          // Determine the place of the buffer in the SREC output
          desc_out.fields.back().buffers.emplace_back(srec_buf_address, buf.size_, buf.desc_, buf.level_);

          // Print some debug info
          auto hv = fletcher::HexView(offset);
          hv.AddData(buf.raw_buffer_, buf.size_);
          FLETCHER_LOG(DEBUG, fletcher::ToString(buf.desc_) + "\n" + hv.ToString());

          // Calculate the padded length and calculate the next offset.
          auto padded_size = PaddedLength(buf.size_, buffer_align);
          offset = offset + padded_size;
        }
      }
    }
    meta_out->push_back(desc_out);
  }
  // We have now determined the location of every buffer in the SREC file and we know the total size of the resulting
  // file in bytes. We must now create the actual SREC file. Calloc some space to serialize the Arrow buffers into.
  auto srec_buffer = static_cast<uint8_t *>(calloc(1, offset));

  // Copy over every buffer.
  for (size_t r = 0; r < meta_in.size(); r++) {
    if (!meta_in[r].is_virtual) {
      for (size_t f = 0; f < meta_in[r].fields.size(); f++) {
        for (size_t b = 0; b < meta_in[r].fields[f].buffers.size(); b++) {
          auto srec_off = reinterpret_cast<size_t>(meta_out->at(r).fields[f].buffers[b].raw_buffer_);
          auto dest = srec_buffer + srec_off;
          auto src = meta_in[r].fields[f].buffers[b].raw_buffer_;
          auto size = meta_in[r].fields[f].buffers[b].size_;
          // skip empty buffers (typically implicit validity buffers)
          if (src != nullptr) {
            memcpy(dest, src, size);
          }
        }
      }
    }
  }

  // Create the SREC file, start at 0
  srec::File sr(0, srec_buffer, offset);
  if (out->good()) {
    sr.write(out);
  } else {
    FLETCHER_LOG(ERROR, "Output stream unavailable. SREC was not written.");
  }

  free(srec_buffer);
}

std::vector<std::shared_ptr<arrow::RecordBatch>>
ReadRecordBatchesFromSREC(std::istream *input,
                          const std::vector<std::shared_ptr<arrow::Schema>> &schemas,
                          const std::vector<uint64_t> &num_rows,
                          const std::vector<uint64_t> &buf_offsets) {
  std::vector<std::shared_ptr<arrow::RecordBatch>> ret;
  // TODO(johanpel): implement this
  FLETCHER_LOG(ERROR, "SREC to RecordBatch not yet implemented.");
  return ret;
}

}  // namespace fletchgen::srec
