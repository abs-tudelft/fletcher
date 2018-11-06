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
#include <utility>

#include "./hex-view.h"

namespace fletcher {

HexView::HexView(uint64_t start, std::string str, uint64_t row, uint64_t col, uint64_t width)
    : str(std::move(str)), row(row), col(col), width(width), start(start) {}

std::string HexView::toString(bool header) {
  char buf[6] = {0};
  std::string ret;
  if (header) {
    ret = "                  ";
    for (unsigned int i = 0; i < width; i++) {
      snprintf(buf, sizeof(buf), "%02X ", i);
      ret.append(buf);
    }
  }
  ret.append(str);
  return ret;
}

unsigned char convertToReadable(unsigned char c) {
  if ((c < 32) || (c > 126)) {
    return '.';
  }
  return c;
}

void HexView::addData(const uint8_t *ptr, size_t size) {
  char buf[64] = {0};
  std::string left;
  std::string right;

  unsigned int i = 0;

  while (i < size) {
    if (col % width == 0) {
      str.append(left);
      str.append(" ");
      str.append(right);
      str.append("\n");
      left = "";
      right = "";
      snprintf(buf, sizeof(buf), "%016lX: ", start + row * width);
      left.append(buf);
      row++;
    }

    snprintf(buf, sizeof(buf), "%02X", (unsigned char) ptr[i]);
    left.append(buf);

    snprintf(buf, sizeof(buf), "%c", convertToReadable((unsigned char) ptr[i]));
    right.append(buf);

    if (i == size - 1) {
      left.append("|");
    } else {
      left.append(" ");
    }
    col++;
    i++;
  }

  left.append(std::string(18 + 3 * width - left.length(), ' '));

  str.append(left);
  str.append(" ");
  str.append(right);
  str.append("\n");
}

}  // namespace fletcher
