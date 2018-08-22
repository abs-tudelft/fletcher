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
#include <iomanip>

#include "FPGAPlatform.h"
#include "logging.h"

namespace fletcher {

uint64_t FPGAPlatform::prepare_column_chunks(const std::shared_ptr<arrow::Column>& column)
{
  uint64_t bytes = 0;

  std::vector<BufConfig> host_bufs;
  std::vector<BufConfig> dest_bufs;

  // Derive some properties of the column:
  //int num_chunks = column->data()->num_chunks();
  auto field = column->field();
  auto chunks = column->data()->chunks();

  // TODO: Support chunks
  // For now, only chunk 0 is selected
  //for (auto const &chunk : chunks) {
  auto chunk = chunks[0];
  std::vector<BufConfig> chunk_config;
  append_chunk_buffer_config(chunk->data(), column->field(), chunk_config);
  host_bufs.insert(host_bufs.end(), chunk_config.begin(), chunk_config.end());
  //}

  LOGD("Host side buffers:" << std::endl << ToString(host_bufs));

  bytes += this->organize_buffers(host_bufs, dest_bufs);

  LOGD("Destination buffers: " << std::endl << ToString(dest_bufs));

  size_t nbufs = host_bufs.size();

  this->_argument_offset += nbufs;

  LOGD("Configured " << nbufs << " buffers. " "Argument offset starting at " << this->argument_offset());

  return bytes;
}

uint64_t FPGAPlatform::argument_offset()
{
  if (this->_argument_offset == UC_REG_BUFFERS) {
    throw std::runtime_error("Argument offset is still at buffer offset."
                             "Prepare at least one buffer before requesting "
                             "argument offset.");
  }
  return this->_argument_offset;
}

std::string FPGAPlatform::name()
{
  return this->_name;
}

/*
 * The default implementation of Arrow always allocates a validity bitmap, even 
 * when a field is specified for which nullable=false. Thus, we need the field 
 * specification of which we expect corresponds to this ArrayData.
 *
 * The first buffer in the buffer list of an ArrayData is therefore always a 
 * validity bitmap buffer. Only in the case of binary and (utf8) string data, 
 * the ArrayData holds three buffers. There, the list elements themselves are 
 * always valid and in fact no validity bitmap is allocated at all.
 *
 * TODO: This quirky implementation should be improved.
 */
void FPGAPlatform::append_chunk_buffer_config(const std::shared_ptr<arrow::ArrayData>& array_data,
                                              const std::shared_ptr<arrow::Field>& field,
                                              std::vector<BufConfig>& config_vector,
                                              uint depth)
{
  LOGD(std::string(depth, '\t') << "Chunk (ArrayData):");
  LOGD(std::string(depth, '\t') << "\tType: " << array_data->type->ToString());
  LOGD(std::string(depth, '\t') << "\tBuffers: " << array_data->buffers.size());

#ifdef PRINT_BUFFERS
  for (int b = 0; b < array_data->buffers.size(); b++) {
    LOGD(std::string(depth, '\t') << "\tAddress " << b << ": " << STRHEX64
        << (uint64_t)array_data->buffers[b]->data());
    LOGD(ToString(array_data->buffers[b]));
  }
#endif

  // Check if this ArrayData has buffers
  if (array_data->buffers.size() > 0) {
    BufConfig vbm, off, dat;
    // Append each buffer to the vector of Buffer Addresses
    switch (array_data->buffers.size()) {
      default:
        throw std::runtime_error("ArrayData contains 0 buffers.");
        break;
      case 1:
        if (field->nullable()) {
          // There is one buffer and the field is nullable, it must be the
          // validity bitmap of a struct
          vbm = {"vbmp " + field->name(), (fa_t)array_data->buffers[0]->data(),
            array_data->buffers[0]->size(), array_data->buffers[0]->capacity()};
          config_vector.push_back(vbm);
        }
        break;
        case 2:
        // There are two buffers, the first one is always the validity bitmap but
        // we only add it to the list if the field is actually nullable
        if (field->nullable()) {
          vbm = {"vbmp " + field->name(), (fa_t)array_data->buffers[0]->data(),
            array_data->buffers[0]->size(), array_data->buffers[0]->capacity()};
          config_vector.push_back(vbm);
        }
        // If there are two buffers, the second one is the data buffer, unless
        // this is a list
        if (field->type()->id() == arrow::Type::LIST) {
          off = {"offs " + field->name(), (fa_t)array_data->buffers[1]->data(),
            array_data->buffers[1]->size(), array_data->buffers[1]->capacity()};
          config_vector.push_back(off);
        }
        else {
          dat = {"data " + field->name(), (fa_t)array_data->buffers[1]->data(),
            array_data->buffers[1]->size(), array_data->buffers[1]->capacity()};
          config_vector.push_back(dat);
        }
        break;
        case 3:
        // If there are three buffers, the first one is the validity bitmap, the
        // second is an offset buffer and the third one is the data buffer. This
        // happens with strings and binary data.
        if (field->nullable()) {
          vbm = {" " + field->name(), (fa_t)array_data->buffers[0]->data(),
            array_data->buffers[0]->size(), array_data->buffers[0]->capacity()};
          config_vector.push_back(vbm);
        }
        off = {"offs " + field->name(), (fa_t)array_data->buffers[1]->data(),
          array_data->buffers[1]->size(), array_data->buffers[1]->capacity()};
        config_vector.push_back(off);
        dat = {"data " + field->name(), (fa_t)array_data->buffers[2]->data(),
          array_data->buffers[2]->size(), array_data->buffers[2]->capacity()};
        config_vector.push_back(dat);
        break;
      }
    }

  LOGD(std::string(depth, '\t') << "\tChildren: " << array_data->child_data.size());

  // Check if chunk has child data (for lists and structs)
  if (array_data->child_data.size() > 0) {
    for (unsigned int c = 0; c < array_data->child_data.size(); c++) {
      auto array_child = array_data->child_data[c];
      auto field_child = field->type()->child(c);
      append_chunk_buffer_config(array_child, field_child, config_vector, depth + 1);
    }
  }
}

std::string ToString(std::vector<BufConfig> &bc)
{
  std::stringstream str;
  str << std::setw(8) << " Idx" << std::setw(17) << " Name" << std::setw(19) << " Address"
      << std::setw(9) << " Size" << std::setw(9) << " Cap" << std::endl;

  for (unsigned int a = 0; a < bc.size(); a++) {
    str << std::setfill(' ') << std::setw(8) << a << " " << std::setfill(' ')
        << std::setw(16) << bc[a].name << " " << STRHEX64 << (uint64_t) bc[a].address
        << " " << std::dec << std::setfill(' ') << std::setw(8) << bc[a].size << " "
        << std::dec << std::setfill(' ') << std::setw(8) << bc[a].capacity << std::endl;
  }
  return str.str();
}

std::string ToString(std::shared_ptr<arrow::Buffer> buf, int width)
{
  std::stringstream str;
  int64_t size = buf->size();
  const uint8_t* data = buf->data();

  str << "Buffer contents:" << std::endl;
  // Print offsets
  for (int j = 0; j < width && j < size; j++) {
    str << std::hex << std::setfill('0') << std::setw(2) << j << " ";
  }
  str << std::endl;

  int i = 0;
  while (i < size) {
    for (int j = 0; j < width && i < size; j++) {
      str << std::hex << std::setfill('0') << std::setw(2) << static_cast<int>(data[i])
          << " ";
      i++;
    }
    if (i != size)
      str << std::endl;
  }
  return str.str();
}

}
