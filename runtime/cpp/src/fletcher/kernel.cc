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

#include "fletcher/kernel.h"

#include <unistd.h>
#include <utility>

#include "fletcher/context.h"

namespace fletcher {

Kernel::Kernel(std::shared_ptr<Context> context) : context_(std::move(context)) {}

bool Kernel::ImplementsSchemaSet(const std::vector<std::shared_ptr<arrow::Schema>> &schema_set) {
  // TODO(johanpel): Implement checking if the kernel implements the same Schema, probably through some checksum
  //  register. We need a hash function for Arrow Schema's for this, that doesn't take into account field names or
  //  metadata, except the fletcher access mode.
  FLETCHER_LOG(WARNING, "ImplementsSchemaSet is not implemented.");
  return false;
}

Status Kernel::Reset() {
  auto status = context_->platform()->WriteMMIO(FLETCHER_REG_CONTROL, ctrl_reset);
  if (status.ok()) {
    return context_->platform()->WriteMMIO(FLETCHER_REG_CONTROL, 0);
  } else {
    return status;
  }
}

Status Kernel::SetRange(size_t recordbatch_index, int32_t first, int32_t last) {
  if (first >= last) {
    FLETCHER_LOG(ERROR, "Row range invalid: [ " + std::to_string(first) + ", " + std::to_string(last) + " )");
    return Status::ERROR();
  }

  Status ret;
  if (!context_->platform()->WriteMMIO(FLETCHER_REG_SCHEMA + 2 * recordbatch_index,
                                       static_cast<uint32_t>(first)).ok()) {
    ret = Status::ERROR();
  }
  if (!context_->platform()->WriteMMIO(FLETCHER_REG_SCHEMA + 2 * recordbatch_index + 1,
                                       static_cast<uint32_t>(last)).ok()) {
    ret = Status::ERROR();
  }
  return Status::OK();
}

Status Kernel::SetArguments(const std::vector<uint32_t>& arguments) {
  for (int i = 0; (size_t) i < arguments.size(); i++) {
    context_->platform()->WriteMMIO(
        FLETCHER_REG_SCHEMA + 2 * context_->num_recordbatches() + 2 * context_->num_buffers() + i, arguments[i]);
  }

  return Status::OK();
}

Status Kernel::Start() {
  Status status;
  if (!metadata_written) {
    WriteMetaData();
  }
  FLETCHER_LOG(DEBUG, "Starting kernel.");
  status = context_->platform()->WriteMMIO(FLETCHER_REG_CONTROL, ctrl_start);
  if (!status.ok())
    return status;
  return context_->platform()->WriteMMIO(FLETCHER_REG_CONTROL, 0);
}

Status Kernel::GetStatus(uint32_t *status_out) {
  return context_->platform()->ReadMMIO(FLETCHER_REG_STATUS, status_out);
}

Status Kernel::GetReturn(uint32_t *ret0, uint32_t *ret1) {
  Status status;
  status = context_->platform()->ReadMMIO(FLETCHER_REG_RETURN0, ret0);
  if ((ret1 == nullptr) || (!status.ok())) {
    return status;
  }
  status = context_->platform()->ReadMMIO(FLETCHER_REG_RETURN1, ret1);
  return status;
}

Status Kernel::WaitForFinish() {
  return WaitForFinish(0);
}

Status Kernel::WaitForFinish(unsigned int poll_interval_usec) {
  FLETCHER_LOG(DEBUG, "Polling kernel for completion.");
  uint32_t status = 0;
  if (poll_interval_usec == 0) {
    do {
      context_->platform()->ReadMMIO(FLETCHER_REG_STATUS, &status);
    } while ((status & done_status_mask) != this->done_status);
  } else {
    do {
      usleep(poll_interval_usec);
      context_->platform()->ReadMMIO(FLETCHER_REG_STATUS, &status);
    } while ((status & done_status_mask) != this->done_status);
  }
  FLETCHER_LOG(DEBUG, "Kernel status done bit asserted.");
  return Status::OK();
}

std::shared_ptr<Context> Kernel::context() {
  return context_;
}

Status Kernel::WriteMetaData() {
  Status status;
  FLETCHER_LOG(DEBUG, "Writing context metadata to kernel.");

  // Set the starting offset to the first schema-derived register index.
  uint64_t offset = FLETCHER_REG_SCHEMA;

  // Get the platform pointer.
  auto platform = context_->platform();

  // Write RecordBatch ranges.
  for (size_t i = 0; i < context_->num_recordbatches(); i++) {
    auto rb = context_->recordbatch(i);
    status = platform->WriteMMIO(offset, 0);               // First index
    if (!status.ok()) return status;
    offset++;
    status = platform->WriteMMIO(offset, rb->num_rows());  // Last index (exclusive)
    if (!status.ok()) return status;
    offset++;
  }

  // Write buffer addresses
  for (size_t i = 0; i < context_->num_buffers(); i++) {
    // Get the device address
    auto device_buf = context_->device_buffer(i);
    dau_t address;
    address.full = device_buf.device_address;
    // Write the address
    platform->WriteMMIO(offset, address.lo);
    if (!status.ok()) return status;
    offset++;
    platform->WriteMMIO(offset, address.hi);
    if (!status.ok()) return status;
    offset++;
  }
  metadata_written = true;
  return Status::OK();
}

}
