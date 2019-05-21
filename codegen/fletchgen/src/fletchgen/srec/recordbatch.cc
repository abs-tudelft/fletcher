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
#include <fstream>

#include <arrow/api.h>
#include <cerata/api.h>
#include <fletcher/common.h>

#include "fletchgen/options.h"
#include "fletchgen/srec/recordbatch.h"
#include "fletchgen/srec/srec.h"

namespace fletchgen::srec {

std::vector<uint64_t> GenerateSREC(const std::shared_ptr<fletchgen::Options> &options,
                                   const std::vector<std::shared_ptr<arrow::Schema>> &schemas,
                                   std::vector<std::pair<uint32_t, uint32_t>> *firstlastidx) {
  if (options->recordbatch_paths.size() != schemas.size()) {
    throw std::runtime_error("Number of schemas does not correspond to number of RecordBatches.");
  }

  std::deque<std::shared_ptr<arrow::RecordBatch>> recordbatches;
  for (size_t i = 0; i < schemas.size(); i++) {
    // Only read RecordBatch files for Read schemas, and add their contents to the SREC file
    if (fletcher::GetMode(schemas[i]) == fletcher::Mode::READ) {
      auto rb = fletcher::ReadRecordBatchFromFile(options->recordbatch_paths[i], schemas[i]);
      recordbatches.push_back(rb);
      if (firstlastidx != nullptr) {
        // Read schemas are assumed to go over the whole range for automatic simulation top-level generation.
        (*firstlastidx).emplace_back(0, rb->num_rows());
      }
    } else {
      // Write schemas just get firstidx and lastidx set to 0.
      if (firstlastidx != nullptr) {
        (*firstlastidx).emplace_back(0, 0);
      }
    }
  }

  // Generate the SREC file
  auto srec_buffer_offsets = fletchgen::srec::WriteRecordBatchesToSREC(recordbatches, options->srec_out_path);

  return srec_buffer_offsets;
}

std::vector<uint64_t> GetBufferOffsets(std::vector<arrow::Buffer *> &buffers) {
  size_t addr = 0;
  std::vector<size_t> ret;

  for (const auto &buf : buffers) {
    ret.push_back(addr);
    addr += (buf->size() / 64) * 64;
    if ((buf->size() % 64) != 0) {
      addr += 64;
    }
  }
  ret.push_back(addr);
  return ret;
}

std::vector<uint64_t> WriteRecordBatchesToSREC(const std::deque<std::shared_ptr<arrow::RecordBatch>> &recordbatches,
                                               const std::string &srec_fname) {

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

  // Generate a warning when stuff gets larger than a megabyte.
  if (offsets.back() > 1024 * 1024) {
    FLETCHER_LOG(WARNING, "The recordbatch you are trying to serialize is very large. "
                          "Use the SREC utility only for functional verification purposes in simulation.");
  }

  unsigned int i = 0;
  for (const auto &buf : buffers) {
    fletcher::HexView hv(0);
    hv.addData(buf->data(), static_cast<size_t>(buf->size()));
    FLETCHER_LOG(DEBUG, "Buffer " + std::to_string(i) + " : " + std::to_string(buf->size()) + " bytes. " +
        "Start address: " + std::to_string(offsets[i]) + "\n" +
        hv.toString());
    i++;
  }

  auto srecbuf = (uint8_t *) calloc(1, offsets.back());

  for (i = 0; i < buffers.size(); i++) {
    memcpy(&srecbuf[offsets[i]], buffers[i]->data(), static_cast<size_t>(buffers[i]->size()));
  }

  srec::File sr(srecbuf, offsets.back(), 0);
  std::ofstream ofs(srec_fname, std::ofstream::out);
  sr.write(ofs);
  ofs.close();
  free(srecbuf);
  return offsets;
}

} // namespace fletchgen::srec
