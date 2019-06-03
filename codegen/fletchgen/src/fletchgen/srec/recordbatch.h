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

} // namespace fletchgen::srec


