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

#include "fletchgen/options.h"

namespace fletchgen::srec {

/**
 * @brief Generate and save an SREC file from a bunch of recordbatches and schemas.
 * @param options       Fletchgen options.
 * @param schemas       Schemas.
 * @param firstlastidx  A vector to store Fletcher command stream first and last indices of a RecordBatch.
 * @return              A vector of buffer addresses in the SREC.
 */
std::vector<uint64_t> GenerateSREC(const std::shared_ptr<fletchgen::Options> &options,
                                   const std::vector<std::shared_ptr<arrow::Schema>> &schemas,
                                   std::vector<std::pair<uint32_t, uint32_t>>* firstlastidx=nullptr);

/**
 * @brief Calculate buffer offsets if all buffers would be stored contiguously.
 * @param buffers The buffers.
 * @return The required size of the contiguous space.
 */
std::vector<uint64_t> GetBufferOffsets(std::vector<arrow::Buffer *> &buffers);

/**
 * @brief Write an arrow::RecordBatch to an SREC file.
 * This file can be used in simulation.
 * @param record_batch The arrow::RecordBatch to convert.
 * @param srec_fname The file name of the SREC file.
 * @return A vector with the buffer offsets in the SREC file.
 */
std::vector<uint64_t> WriteRecordBatchesToSREC(const std::deque<std::shared_ptr<arrow::RecordBatch>>& recordbatches,
                                               const std::string &srec_fname);

} // namespace fletchgen::srec
