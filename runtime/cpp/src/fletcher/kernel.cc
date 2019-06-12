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

bool Kernel::ImplementsSchema(const std::shared_ptr<arrow::Schema> &schema) {
  // TODO(johanpel): Implement checking if the kernel implements the same Schema,
  //  probably through some checksum register
  FLETCHER_LOG(INFO, schema->ToString());
  return true;
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
  if (!context_->platform()->WriteMMIO(FLETCHER_REG_SCHEMA + 2 * recordbatch_index, static_cast<uint32_t>(first)).ok()) {
    ret = Status::ERROR();
  }
  if (!context_->platform()->WriteMMIO(FLETCHER_REG_SCHEMA + 2 * recordbatch_index + 1, static_cast<uint32_t>(last)).ok()) {
    ret = Status::ERROR();
  }
  return Status::OK();
}

Status Kernel::SetArguments(std::vector<uint32_t> arguments) {
  for (int i = 0; (size_t) i < arguments.size(); i++) {
    context_->platform()->WriteMMIO(FLETCHER_REG_SCHEMA + context_->num_buffers() * 2 + i, arguments[i]);
  }

  return Status::OK();
}

Status Kernel::Start() {
  return context_->platform()->WriteMMIO(FLETCHER_REG_CONTROL, ctrl_start);
}

Status Kernel::GetStatus(uint32_t *status) {
  return context_->platform()->ReadMMIO(FLETCHER_REG_STATUS, status);
}

Status Kernel::GetReturn(uint32_t *ret0, uint32_t *ret1) {
  if (context_->platform()->ReadMMIO(FLETCHER_REG_RETURN0, ret0).ok()) {
    if (context_->platform()->ReadMMIO(FLETCHER_REG_RETURN1, ret1).ok()) {
      return Status::OK();
    }
  }
  return Status::ERROR();
}

Status Kernel::WaitForFinish() {
  return WaitForFinish(0);
}

Status Kernel::WaitForFinish(unsigned int poll_interval_usec) {
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
  return Status::OK();
}

std::shared_ptr<Context> Kernel::context() {
  return context_;
}

}
