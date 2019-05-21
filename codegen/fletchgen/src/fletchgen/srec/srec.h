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

#include <cstdint>
#include <stdexcept>
#include <cstring>
#include <ostream>
#include <vector>
#include <memory>

namespace fletchgen::srec {

/**
 * @brief Structure to build up a single line in an SREC file.
 *
 * Only supports SREC record type S3.
 * By no means should this be expected to be compliant with any standards.
 */
struct Record {
  const static size_t MAX_DATA_BYTES = 64;
  size_t length_;
  uint32_t address_;
  uint8_t *data_ = nullptr;
  uint8_t checksum_ = 0;
  size_t byte_count_ = 0;

  /**
   * Create a new SRecord file
   * @param address Address in the SREC memory space
   * @param data Data to store
   * @param length Length length of the data buffer
   */
  Record(const uint8_t *data, size_t length, uint32_t address);

  ~Record();

  /// @brief Calculate the checksum of this Record
  uint8_t checksum();

  /// @brief Return the SREC record string
  std::string toString();
};

/**
 * @brief Structure to build up an SREC file with multiple Record lines.
 */
struct File {
  std::vector<std::shared_ptr<Record>> lines_;

  /**
   * @brief Construct a new File
   * @param address
   * @param data
   * @param length
   */
  File(const uint8_t *data, size_t length, uint32_t address);

  void write(std::ostream &output);
};

} // namespace fletchgen::srec
