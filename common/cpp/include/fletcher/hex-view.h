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

#include <string>
#include <cstdint>
#include <vector>

namespace fletcher {

/**
 * Utility for hex editor style command-line output.
 */
struct HexView {
  /**
   * @brief Construct a new HexView object
   * @param start Start address of the first byte.
   * @param width Number of bytes per line
   */
  explicit HexView(uint64_t start = 0, uint64_t width = 32);

  /// @brief Return a hex editor style view of the data that was added to this HexView, with an optional header.
  std::string ToString(bool header = true);

  /**
   * @brief Add data to be printed to the HexView.
   * @param[in]  ptr  The start address of the data.
   * @param[in] size  The size of the data.
   */
  void AddData(const uint8_t *ptr, size_t size);

  int64_t width = 32;
  int64_t start = 0;
  std::vector<uint8_t> data;
};

}  // namespace fletcher
