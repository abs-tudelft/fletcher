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

#pragma once

#include <arrow/api.h>
#include <arrow/ipc/api.h>
#include <arrow/io/api.h>
#include <fletcher/common.h>

#include <vector>
#include <memory>

#include "fletchgen/options.h"

namespace fletchgen::srec {

/**
 * @brief Generate and save an SREC file from a bunch of RecordBatches and Schemas.
 * @param schemas       The Schemas.
 * @param recordbatches The RecordBatches.
 * @param meta_out      Metadata output about saved RecordBatches.
 * @param out           Output stream to write the SREC file to.
 * @param buffer_align  Alignment in bytes for every RecordBatch buffer.
*/
void GenerateReadSREC(const std::vector<fletcher::RecordBatchDescription> &meta_in,
                      std::vector<fletcher::RecordBatchDescription> *meta_out,
                      std::ofstream *out,
                      int64_t buffer_align);

/**
 * Write SREC formatted RecordBatches to an output stream.
 * @param output        The output stream to write to.
 * @param recordbatches The RecordBatches
 * @return              SREC buffer offsets of the flattened buffers of the RecordBatches
 */
std::vector<uint64_t> WriteRecordBatchesToSREC(std::ostream *output,
                                               const std::vector<std::shared_ptr<arrow::RecordBatch>> &recordbatches);

/**
 * @brief Read an SREC formatted input stream and turn it into a RecordBatch
 *
 * Buffer offsets should follow
 *
 * @param input         The input stream to read from.
 * @param schemas       A vector of Arrow Schemas.
 * @param num_rows      Number of rows for each RecordBatch.
 * @param buf_offsets   The offsets of the flattened buffer.
 * @return              A vector of Arrow RecordBatches filled with contents from the SREC input stream.
 */
std::vector<std::shared_ptr<arrow::RecordBatch>>
ReadRecordBatchesFromSREC(std::istream *input,
                          const std::vector<std::shared_ptr<arrow::Schema>> &schemas,
                          const std::vector<uint64_t> &num_rows,
                          const std::vector<uint64_t> &buf_offsets);

}  // namespace fletchgen::srec
