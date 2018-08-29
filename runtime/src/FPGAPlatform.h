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

#include <vector>
#include <memory>
#include <string>

#include <arrow/api.h>

#include "common.h"

/// The status register and bits
#define UC_REG_STATUS   0
#define   UC_REG_STATUS_IDLE 0
#define   UC_REG_STATUS_BUSY 1
#define   UC_REG_STATUS_DONE 2

/// The control register
#define UC_REG_CONTROL  1
#define   UC_REG_CONTROL_RESET 0
#define   UC_REG_CONTROL_START 1
#define   UC_REG_CONTROL_STOP  2

/// The return register
#define UC_REG_RETURN   2

/// The offset of the buffer addresses
#define UC_REG_BUFFERS  3

namespace fletcher {

/**
 * \class FPGAPlatform
 * \brief Abstract class to represent an FPGA platform.
 * 
 * Users should implement the member functions of this class to allow
 * a UserCore to write/read memory mapped slave registers and to
 * organize buffers. This may or may not include copying the Arrow
 * buffers to some on-board memory.
 */
class FPGAPlatform
{
 public:
  virtual ~FPGAPlatform()=default;

  /**
   * \brief Write a 64-bit value to a memory mapped slave register at 
   * some offset (address).
   */
  virtual int write_mmio(uint64_t offset, fr_t value)=0;

  /**
   * \brief Read a 64-bit value from a memory mapped slave register at
   * some offset (address) and store it in dest
   */
  virtual int read_mmio(uint64_t offset, fr_t* dest)=0;

  /**
   * \brief Prepare the chunks of a column.
   * 
   * This may or may not include a copy to some on-board memory, 
   * depending on the type of platform uses.
   * \return the number of bytes prepared for all buffers in this column
   */
  uint64_t prepare_column_chunks(const std::shared_ptr<arrow::Column>& column);

  /**
   * \brief The offset of the first memory-mapped slave register 
   * argument.
   */
  uint64_t argument_offset();

  /**
   * \brief Return the name of this platform
   */
  std::string name();

  /**
   * \brief Returns true if the platform is OK for use, false otherwise.
   */
  virtual bool good()=0;

 private:
  uint64_t _argument_offset = UC_REG_BUFFERS;

  std::string _name = "Anonymous Platform";

  /**
   * \brief Function to organize buffers for the specific FPGA Platform.
   * 
   * \param source_buffers A vector of buffer configurations of all 
   *        source buffers to be organized for the FPGA platform.
   * \param dest_buffers A vector to append the buffer configurations
   *        on the FPGA platform for.
   * \return the number of bytes organized
   */
  virtual uint64_t organize_buffers(const std::vector<BufConfig>& source_buffers,
                                    std::vector<BufConfig>& dest_buffers)=0;

  /**
   * Append a BufConfig vector with all ArrayData buffers that are used 
   * specified by an arrow::Field
   *
   * This is useful to obtain a flat list of the buffers that are of 
   * interest.
   *
   * \param array_data    the ArrayData to get the Buffer configuration 
   *                      from
   * \param field         the arrow::Field corresponding to this 
   *                      ArrayData
   * \param config_vector the configuration vector to append
   */
  void append_chunk_buffer_config(const std::shared_ptr<arrow::ArrayData>& array_data,
                                  const std::shared_ptr<arrow::Field>& field,
                                  std::vector<BufConfig>& config_vector,
                                  uint depth = 1);
};

std::string ToString(std::shared_ptr<arrow::Buffer> buf, int width = 64);
std::string ToString(std::vector<BufConfig> &bc);

}
