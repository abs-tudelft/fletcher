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

#include "fletcher/common/hex-view.h"
#include "fletcher/common/arrow-utils.h"

#include "./recordbatch.h"

namespace fletchgen {
namespace srec {

std::vector<uint64_t> getBufferOffsets(std::vector<arrow::Buffer *> &buffers) {
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

std::vector<uint64_t> writeRecordBatchToSREC(arrow::RecordBatch *record_batch,
                                             const std::string &srec_fname) {

  std::vector<arrow::Buffer *> buffers;
  for (int c = 0; c < record_batch->num_columns(); c++) {
    auto column = record_batch->column(c);
    fletcher::flattenArrayBuffers(&buffers, column);
  }

  LOGD("RecordBatch has " + std::to_string(buffers.size()) + " Arrow buffers.");
  auto offsets = getBufferOffsets(buffers);
  LOGD("Contiguous size: " + std::to_string(offsets.back()));

  // Generate a warning when stuff gets larger than a megabyte.
  if (offsets.back() > 1024 * 1024) {
    LOGW("The recordbatch you are trying to serialize is very large. "
         "Use the SREC utility only for functional verification purposes in simulation.");
  }

  unsigned int i = 0;
  for (const auto &buf : buffers) {
    fletcher::HexView hv(0);
    hv.addData(buf->data(), static_cast<size_t>(buf->size()));
    LOGD("Buffer " + std::to_string(i) + " : " + std::to_string(buf->size()) + " bytes. " +
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

} // namespace srec
} // namespace fletchgen
