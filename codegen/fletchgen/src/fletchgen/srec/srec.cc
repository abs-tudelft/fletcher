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

#include <sstream>
#include <string>

#include "./srec.h"

namespace fletchgen {
namespace srec {

Record::Record(const uint8_t *data, size_t length, uint32_t address)
    : length_(length), address_(address) {
  data_ = (uint8_t *) calloc(1, length_);
  memcpy(data_, data, length);
  byte_count_ = 4 + length_ + 1; // 4 for addr, 1 for checksum
  checksum_ = checksum();
}

Record::~Record() {
  free(data_);
}

uint8_t Record::checksum() {
  auto ret = static_cast<uint8_t>(byte_count_);

  // Address
  ret += (uint8_t) ((address_ & 0xFFu << 24u) >> 24u);
  ret += (uint8_t) ((address_ & 0xFFu << 16u) >> 16u);
  ret += (uint8_t) ((address_ & 0xFFu << 8u) >> 8u);
  ret += (uint8_t) (address_ & 0xFFu);

  // Data
  for (unsigned int i = 0; i < length_; i++)
    ret += (uint8_t) data_[i];

  // 1's complement the final result
  ret = ~ret;

  return ret;
}

std::string Record::toString() {
  // Formatting was taken from:
  // https://github.com/vsergeev/libGIS

  // Buffer to throw snprintf output in
  char buf[64] = {0};

  // String stream to build output
  std::stringstream output;

  // Byte count
  snprintf(buf, sizeof(buf), "%s%2.2X", "S3", (unsigned int) byte_count_);
  output << std::string(buf);

  // Address
  snprintf(buf, sizeof(buf), "%2.8X", address_);
  output << std::string(buf);

  // Data
  for (unsigned int i = 0; i < length_; i++) {
    snprintf(buf, sizeof(buf), "%2.2X", data_[i]);
    output << std::string(buf);
  }

  // Checksum
  snprintf(buf, sizeof(buf), "%2.2X\r\n", checksum_);
  output << std::string(buf);

  return output.str();
}

File::File(const uint8_t *data, size_t length, uint32_t address) {
  // Chop the data up into MAX_DATA_BYTES Records
  size_t pos = 0;
  while (pos < length) {
    size_t recsize;
    if ((length - pos) / Record::MAX_DATA_BYTES > 0) {
      recsize = Record::MAX_DATA_BYTES;
    } else {
      recsize = (length - pos) % Record::MAX_DATA_BYTES;
    }
    auto record = std::make_shared<Record>(&data[pos], recsize, static_cast<uint32_t>(address + pos));
    lines_.push_back(record);
    pos = pos + recsize;
  }
}

void File::write(std::ostream &output) {
  for (auto &r : lines_) {
    output << r->toString();
  }
}

}; // namespace srec
}; // namespace fletchgen