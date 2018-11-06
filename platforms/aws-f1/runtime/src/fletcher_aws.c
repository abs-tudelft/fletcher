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

#include <errno.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include <fpga_pci.h>
#include <fpga_mgmt.h>

#include "../../../../common/cpp/src/fletcher.h"

#include "fletcher_aws.h"

da_t buffer_ptr = 0x0;

// Dirty globals
AwsConfig aws_default_config = {0, 0, 1};
PlatformState aws_state = {{0, 0, 0}, 4096, {0}, {0},  0, 0, {0}, {0}};

static fstatus_t check_ddr(const uint8_t *source, da_t offset, size_t size) {
  uint8_t *check_buffer = (uint8_t *) malloc(size);
  int rc = pread(aws_state.xdma_rd_fd[0], check_buffer, size, offset);
  if (rc < 0) {
    int errsv = errno;
    fprintf(stderr, "[FLETCHER_AWS] pread() error: %s\n", strerror(errsv));
  }
  int ret = memcmp(source, check_buffer, size);
  free(check_buffer);
  return (ret == 0) ? FLETCHER_STATUS_OK : FLETCHER_STATUS_ERROR;
}

static fstatus_t check_slot_config(int slot_id) {
  // Amazon PCI Vendor ID
  static uint16_t pci_vendor_id = 0x1D0F;

  static uint16_t pci_device_id = 0xF001;

  // Parts of this function from AWS sources
  int rc = 0;
  struct fpga_mgmt_image_info info;

  // Check local image
  rc = fpga_mgmt_describe_local_image(slot_id, &info, 0);
  if (rc != 0) {
    fprintf(stderr, "[FLETCHER_AWS] Unable to get local image information. Are you running as root?\n");
    aws_state.error = 1;
    return FLETCHER_STATUS_ERROR;
  }

  // Check if slot is ready
  if (info.status != FPGA_STATUS_LOADED) {
    rc = 1;
    fprintf(stderr, "[FLETCHER_AWS] Slot %d is not ready.\n", slot_id);
    aws_state.error = 1;
    return FLETCHER_STATUS_ERROR;
  }

  // Confirm that AFI is loaded
  if (info.spec.map[FPGA_APP_PF].vendor_id != pci_vendor_id || info.spec.map[FPGA_APP_PF].device_id != pci_device_id) {
    rc = 1;
    fprintf(stderr,
            "[FLETCHER_AWS] Slot appears loaded, but pci vendor or device ID doesn't match the expected value. \n"
            "\tYou may need to rescan the fpga with:\n"
            "\tfpga-describe-local-image -S  %d -R\n"
            "\tNote that rescanning can change which device file in /dev/ a FPGA will map to. "
            "\tTo remove and re-add your xdma driver and reset the device file mappings, run\n"
            "\t`sudo rmmod xdma && sudo insmod <aws-fpga>/sdk/linux_kernel_drivers/xdma/xdma.ko`\n"
            "\tThe PCI vendor id and device of the loaded image are not the expected values.", slot_id);
    return FLETCHER_STATUS_ERROR;
  }

  return FLETCHER_STATUS_OK;
}

fstatus_t platformGetName(char *name, size_t size) {
  size_t len = strlen(FLETCHER_PLATFORM_NAME);
  if (len > size) {
    memcpy(name, FLETCHER_PLATFORM_NAME, size - 1);
    name[size - 1] = '\0';
  } else {
    memcpy(name, FLETCHER_PLATFORM_NAME, len + 1);
  }
  return FLETCHER_STATUS_OK;
}

