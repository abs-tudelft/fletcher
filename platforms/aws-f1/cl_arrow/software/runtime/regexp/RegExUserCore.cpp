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

#include <stdexcept>	

#include "RegExUserCore.h"

using namespace fletcher;

RegExUserCore::RegExUserCore(std::shared_ptr<fletcher::FPGAPlatform> platform)
    : UserCore(platform)
{
  // Some settings that are different from standard implementation
  // concerning start, reset and status register.
  ctrl_start = 0x000000000000FFFF;
  ctrl_reset = 0x00000000FFFF0000;
  done_status = 0x00000000FFFF0000;
  done_status_mask = 0x00000000FFFF0000;
}

std::vector<fr_t> RegExUserCore::generate_unit_arguments(uint32_t first_index,
                                                         uint32_t last_index)
{
  /*
   * Generate arguments for the regular expression matching units.
   * Because the arguments for each REM unit are two 32-bit integers,
   * but the register model for UserCores is 64-bit, we need to
   * determine each 64-bit register value.
   */

  if (first_index >= last_index) {
    throw std::runtime_error("First index cannot be larger than "
                             "or equal to last index.");
  }

  // Obtain first and last indices
  std::vector<uint32_t> first_vec;
  std::vector<uint32_t> last_vec;
  uint32_t match_rows = last_index - first_index;
  for (int i = 0; i < REUC_ACTIVE_UNITS; i++) {
    // First and last index for unit i
    uint32_t first = first_index + i * match_rows / REUC_ACTIVE_UNITS;
    uint32_t last = first + match_rows / REUC_ACTIVE_UNITS;
    first_vec.push_back(first);
    last_vec.push_back(last);
  }
  // Generate one argument vector
  // Every unit needs two 32 bit argument, which is one 64-bit argument
  std::vector<fr_t> arguments(REUC_TOTAL_UNITS);
  // Every unit needs one 64-bit argument, but we set two arguments per 
  // iteration
  for (int i = 0; i < REUC_TOTAL_UNITS / 2; i++) {
    reg_conv_t conv;
    // First indices
    conv.half.hi = first_vec[2 * i];
    conv.half.lo = first_vec[2 * i + 1];
    arguments[i] = conv.full;
    // Last indices
    conv.half.hi = last_vec[2 * i];
    conv.half.lo = last_vec[2 * i + 1];
    arguments[REUC_TOTAL_UNITS / 2 + i] = conv.full;
  }
  return arguments;
}

void RegExUserCore::set_arguments(uint32_t first_index, uint32_t last_index)
{
  std::vector<fr_t> arguments = this->generate_unit_arguments(first_index, last_index);
  UserCore::set_arguments(arguments);
}

void RegExUserCore::get_matches(std::vector<uint32_t>& matches)
{
  int np = matches.size();

  for (int p = 0; p < np / 2; p++) {
    reg_conv_t conv;
    conv.full = this->platform()->read_mmsr(REUC_RESULT_OFFSET + p);
    matches[2 * p] += conv.half.hi;
    matches[2 * p + 1] += conv.half.lo;
  }
}
