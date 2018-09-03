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
#include <assert.h>

#include <arrow/api.h>

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

  LOGD("[AWSPlatform] Slot config: " << check_slot_config());

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

size_t AWSPlatform::copy_to_ddr(uint8_t *source, fa_t address, size_t bytes) {
  size_t total = 0;
  if (!error) {

    size_t written[AWS_NUM_QUEUES] = {0};

    int queues = AWS_NUM_QUEUES;

    // Only use more queues if the data to copy is larger than the queue threshold
    if (bytes < AWS_QUEUE_THRESHOLD) {
      queues = 1;
    }

    size_t qbytes = bytes / queues;

    //omp_set_num_threads(queues);
    // For each queue
//#pragma omp parallel for
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

      // Synchronize the files
      fsync(edma_fd[q]);
    }
  }
  return total;
}

int AWSPlatform::check_ddr(uint8_t *source, fa_t offset, size_t size) {
  ssize_t rc = 0;

  auto *check_buffer = (uint8_t *) malloc(size);

  rc = pread(edma_fd[0], check_buffer, size, offset);

  int ret = memcmp(source, check_buffer, size);

  free(check_buffer);

  return ret;
}

uint64_t AWSPlatform::organize_buffers(const std::vector<BufConfig> &source_buffers,
                                       std::vector<BufConfig> &dest_buffers) {
  uint64_t bytes = 0;
  if (!error) {
    LOGD("[AWSPlatform] Organizing buffers.");

    // First buffer goes to address 0 for now
    // TODO: manage memory on on-board DDR
    fa_t address = 0x0;

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

      LOGD("[AWSPlatform] Copying buffers to DDR...");
      bytes += copy_to_ddr(reinterpret_cast<uint8_t *>(source_buf.address),
                           (fa_t) dest_buf.address,
                           (size_t) dest_buf.size);

      // Check ddr:
#ifdef DEBUG
      LOGD("[AWSPlatform] Checking DDR. Diff = ");
      int diff = check_ddr(reinterpret_cast<uint8_t *>(source_buf.address),
                           (fa_t) dest_buf.address,
                           (size_t) dest_buf.size);
      LOGD(diff << "\n");
#endif

      // Set the buffer address in the MMSRs:
      assert(sizeof(fr_t) == 4);
      assert(sizeof(fa_t) == 8);
      write_mmio(
          UC_REG_BUFFERS + i * 2,
          (fr_t) (dest_buf.address & 0xffffffff));
      write_mmio(
          UC_REG_BUFFERS + i * 2 + 1,
          (fr_t) ((dest_buf.address >> 32) & 0xffffffff));

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

  // Close the files:
  for (int q = 0; q < AWS_NUM_QUEUES; q++) {
    if (edma_fd[q] >= 0) {
      close(edma_fd[q]);
    }
  }

  return bytes;
}

int AWSPlatform::write_mmio(uint64_t offset, fr_t value) {
  if (!error) {
    int rc = 0;

    LOGD("[AWSPlatform] AWS fpga_pci_poke " 
        << STRHEX32 << value << std::dec << " to reg " << (offset)
        << " addr " << STRHEX64 << (sizeof(fr_t) * offset));

    rc = fpga_pci_poke(pci_bar_handle, sizeof(fr_t) * offset, value);

    // We can't write MMIO
    if (rc != 0) {
      LOGE("[AWSPlatform] MMIO write failed.");
      return fletcher::ERROR;
    }
  }
  return fletcher::OK;
}

int AWSPlatform::read_mmio(uint64_t offset, fr_t *dest) {
  if (!error) {
    int rc = 0;

    rc = fpga_pci_peek(pci_bar_handle, sizeof(fr_t) * offset, dest);

    LOGD("[AWSPlatform] AWS fpga_pci_peek "
        << STRHEX32 << *dest << " from reg " << std::dec << offset
        << " addr " << STRHEX64 << (sizeof(fr_t) * offset));

    if (rc != 0) {
      LOGD("[AWSPlatform] MMIO read failed.");
      return fletcher::ERROR;
    }

    return fletcher::OK;
  } else {
    return fletcher::ERROR;
  }
}

bool AWSPlatform::good() {
  return !error;
}

int AWSPlatform::check_slot_config() {
  static uint16_t pci_vendor_id = 0x1D0F; /* Amazon PCI Vendor ID */
  static uint16_t pci_device_id = 0xF001;

  // Parts of this function from AWS sources
  int rc = 0;
  struct fpga_mgmt_image_info info;

  // Check local image
  rc = fpga_mgmt_describe_local_image(slot_id, &info, 0);
  if (rc != 0) {
    LOGE("Unable to get local image information. Are you running as root?");
    return fletcher::ERROR;
  }

  // Check if slot is ready
  if (info.status != FPGA_STATUS_LOADED) {
    rc = 1;
    LOGE("Slot " << slot_id << " is not ready.");
    return fletcher::ERROR;
  }

  // Confirm that AFI is loaded
  if (info.spec.map[FPGA_APP_PF].vendor_id != pci_vendor_id
      || info.spec.map[FPGA_APP_PF].device_id != pci_device_id) {
    rc = 1;
    LOGE(
        "The slot appears loaded, but the pci vendor or device ID doesn't match the expected values. You may need to rescan the fpga with\n"
        "fpga-describe-local-image -S " << slot_id << " -R\n"
                                                      "Note that rescanning can change which device file in /dev/ a FPGA will map to. To remove and re-add your edma driver and reset the device file mappings, run\n"
                                                      "`sudo rmmod edma-drv && sudo insmod <aws-fpga>/sdk/linux_kernel_drivers/edma/edma-drv.ko`\n"
                                                      "The PCI vendor id and device of the loaded image are not the expected values.");
    return fletcher::ERROR;;
  }

  return rc;
}

}