fstatus_t platformInit(void *arg) {

  AwsConfig *config = NULL;

  if (arg != NULL) {
    config = (AwsConfig *) arg;
  } else {
    config = &aws_default_config;
  }

  aws_state.config = *config;

  debug_print("[FLETCHER_AWS] Initializing platform.       Arguments @ [host] %016lX.\n", (unsigned long) arg);

  int rc = fpga_mgmt_init();

  if (rc != 0) {
    fprintf(stderr, "[FLETCHER_AWS] Cannot initialize FPGA management library.\n");
    aws_state.error = 1;
    return FLETCHER_STATUS_ERROR;
  }

  debug_print("[FLETCHER_AWS] Slot config: %lu\n", check_slot_config(config->slot_id));

  // Open files for all queues
  for (int q = 0; q < FLETCHER_AWS_NUM_QUEUES; q++) {
    // Get the XDMA device filename
    snprintf(aws_state.wr_device_filename, 256, "/dev/xdma%i_h2c_%i", aws_state.config.slot_id, q);
    snprintf(aws_state.rd_device_filename, 256, "/dev/xdma%i_c2h_%i", aws_state.config.slot_id, q);

    // Attempt to open the XDMA file
    debug_print("[FLETCHER_AWS] Attempting to open device files for queue %d; %s and %s.\n", q, aws_state.wr_device_filename, aws_state.rd_device_filename);
    aws_state.xdma_wr_fd[q] = open(aws_state.wr_device_filename, O_WRONLY);
    aws_state.xdma_rd_fd[q] = open(aws_state.rd_device_filename, O_RDONLY);

    if ((aws_state.xdma_rd_fd[q] < 0) || (aws_state.xdma_wr_fd[q] < 0)) {
      fprintf(stderr, "[FLETCHER_AWS] Did not get a valid file descriptor.\n"
                      "[FLETCHER_AWS] Is the XDMA driver installed?\n");
      aws_state.error = 1;
      return FLETCHER_STATUS_ERROR;
    }
  }

  // Set the PCI bar handle init
  aws_state.pci_bar_handle = PCI_BAR_HANDLE_INIT;
  debug_print("[FLETCHER_AWS] Bar handle init: %d\n", aws_state.pci_bar_handle);

  // Attach the FPGA
  debug_print("[FLETCHER_AWS] Attaching PCI <-> FPGA\n");
  rc = fpga_pci_attach(aws_state.config.slot_id,
                       aws_state.config.pf_id,
                       aws_state.config.bar_id,
                       0,
                       &aws_state.pci_bar_handle);

  debug_print("[FLETCHER_AWS] Bar handle init: %d\n", aws_state.pci_bar_handle);

  if (rc != 0) {
    fprintf(stderr, "[FLETCHER_AWS] Could not attach PCI <-> FPGA. Are you running as root? "
                    "[FLETCHER_AWS] Entering error state. fpga_pci_attach: %d\n", rc);
    return FLETCHER_STATUS_ERROR;
  }

  return FLETCHER_STATUS_OK;
}

fstatus_t platformWriteMMIO(uint64_t offset, uint32_t value) {
  int rc = 0;
  rc = fpga_pci_poke(aws_state.pci_bar_handle, sizeof(uint32_t) * offset, value);
  if (rc != 0) {
    fprintf(stderr, "[FLETCHER_AWS] MMIO write failed.\n");
    aws_state.error = 1;
    return FLETCHER_STATUS_ERROR;
  }
  debug_print("[FLETCHER_AWS] MMIO Write %d : %08X\n", (uint32_t) offset, (uint32_t) value);
  return FLETCHER_STATUS_OK;
}

fstatus_t platformReadMMIO(uint64_t offset, uint32_t *value) {
  *value = 0xDEADBEEF;
  int rc = 0;
  rc = fpga_pci_peek(aws_state.pci_bar_handle, sizeof(uint32_t) * offset, value);
  if (rc != 0) {
    fprintf(stderr, "[FLETCHER_AWS] MMIO read failed.\n");
    aws_state.error = 1;
    return FLETCHER_STATUS_ERROR;
  }
  debug_print("[FLETCHER_AWS] MMIO Read %d : %08X\n", (uint32_t) offset, (uint32_t)(*value));
  return FLETCHER_STATUS_OK;
}

