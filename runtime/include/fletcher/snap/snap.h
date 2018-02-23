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
#include <vector>

#include <arrow/api.h>

#include "../common.h"
#include "../FPGAPlatform.h"
#include "../UserCore.h"

#define SNAP_ACTION_REG_OFFSET 64 // starts at 0x200

struct snap_card;
struct snap_action;
struct snap_queue;

namespace fletcher {

/// \class SNAPPlatform
/// \brief An implementation of an FPGAPlatform for SNAP
class SNAPPlatform : public FPGAPlatform
{
 public:
  ~SNAPPlatform();
  /**
   * \brief SNAPPlatform constructor
   *
   */
  SNAPPlatform(int card_no=0, uint32_t action_type=0x00000001, bool sim = false);

  int write_mmio(uint64_t offset, fr_t value);
  int read_mmio(uint64_t offset, fr_t* dest);

  void set_alignment(uint64_t alignment);

  bool good();

 private:
  std::string _name = "CAPI SNAP";
  uint64_t alignment = 4096;  // TODO: this should become 64 after Arrow spec.
  uint64_t organize_buffers(const std::vector<BufConfig> &source_buffers,
                            std::vector<BufConfig> &dest_buffers);

  bool error = false;

  // Snap device path
  char device[64];

  // Snap card handle
  struct snap_card *card_handle;

  // Snap action handle
  struct snap_action *action_handle = NULL;

};

}
