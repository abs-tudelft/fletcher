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

#include <unistd.h>
#include <utility>

#include <arrow/util/logging.h>

#include "./context.h"
#include "./usercore.h"

namespace fletcher {

UserCore::UserCore(std::shared_ptr<Context> context) : _context(std::move(context)) {}

bool UserCore::implementsSchema(const std::shared_ptr<arrow::Schema> &schema) {
  // TODO(johanpel): Implement checking if the platform implements the same Schema
  ARROW_LOG(INFO) << schema->ToString();
  return true;
}

Status UserCore::reset() {
  platform()->writeMMIO(FLETCHER_REG_CONTROL, ctrl_reset);
  return platform()->writeMMIO(FLETCHER_REG_CONTROL, 0);
}

Status UserCore::setRange(int32_t first, int32_t last) {
  if (first >= last) {
    ARROW_LOG(ERROR) << "Row range invalid: [ " + std::to_string(first) + ", " + std::to_string(last) + " )";
    return Status::ERROR();
  }

  Status ret;
  if (!platform()->writeMMIO(FLETCHER_REG_FIRSTIDX, static_cast<uint32_t>(first)).ok()) {
    ret = Status::ERROR();
  }
  if (!platform()->writeMMIO(FLETCHER_REG_LASTIDX, static_cast<uint32_t>(last)).ok()) {
    ret = Status::ERROR();
  }
  return Status::OK();
}

Status UserCore::setArguments(std::vector<uint32_t> arguments) {
  for (int i = 0; (size_t) i < arguments.size(); i++) {
    platform()->writeMMIO(FLETCHER_REG_BUFFER_OFFSET + _context->num_buffers() * 2 + i, arguments[i]);
  }

  return Status::OK();
}

Status UserCore::start() {
  return platform()->writeMMIO(FLETCHER_REG_CONTROL, ctrl_start);
}

Status UserCore::getStatus(uint32_t *status) {
  return platform()->readMMIO(FLETCHER_REG_STATUS, status);
}

Status UserCore::getReturn(uint32_t *ret0, uint32_t *ret1) {
  if (platform()->readMMIO(FLETCHER_REG_RETURN0, ret0).ok()) {
    if (platform()->readMMIO(FLETCHER_REG_RETURN1, ret1).ok()) {
      return Status::OK();
    }
  }
  return Status::ERROR();
}

Status UserCore::waitForFinish() {
  return waitForFinish(0);
}

Status UserCore::waitForFinish(unsigned int poll_interval_usec) {
  uint32_t status = 0;
  if (poll_interval_usec == 0) {
    do {
      platform()->readMMIO(FLETCHER_REG_STATUS, &status);
    } while ((status & done_status_mask) != this->done_status);
  } else {
    do {
      usleep(poll_interval_usec);
      platform()->readMMIO(FLETCHER_REG_STATUS, &status);
    } while ((status & done_status_mask) != this->done_status);
  }
  return Status::OK();
}

std::shared_ptr<Platform> UserCore::platform() {
  return _context->platform;
}

std::shared_ptr<Context> UserCore::context() {
  return _context;
}

}
