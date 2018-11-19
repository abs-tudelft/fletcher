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

#include <arrow/buffer.h>
#include <arrow/array.h>
#include <arrow/builder.h>
#include <arrow/record_batch.h>
#include <arrow/io/api.h>
#include <arrow/ipc/api.h>
#include <fstream>
#include <bits/ios_base.h>
#include <iostream>

#include "../logging.h"
#include "../printers.h"

#include "srec.h"

namespace fletchgen {
namespace srec {

/**
 * @brief Calculate buffer offsets if all buffers would be stored contiguously.
 * @param buffers The buffers.
 * @return The required size of the contiguous space.
 */
std::vector<uint64_t> getBufferOffsets(std::vector<arrow::Buffer *> &buffers);

/**
 * @brief Write an arrow::RecordBatch to an SREC file.
 * This file can be used in simulation.
 * @param record_batch The arrow::RecordBatch to convert.
 * @param srec_fname The file name of the SREC file.
 * @return A vector with the buffer offsets in the SREC file.
 */
std::vector<uint64_t> writeRecordBatchToSREC(arrow::RecordBatch *record_batch, const std::string &srec_fname);

} // namespace srec
} // namespace fletchgen