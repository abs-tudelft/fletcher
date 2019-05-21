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

namespace fletcher {

/**
 * Structure for hex editor style command-line output
 */
struct HexView {
  /**
   * @brief Construct a new HexView object
   * @param start Start address of the first byte.
   * @param str Optional string to append any output to.
   * @param row Starting row
   * @param col Starting column
   * @param width Number of bytes per line
   */
  explicit HexView(uint64_t start,
                   std::string str = "",
                   uint64_t row = 0,
                   uint64_t col = 0,
                   uint64_t width = 32);

  /// @brief Return a hex editor style view of the memory that was added to this HexView, optionally with a \p header.
  std::string toString(bool header = true);

  /**
   * @brief Add a memory region to be printed to the HexView
   * @param ptr The memory
   * @param size The size
   */
  void addData(const uint8_t *ptr, size_t size);

  std::string str;
  uint64_t row;
  uint64_t col;
  uint64_t width;
  uint64_t start;
};

}  // namespace fletcher
