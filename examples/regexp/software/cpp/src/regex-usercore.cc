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
#include <vector>
#include <utility>

#include <fletcher/context.h>

#include "./regex-usercore.h"

RegExCore::RegExCore(std::shared_ptr<fletcher::Context> context)
    : UserCore(std::move(context)) {
  // Some settings that are different from standard implementation
  // concerning start, reset and status register.
  // TODO: generate this properly
  if (UserCore::context()->platform->getName() == "aws") {
    active_units = 16;
    ctrl_start = 0x0000FFFF;
    ctrl_reset = 0xFFFF0000;
    done_status = 0xFFFF0000;
    done_status_mask = 0xFFFFFFFF;
  } else if (UserCore::context()->platform->getName() == "snap") {
    active_units = 8;
    ctrl_start = 0x000000FF;
    ctrl_reset = 0x0000FF00;
    done_status = 0x0000FF00;
    done_status_mask = 0x0000FFFF;
  }
}

std::vector<uint32_t> RegExCore::generateUnitArguments(uint32_t first_index,
                                                       uint32_t last_index) {
  std::vector<uint32_t> arguments(2 * active_units, 0);

  if (first_index >= last_index) {
    throw std::runtime_error("First index cannot be larger than or equal to last index.");
  }

  uint32_t match_rows = last_index - first_index;
  for (uint32_t i = 0; i < active_units; i++) {
    // First and last index for unit i
    uint32_t first = first_index + i * match_rows / active_units;
    uint32_t last = first + match_rows / active_units;
    arguments[i] = first;
    arguments[active_units + i] = last;
  }
  return arguments;
}

void RegExCore::setRegExpArguments(uint32_t first_index, uint32_t last_index) {
  std::vector<uint32_t> arguments = generateUnitArguments(first_index, last_index);
  UserCore::setArguments(arguments);
}

void RegExCore::getMatches(std::vector<uint32_t> *matches) {
  for (size_t p = 0; p < matches->size(); p++) {
    platform()->readMMIO(REUC_RESULT_OFFSET + p, matches->data() + p);
  }
}
