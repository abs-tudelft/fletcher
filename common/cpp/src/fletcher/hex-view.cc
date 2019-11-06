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

#include <string>
#include <sstream>
#include <iomanip>
#include <utility>

#include "fletcher/hex-view.h"

#define HEX2 std::hex << std::setfill('0') << std::setw(2) << std::uppercase
#define HEX16 std::hex << std::setfill('0') << std::setw(16) << std::uppercase

namespace fletcher {

/// @brief Convert to readable ASCII
inline static unsigned char ConvertToReadable(unsigned char c) {
  if ((c < 32) || (c > 126)) {
    return '.';
  }
  return c;
}

HexView::HexView(uint64_t start, uint64_t width) : width(width), start(start) {}

std::string HexView::ToString(bool header) {
  std::stringstream ss;
  std::string ret;

  // Create a header
  if (header) {
    ss << std::string(17, ' ');
    for (int64_t i = 0; i < width; i++) {
      ss << HEX2 << i;
      if (i != width - 1) {
        ss << " ";
      }
    }
  }

  // Calculate aligned range
  int64_t size = data.size();
  int64_t aligned_start = start - (start % width);
  int64_t aligned_end = aligned_start + size + ((aligned_start + size) % width);
  int64_t aligned_size = aligned_end - aligned_start;

  // Iterate over rows
  for (int64_t row_offset = 0; row_offset < aligned_size; row_offset += width) {
    if ((row_offset != 0) || header) {
      ss << "\n";
    }
    // Put row address
    ss << HEX16 << aligned_start + row_offset << " ";

    // Put bytes as hex
    for (int64_t col_offset = 0; col_offset < width; col_offset++) {
      int64_t pos = row_offset + col_offset - (start - aligned_start);   // Position in the data buffer
      if ((pos < 0) || (pos >= size)) {
        ss << "   ";
      } else {
        ss << HEX2 << static_cast<uint32_t>(data[pos]) << " ";
      }
    }

    // Put bytes as ascii
    for (int64_t col_offset = 0; col_offset < width; col_offset++) {
      int64_t pos = row_offset + col_offset - (start - aligned_start);
      if ((pos < 0) || (pos >= size)) {
        ss << " ";
      } else {
        ss << ConvertToReadable(data[pos]);
      }
    }
  }

  return ss.str();
}

void HexView::AddData(const uint8_t *ptr, size_t size) {
  data.insert(data.end(), ptr, ptr + size);
}

}  // namespace fletcher