fstatus_t platformCopyHostToDevice(const uint8_t *host_source, da_t device_destination, int64_t size) {
  size_t total = 0;

  debug_print("[FLETCHER_AWS] Copying host to device %016lX -> %016lX (%li bytes).\n",
              (uint64_t) host_source,
              (uint64_t) device_destination,
              size);

  size_t written[FLETCHER_AWS_NUM_QUEUES] = {0};

  int queues = FLETCHER_AWS_NUM_QUEUES;

  // Only use more queues if the data to copy is larger than the queue threshold
  if (size < FLETCHER_AWS_QUEUE_THRESHOLD) {
    queues = 1;
  }
  size_t qbytes = (size_t)(size / queues);

  for (int q = 0; q < queues; q++) {
    ssize_t rc = 0;
    // Determine number of bytes for the whole transfer
    size_t qtotal = qbytes;
    const uint8_t *qsource = host_source + q * qbytes;
    da_t qdest = device_destination + qbytes * q;

    // For the last queue check how many extra bytes we must copy
    if (q == queues - 1) {
      qtotal = qbytes + (size % queues);
    }

    while (written[q] < qtotal) {
      // Write some bytes
      rc = pwrite(aws_state.xdma_wr_fd[q],
                  (void *) ((uint64_t) qsource + written[q]),
                  qtotal - written[q],
                  qdest + written[q]);

      // If rc is negative there is something else going wrong. Abort the mission
      if (rc < 0) {
        int errsv = errno;
        fprintf(stderr, "[FLETCHER_AWS] Copy host to device failed. Queue: %d. Error: %s\n", q, strerror(errsv));
        aws_state.error = 1;
        return FLETCHER_STATUS_ERROR;
      }
      written[q] += rc;
    }
  }
  for (int q = 0; q < queues; q++) {
    total += written[q];

    // Synchronize the files
    fsync(aws_state.xdma_wr_fd[q]);
  }

#ifdef DEBUG
  fstatus_t ddr_check = check_ddr(host_source, device_destination, size);
  if (ddr_check != FLETCHER_STATUS_OK) {
    fprintf(stderr, "[FLETCHER_AWS] Copied buffer in DDR differs from host buffer.\n");
  }
  return ddr_check;
#endif

  return FLETCHER_STATUS_OK;
}

fstatus_t platformCopyDeviceToHost(da_t device_source, uint8_t *host_destination, int64_t size) {
  debug_print("[FLETCHER_AWS] Copying from device to host. [dev] 0x%016lX --> [host] 0x%016lX (%lu bytes)\n",
              device_source,
              (uint64_t) host_destination,
              size);
  return FLETCHER_STATUS_OK;
}

fstatus_t platformTerminate(void *arg) {
  debug_print("[FLETCHER_AWS] Terminating platform.        Arguments @ [host] 0x%016lX.\n", (uint64_t) arg);

  int rc = fpga_pci_detach(aws_state.pci_bar_handle);

  if (rc != 0) {
    fprintf(stderr, "[FLETCHER_AWS] Could not detach FPGA PCI\n");
    return FLETCHER_STATUS_ERROR;
  }

  for (int q = 0; q < FLETCHER_AWS_NUM_QUEUES; q++) {
    close(q);
  }

  return FLETCHER_STATUS_OK;
}

fstatus_t platformDeviceMalloc(da_t *device_address, int64_t size) {
  *device_address = buffer_ptr;
  debug_print("[FLETCHER_AWS] Allocating device memory.    [device] 0x%016lX (%10lu bytes).\n",
              (uint64_t) *device_address,
              size);
  buffer_ptr += size + FLETCHER_AWS_DEVICE_ALIGNMENT - (size % FLETCHER_AWS_DEVICE_ALIGNMENT);
  return FLETCHER_STATUS_OK;
}

fstatus_t platformDeviceFree(da_t device_address) {
  debug_print("[FLETCHER_AWS] Freeing device memory.       [device] 0x%016lX : NOT IMPLEMENTED.\n", device_address);
  return FLETCHER_STATUS_OK;
}

fstatus_t platformPrepareHostBuffer(const uint8_t *host_source, da_t *device_destination, int64_t size, int *alloced) {
  debug_print("[FLETCHER_AWS] Prepare is equal to cache on AWS f1.\n");
  *alloced = 1;
  return platformCacheHostBuffer(host_source, device_destination, size);
}

fstatus_t platformCacheHostBuffer(const uint8_t *host_source, da_t *device_destination, int64_t size) {
  *device_destination = buffer_ptr;
  debug_print("[FLETCHER_AWS] Caching buffer on device.    [host] 0x%016lX --> 0x%016lX (%10lu bytes).\n",
              (unsigned long) host_source,
              (unsigned long) *device_destination,
              size);
  fstatus_t ret = platformCopyHostToDevice(host_source, buffer_ptr, size);
  *device_destination = buffer_ptr;
  buffer_ptr += size + (FLETCHER_AWS_DEVICE_ALIGNMENT - (size % FLETCHER_AWS_DEVICE_ALIGNMENT));
  return ret;
}
