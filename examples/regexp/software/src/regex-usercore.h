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

#include <memory>

#include <fletcher/platform.h>
#include <fletcher/usercore.h>

#define REUC_RESULT_OFFSET 42

/**
 * A class to provide interaction with the regular expression matching UserCore example.
 */
class RegExCore : public fletcher::UserCore {
 public:
  explicit RegExCore(std::shared_ptr<fletcher::Context> context);
  /**
   * @brief Get the number of matches from the RegEx units.
   */
  void getMatches(std::vector<uint32_t>* matches);
  void setRegExpArguments(uint32_t first_index, uint32_t last_index);


 private:
  /// @brief Generate arguments for each of the RegEx units.
  std::vector<uint32_t> generateUnitArguments(uint32_t last_index, uint32_t first_index);
  uint32_t active_units = 16;

};
