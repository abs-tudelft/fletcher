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

#define AWS_QUEUE_THRESHOLD (1024*1024*1) // 1 MiB
#define AWS_NUM_QUEUES 4

// Forward declarations:
typedef int pci_bar_handle_t;

namespace fletcher {

/// \class AWSPlatform
/// \brief An implementation of an FPGAPlatform for Amazon EC2 F1 instances.
class AWSPlatform : public FPGAPlatform {
 public:
  ~AWSPlatform() override;

  /**
   * \brief AWSPlatform constructor
   * 
   * \param slotd_id The FPGA slot ID you want to use
   * \param pf_id    The FPGA pf_id you want to use. Default is FPGA_APP_PF=0.
   * \param bar_id   The BAR id you want to use for the memory-mapped slave 
   *                 registers. Default is APP_PF_BAR1.
   */
  explicit AWSPlatform(int slot_id = 0, int pf_id = 0, int bar_id = 1);

  int write_mmio(uint64_t offset, fr_t value) override;

  int read_mmio(uint64_t offset, fr_t *dest) override;

  void set_alignment(uint64_t alignment) {}

  bool good() override;

 private:
  std::string _name = "AWS EC2 F1";
  int slot_id;
  int pf_id;
  int bar_id;
  pci_bar_handle_t pci_bar_handle;
  char device_filename[256];
  int edma_fd[AWS_NUM_QUEUES];
  uint64_t alignment = 4096;  // TODO: this should become 64 after Arrow spec.

  size_t copy_to_ddr(uint8_t *source, fa_t offset, size_t size);

  int check_ddr(uint8_t *source, fa_t offset, size_t size);

  uint64_t organize_buffers(const std::vector<BufConfig> &source_buffers,
                            std::vector<BufConfig> &dest_buffers) override;

  int check_slot_config();

  bool error = false;
};

}
