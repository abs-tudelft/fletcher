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

#pragma once

#include <cstdint>
#include <stdexcept>
#include <cstring>
#include <ostream>
#include <vector>
#include <memory>
#include <iostream>
#include <optional>
#include <string>
#include <sstream>
#include <iomanip>

namespace fletchgen::srec {

/**
 * @brief Structure to build up a single Record of an SREC file.
 */
class Record {
 public:
  /// Maximum number of data bytes per Record.
  static constexpr size_t MAX_DATA_BYTES = 32;

  /**
   * @brief The SREC Record type.
   */
  enum Type {
    HEADER = 0,
    DATA16 = 1,
    DATA24 = 2,
    DATA32 = 3,
    RESERVED = 4,
    COUNT16 = 5,
    COUNT24 = 6,
    TERM32 = 7,
    TERM24 = 8,
    TERM16 = 9
  };

  /// @brief SREC Record copy constructor
  Record(const Record &rec) : Record(rec.type_, rec.address_, rec.data_, rec.size_) {}

  /**
   * @brief SREC Record constructor. Data is copied into the Record.
   * @param type    The type of the SREC record.
   * @param address The address of the data in the SREC file.
   * @param data    The data.
   * @param size    The size of the data in bytes.
   */
  Record(Type type, uint32_t address, const uint8_t *data, size_t size);

  /// @brief Record destructor.
  ~Record();

  /// @brief Attempt to construct a Record from a string.
  static std::optional<Record> FromString(const std::string &line);

  /**
   * @brief Create an SREC header Record.
   *
   * If header_str is longer than MAX_DATA_BYTES, the remainder of the characters are chopped off.
   *
   * @param header_str  The header ASCII string, typically "HDR"
   * @param address     The header address, typically 0.
   * @return            An SREC Record of type S0 (Header)
   */
  static Record Header(const std::string &header_str = "HDR", uint16_t address = 0);

  /**
   * @brief Create an SREC data Record.
   * @tparam S            The size of the address field.
   * @param srec_address  The address in the SREC file.
   * @param data          The data.
   * @param size          The size of the data.
   * @return              An SREC data record.
   */
  template<uint32_t S>
  static Record Data(uint32_t srec_address, const uint8_t *data, size_t size) {
    switch (S) {
      case 16:return Record(DATA16, srec_address, data, size);
      case 24:return Record(DATA24, srec_address, data, size);
      case 32:return Record(DATA32, srec_address, data, size);
      default:throw std::domain_error("SREC data records can only have 16, 24 or 32-bit address fields.");
    }
  }

  /// @brief Return the SREC Record string
  std::string ToString(bool line_feed = false);

  /// @brief Return the address of this record.
  [[nodiscard]] inline uint32_t address() const { return address_; }
  /// @brief Return the size in bytes of this record.
  [[nodiscard]] inline size_t size() const { return size_; }
  /// @brief Return the data source pointer of this record.
  [[nodiscard]] inline uint8_t *data() const { return data_; }

 private:
  /// Record type.
  Type type_ = RESERVED;
  /// Record size in number of data bytes.
  size_t size_ = 0;
  /// Record address.
  uint32_t address_ = 0;
  /// Record data.
  uint8_t *data_ = nullptr;

  /// @brief Return the number of bytes of the address field.
  int address_width();
  /// @brief Return the byte count of this Record.
  uint8_t byte_count();
  /// @brief Return the checksum of this Record.
  uint8_t checksum();
};

inline void PutHex(std::stringstream &stream, uint32_t val, int characters = 2) {
  stream << std::uppercase << std::hex << std::setfill('0') << std::setw(characters) << val;
}

/**
 * @brief Structure to build up an SREC file with multiple Record lines.
 */
struct File {
  File() = default;

  /**
   * @brief Construct a new File from some data source in memory.
   * @param start_address The start address of the file.
   * @param data          The data source.
   * @param size          The number of bytes of source data.
   * @param header_str    The header string. Default is commonly used "HDR".
   */
  File(uint32_t start_address, const uint8_t *data, size_t size, const std::string &header_str = "HDR");

  /**
   * @brief Construct a new File, reading the contents from an input stream.
   * @param input   The input stream.
   */
  explicit File(std::istream *input);

  /**
   * @brief Write the SREC file to an output stream.
   * @param output  The output stream to write to.
   */
  void write(std::ostream *output);

  /**
   * @brief Convert an SREC file to a raw buffer.
   *
   * Allocates memory that must be freed.
   *
   * @param buffer  A pointer to a pointer that will be set to newly allocated buffer.
   * @param size    The size of the buffer.
   */
  void ToBuffer(uint8_t **buffer, size_t *size);

  /// SREC records in this file.
  std::vector<Record> records;
};

}  // namespace fletchgen::srec
