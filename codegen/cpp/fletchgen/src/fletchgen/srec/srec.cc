// Copyright 2018-2019 Delft University of Technology
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

#include "fletchgen/srec/srec.h"
#include <fletcher/common.h>
#include <cstdlib>
#include <sstream>
#include <string>
#include <algorithm>

namespace fletchgen::srec {

Record::Record(Type type, uint32_t address, const uint8_t *data, size_t size)
    : type_(type), size_(size), address_(address) {
  // Throw if size is too large.
  if (size > MAX_DATA_BYTES) {
    throw std::domain_error("SREC Record size cannot exceed " + std::to_string(MAX_DATA_BYTES) + " bytes.");
  }
  if (size_ > 0) {
    // Allocate buffer for data
    data_ = static_cast<uint8_t *>(calloc(1, size_));
    // Copy data over
    memcpy(data_, data, size);
  }
}

Record::~Record() {
  if (size_ > 0) {
    free(data_);
  }
}

Record Record::Header(const std::string &header_str, uint16_t address) {
  auto str = header_str.substr(0, std::max(MAX_DATA_BYTES, header_str.size()));
  return Record(Record::HEADER, address, (const uint8_t *) (str.c_str()), str.size());
}

uint8_t Record::byte_count() {
  return address_width() + size_ + 1;
}

int Record::address_width() {
  switch (type_) {
    case DATA24: return 3;
    case COUNT24: return 3;
    case TERM24: return 3;
    case DATA32: return 4;
    case TERM32: return 4;
    default:return 2;
  }
}

uint8_t Record::checksum() {
  uint32_t sum = 0;
  // Byte count
  sum += byte_count();
  // Address
  if (address_width() > 3) sum += (address_ & 0xFF000000u) >> 24u;
  if (address_width() > 2) sum += (address_ & 0x00FF0000u) >> 16u;
  sum += (address_ & 0x0000FF00u) >> 8u;
  sum += (address_ & 0x000000FFu);
  // Data
  for (size_t i = 0; i < size_; i++)
    sum += data_[i];
  // Keep the least significant byte
  auto ret = static_cast<uint8_t>(sum & 0xFFu);
  // Get one's complement
  ret = ~ret;
  // Return 1's complement
  return ret;
}

std::string Record::ToString(bool line_feed) {
  // String stream to build output
  std::stringstream output;
  // Record type
  output << 'S' << std::to_string(type_);
  // Byte count
  PutHex(output, byte_count());
  // Address
  PutHex(output, address_, 2 * address_width());
  // Data
  for (size_t i = 0; i < size_; i++) {
    PutHex(output, data_[i]);
  }
  // Checksum
  PutHex(output, checksum());
  // Line feed
  if (line_feed) {
    output << std::endl;
  }
  return output.str();
}

std::optional<Record> Record::FromString(const std::string &line) {
  // TODO(johanpel): make this function not break on big endian systems
  size_t offset = 0;
  Record ret(RESERVED, 0, nullptr, 0);

  // Check if line starts with S (1 character)
  if (line.substr(offset, 1) != "S") {
    return std::nullopt;
  }
  offset++;

  // Get type (1 character)
  uint64_t t = std::stoul(line.substr(offset, 1), nullptr, 16);
  if (t > 9) {
    return std::nullopt;
  }
  ret.type_ = static_cast<Type>(t);
  offset++;

  // Get size (2 characters, 1 byte), subtract address width and checksum
  ret.size_ = std::stoul(line.substr(offset, 2), nullptr, 16) - ret.address_width() - 1;
  if (ret.size_ > MAX_DATA_BYTES) {
    return std::nullopt;
  }
  offset += 2;

  // Obtain the address (addr. width * (2 chars or 1 byte))
  uint32_t addr = 0;
  for (int i = ret.address_width() - 1; i >= 0; i--) {
    uint8_t byte = static_cast<uint8_t>(std::stoul(line.substr(offset, 2), nullptr, 16));
    addr |= static_cast<uint32_t>(byte) << (8u * i);
    offset += 2;
  }
  ret.address_ = addr;

  // Reserve a data buffer
  ret.data_ = static_cast<uint8_t *>(calloc(ret.size_, sizeof(uint8_t)));

  // Obtain the data (2 chars or 1 byte)
  for (size_t i = 0; i < ret.size_; i++) {
    auto byte = static_cast<uint8_t>(std::stoul(line.substr(offset, 2), nullptr, 16));
    ret.data_[i] = byte;
    offset += 2;
  }

  // Validate checksum
  uint8_t sum = static_cast<uint8_t>(std::stoul(line.substr(offset, 2), nullptr, 16));
  if (ret.checksum() != sum) {
    return std::nullopt;
  }

  return ret;
}

File::File(uint32_t start_address, const uint8_t *data, size_t size, const std::string &header_str) {
  // Create a header
  auto header = Record::Header(header_str);
  records.push_back(header);
  // Chop the data up into MAX_DATA_BYTES Records
  size_t pos = 0;
  while (pos < size) {
    // Determine record size
    size_t rec_size;
    if ((size - pos) / Record::MAX_DATA_BYTES > 0) {
      rec_size = Record::MAX_DATA_BYTES;
    } else {
      rec_size = (size - pos) % Record::MAX_DATA_BYTES;
    }
    // Create the record
    auto rec = Record::Data<32>(static_cast<uint32_t>(start_address + pos), &data[pos], rec_size);
    // Add to the file
    records.push_back(rec);
    pos = pos + rec_size;
  }
}

void File::write(std::ostream *output) {
  if (output->good()) {
    for (auto &r : records) {
      (*output) << r.ToString(true);
    }
  } else {
    FLETCHER_LOG(ERROR, "Could not write SREC file to output stream.");
  }
}

File::File(std::istream *input) {
  for (std::string line; std::getline(*input, line);) {
    auto record = Record::FromString(line);
    if (record) {
      records.push_back(*record);
    } else {
      throw std::runtime_error("Could not parse SREC file.");
    }
  }
}

void File::ToBuffer(uint8_t **buf, size_t *size) {
  // Find the highest address and total size
  uint32_t top_addr = 0;
  const Record *top_rec = nullptr;
  for (const auto &r : records) {
    if (r.address() > top_addr) {
      top_addr = r.address();
      top_rec = &r;
    }
  }
  // Allocate buffer
  if (top_rec != nullptr) {
    *size = top_addr + top_rec->size();
    *buf = static_cast<uint8_t *>(calloc(*size, sizeof(uint8_t)));
  } else {
    // If there werent any records, just return a nullptr and size 0
    *buf = nullptr;
    *size = 0;
    return;
  }
  // For each record, copy bytes into the buffer
  for (const auto &r : records) {
    std::memcpy(*buf + r.address(), r.data(), r.size());
  }
}

}  // namespace fletchgen::srec
