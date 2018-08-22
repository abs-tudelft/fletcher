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

#include <fcntl.h>
#include <unistd.h>
#include <omp.h>
#include <fstream>

#include <arrow/api.h>

#include "fletcher/fletcher.h"
#include "fletcher/logging.h"
#include "fletcher/snap/snap.h"

extern "C" {
#include "libsnap.h"
}

namespace fletcher {

SNAPPlatform::SNAPPlatform(int card_no, uint32_t action_type, bool sim)
{
  LOGD("Setting up SNAP platform.");

  // Check psl_server.dat is present

  if (sim) {
    std::ifstream f("pslse_server.dat");
    if (!f.good()) {
      LOGE("No pslse_server.dat file present in working directory. Entering error state.");
      error = true;
      return;
    }
  }

  sprintf(device, "/dev/cxl/afu%d.0s", card_no);
  card_handle = snap_card_alloc_dev(device, SNAP_VENDOR_ID_IBM, SNAP_DEVICE_ID_SNAP);

  if (card_handle == NULL) {
    LOGE("Could not allocate SNAP card. Entering error state.");
    error = true;
    return;
  }

  unsigned long ioctl_data;

  snap_card_ioctl(card_handle, GET_CARD_TYPE, (unsigned long) &ioctl_data);

  switch (ioctl_data) {
    case 0:
      LOGD("ADKU3");
      break;
    case 1:
      LOGD("N250S");
      break;
    case 16:
      LOGD("N250SP");
      break;
    default:
      LOGD("Unknown");
      break;
  }

  snap_card_ioctl(card_handle, GET_SDRAM_SIZE, (unsigned long) &ioctl_data);
  LOGD("Available card RAM: " << (int)ioctl_data);

  snap_action_flag_t attach_flags = (snap_action_flag_t) 0;

  action_handle = snap_attach_action(card_handle, action_type, attach_flags, 100);
}

SNAPPlatform::~SNAPPlatform()
{
  snap_detach_action(action_handle);
  snap_card_free(card_handle);
}

uint64_t SNAPPlatform::organize_buffers(const std::vector<BufConfig> &source_buffers,
                                        std::vector<BufConfig> &dest_buffers)
{
  uint64_t bytes = 0;

  int buf = 0;

  // Simply copy the source to the destination BufConfigs
  // as in SNAP the FPGA can access the host memory
  // using an address translation service.
  for (auto const &src : source_buffers) {
    bytes += src.size;
    dest_buffers.push_back(src);

    // Write the buffer config to the user core
    write_mmio(UC_REG_BUFFERS + buf, src.address);
    buf++;
  }

  return bytes;
}

inline int SNAPPlatform::write_mmio(uint64_t offset, fr_t value)
{
  if (!error) {
    reg_conv_t conv_value;
    conv_value.full = value;

    LOGD("Writing to MMIO reg HI " << std::dec << offset << " @ " << 4 * (2 * (SNAP_ACTION_REG_OFFSET + offset)) << " value: " << STRHEX32 << conv_value.half.hi);
    snap_mmio_write32(card_handle, 4 * (2 * (SNAP_ACTION_REG_OFFSET + offset)), conv_value.half.hi);

    LOGD("Writing to MMIO reg LO " << std::dec << offset << " @ " << 4 * (2 * (SNAP_ACTION_REG_OFFSET + offset) + 1) << " value: " << STRHEX32 << conv_value.half.lo);
    snap_mmio_write32(card_handle, 4 * (2 * (SNAP_ACTION_REG_OFFSET + offset) + 1), conv_value.half.lo);
    
    return FLETCHER_OK;
  } else {
    LOGE("Write unsuccessful. SNAP platform is in error state. Write " << STRHEX64 << value << " to " << STRHEX64 << offset);
    return FLETCHER_ERROR;
  }
}

inline int SNAPPlatform::read_mmio(uint64_t offset, fr_t* dest)
{
  reg_conv_t conv_value;
  uint32_t ret = 0xDEADBEEF;
    
  if (!error) {
    snap_mmio_read32(card_handle, 4 * (2 * (SNAP_ACTION_REG_OFFSET + offset)), &ret);
    conv_value.half.hi = ret;

    LOGD("Read from MMIO reg HI " << std::dec << offset << " @ " << 4 * (2 * (SNAP_ACTION_REG_OFFSET + offset)) << " value " << STRHEX32 << ret);
    
    snap_mmio_read32(card_handle, 4 * (2 * (SNAP_ACTION_REG_OFFSET + offset) + 1), &ret);
    conv_value.half.lo = ret;

    LOGD("Read from MMIO reg LO " << std::dec << offset << " @ " << 4 * (2 * (SNAP_ACTION_REG_OFFSET + offset) + 1) << " value " << STRHEX32 << ret);
  } else {
    LOGE("Read unsuccessful. SNAP platform is in error state. Read from " << STRHEX64 << offset);
    return FLETCHER_ERROR;
  }
  *dest = conv_value.full;
  return FLETCHER_OK;
}

bool SNAPPlatform::good()
{
  return !error;
}

}

