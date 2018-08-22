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

#include <arrow/api.h>

#include "../fletcher.h"
#include "../logging.h"

#include "aws.h"

extern "C" {
#include <fpga_pci.h>
#include <fpga_mgmt.h>
}

namespace fletcher {

AWSPlatform::AWSPlatform(int slot_id, int pf_id, int bar_id)
    : slot_id(slot_id),
      pf_id(pf_id),
      bar_id(bar_id) {
  int rc = 0;

  // Initialize FPGA management library
  rc = fpga_mgmt_init();

  if (rc != 0) {
    LOGE("[AWSPlatform] Cannot initialize FPGA management library. Entering error state.");
    error = true;
    return;
  }

  // TODO: check slot config

  // Open files for all queues
  for (int q = 0; q < AWS_NUM_QUEUES; q++) {
    // Get the EDMA device filename
    sprintf(device_filename, "/dev/edma%i_queue_%i", slot_id, q);

    // Attempt to open the EDMA file
    LOGD("[AWSPlatform] Attempting to open device file " << device_filename);
    edma_fd[q] = open(device_filename, O_RDWR);

    if (edma_fd[q] < 0) {
      LOGE("[AWSPlatform] Did not get a valid file descriptor. FD: " << edma_fd[q]
                                                                     << ". Is the EDMA driver installed? Entering error state.");
      error = true;
      return;
    }
  }
  // Set the PCI bar handle init
  pci_bar_handle = PCI_BAR_HANDLE_INIT;

  // Attach the PCI to the FPGA
  LOGD("[AWSPlatform] Attaching PCI <-> FPGA");
  int ret = fpga_pci_attach(slot_id, pf_id, bar_id, 0, &pci_bar_handle);

  if (ret != 0) {
    LOGE("[AWSPlatform] Could not attach PCI <-> FPGA. Are you running as root? Entering error state. fpga_pci_attach: "
             << ret);
    error = true;
  }
}

AWSPlatform::~AWSPlatform() {
  fpga_pci_detach(this->pci_bar_handle);

  for (int q : edma_fd) {
    close(q);
  }
}

size_t AWSPlatform::copy_to_ddr(void *source, fa_t address, size_t bytes) {
  size_t total = 0;
  if (!error) {

    size_t written[AWS_NUM_QUEUES] = {0};

    int queues = AWS_NUM_QUEUES;

    // Only use more queues if the data to copy is larger than the queue threshold
    if (bytes < AWS_QUEUE_THRESHOLD) {
      queues = 1;
    }

    size_t qbytes = bytes / queues;

    omp_set_num_threads(queues);
    // For each queue
#pragma omp parallel for
    for (int q = 0; q < queues; q++) {
      ssize_t rc = 0;
      // Determine number of bytes for the whole transfer
      size_t qtotal = qbytes;
      auto *qsource = (void *) ((uint64_t) source + q * qbytes);
      fa_t qdest = address + qbytes * q;

      // For the last queue check how many extra bytes we must copy
      if (q == queues - 1) {
        qtotal = qbytes + (bytes % queues);
      }

      LOGD("[AWSPlatform] Copying " << std::dec << (uint64_t) qtotal << " bytes from host: " << STRHEX64
                                    << (uint64_t) qsource << " --> on-board DDR: " << STRHEX64 << qdest
                                    << " over queue " << q);

      while (written[q] < qtotal) {
        if (written[q] != 0) {
          LOGD("[AWSPlatform] Partial copy, attempting to finish copy. " << written[q] << " out of " << qtotal << ", "
                                                                         << qtotal - written[q] << " remaining.");
        }
        // Write some bytes
        rc = pwrite(edma_fd[q],
                    (void *) ((uint64_t) qsource + written[q]),
                    qtotal - written[q],
                    qdest + written[q]);
        // If rc is negative there is something else going wrong. Abort the mission
        if (rc < 0) {
          LOGE("[AWSPlatform] Copy to DDR failed, Queue: " << q << " RC=" << rc);
          throw std::runtime_error("Copy to DDR failed.");
        }
        written[q] += rc;
      }
    }
    for (int q = 0; q < queues; q++) {
      total += written[q];
    }
  }
  return total;
}

uint64_t AWSPlatform::organize_buffers(const std::vector<BufConfig> &source_buffers,
                                       std::vector<BufConfig> &dest_buffers) {
  uint64_t bytes = 0;
  if (!error) {
    LOGD("[AWSPlatform] Organizing buffers.");

    // First buffer goes to address 0 for now
    // TODO: manage memory on on-board DDR
    uint64_t address = 0x0;

    for (unsigned int i = 0; i < source_buffers.size(); i++) {
      BufConfig source_buf = source_buffers[i];

      LOGD("[AWSPlatform] Source buffer: " << source_buf.name << ", " << std::dec << source_buf.size << ", "
                                           << source_buf.capacity << ", " << STRHEX64 << source_buf.address);

      // Align the buffer address to the next aligned address, if it's not
      // aligned already.
      if (address % alignment != 0) {
        address = (address / alignment + 1) * alignment;
      }

      BufConfig dest_buf;
      dest_buf.name = source_buf.name;
      dest_buf.size = source_buf.size;
      dest_buf.capacity = source_buf.capacity;
      dest_buf.address = address;

      LOGD("[AWSPlatform] Destination buffer: " << dest_buf.name << ", " << std::dec << dest_buf.size << ", "
                                                << dest_buf.capacity << ", " << STRHEX64 << dest_buf.address);
      // Copy each of the buffers to the FPGA board memory

      bytes += copy_to_ddr((void *) source_buf.address,
                           (fa_t) dest_buf.address,
                           (size_t) dest_buf.size);

      // Set the buffer address in the MMSRs:
      write_mmio(UC_REG_BUFFERS + i, (fr_t) dest_buf.address);

      dest_buffers.push_back(dest_buf);

      // Calculate the next buffer address
      address += source_buf.capacity;
    }
  }
  // Make sure all bytes are copied.
  for (int q : edma_fd) {
    LOGD("[AWSPlatform] Emptying queue " << q);
    fsync(q);
  }

  return bytes;
}

int AWSPlatform::write_mmio(uint64_t offset, fr_t value) {
  if (!error) {
    int rc = 0;
    reg_conv_t conv_value;
    conv_value.full = value;

    LOGD("[AWSPlatform] AWS fpga_pci_poke " << STRHEX32 << conv_value.half.hi << std::dec << " to reg " << (2 * offset)
                                            << " addr " << STRHEX64 << (4 * (2 * offset)));
    LOGD("[AWSPlatform] AWS fpga_pci_poke " << STRHEX32 << conv_value.half.lo << std::dec << " to reg "
                                            << (2 * offset + 1) << " addr " << STRHEX64 << (4 * (2 * offset + 1)));

    rc |= fpga_pci_poke(pci_bar_handle, 4 * (2 * offset), conv_value.half.hi);

    rc |= fpga_pci_poke(pci_bar_handle, 4 * (2 * offset + 1), conv_value.half.lo);

    // We can't write MMIO
    if (rc != 0) {
      LOGE("[AWSPlatform] MMIO write failed.");
      return FLETCHER_ERROR;
    }
  }
  return FLETCHER_OK;
}

int AWSPlatform::read_mmio(uint64_t offset, fr_t *dest) {
  if (!error) {
    int rc = 0;
    reg_conv_t conv_value;
    uint32_t ret = 0xDEADBEEF;

    rc |= fpga_pci_peek(pci_bar_handle, 4 * (2 * offset), &ret);
    conv_value.half.hi = ret;

    LOGD("[AWSPlatform] AWS fpga_pci_peek " << STRHEX32 << ret << " from reg " << std::dec << (2 * offset) << " addr "
                                            << 4 * (2 * offset));

    rc |= fpga_pci_peek(pci_bar_handle, 4 * (2 * offset + 1), &ret);
    conv_value.half.lo = ret;

    LOGD("[AWSPlatform] AWS fpga_pci_peek " << STRHEX32 << ret << " from reg " << std::dec << (2 * offset + 1)
                                            << " addr " << 4 * (2 * offset + 1));

    if (rc != 0) {
      LOGD("[AWSPlatform] MMIO read failed.");
      return FLETCHER_ERROR;
    }

    *dest = conv_value.full;
    return FLETCHER_OK;
  } else {
    return FLETCHER_ERROR;
  }
}

bool AWSPlatform::good() {
  return !error;
}

}
