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

#include <stdio.h>
#include <memory.h>

#include "../../../../common/c/src/fletcher/fletcher.h"

#include "fletcher_snap.h"

da_t buffer_ptr = 0x0;

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
  debug_print("[FLETCHER_SNAP] Initializing platform.       Arguments @ [host] %016lX.\n", (unsigned long) arg);

  // Check psl_server.dat is present

  if (snap_state.sim) {
    if (access("pslse_server.dat", F_OK) == -1) {
      debug_print("[FLETCHER_SNAP] No pslse_server.dat file present in working directory. Entering error state.\n");
      snap_state.error = 1;
      return FLETCHER_STATUS_ERROR;
    }
  }

  debug_print(snap_state.device, "/dev/cxl/afu%d.0s", snap_state.card_no);
  snap_state.card_handle = snap_card_alloc_dev(snap_state.device, SNAP_VENDOR_ID_IBM, SNAP_DEVICE_ID_SNAP);

  if (snap_state.card_handle == NULL) {
    debug_print("[FLETCHER_SNAP] Could not allocate SNAP card. Entering error state.");
    snap_state.error = 1;
    return FLETCHER_STATUS_ERROR;
  }

  unsigned long ioctl_data;

  snap_card_ioctl(snap_state.card_handle, GET_CARD_TYPE, (unsigned long) &ioctl_data);

  switch (ioctl_data) {
    case 0:debug_print("ADKU3");
      break;
    case 1:debug_print("N250S");
      break;
    case 16:debug_print("N250SP");
      break;
    default:debug_print("Unknown");
      break;
  }

  snap_card_ioctl(snap_state.card_handle, GET_SDRAM_SIZE, (unsigned long) &ioctl_data);
  debug_print("Available card RAM: %d\n", (int) ioctl_data);

  snap_action_flag_t attach_flags = (snap_action_flag_t) 0;

  snap_state.action_handle = snap_attach_action(snap_state.card_handle, snap_state.action_type, attach_flags, 100);

  return FLETCHER_STATUS_OK;
}

fstatus_t platformWriteMMIO(uint64_t offset, uint32_t value) {
  snap_mmio_write32(snap_state.card_handle, 4 * (2 * (FLETCHER_SNAP_ACTION_REG_OFFSET + offset)), value);
  debug_print("[FLETCHER_SNAP] Writing MMIO register.       %04lu <= 0x%08X\n", offset, value);
  return FLETCHER_STATUS_OK;
}

fstatus_t platformReadMMIO(uint64_t offset, uint32_t *value) {
  *value = 0xDEADBEEF;
  snap_mmio_read32(snap_state.card_handle, 4 * (2 * (FLETCHER_SNAP_ACTION_REG_OFFSET + offset)), value);
  debug_print("[FLETCHER_SNAP] Reading MMIO register.       %04lu => 0x%08X\n", offset, *value);
  return FLETCHER_STATUS_OK;
}

fstatus_t platformCopyHostToDevice(const uint8_t *host_source, da_t device_destination, int64_t size) {
  debug_print(
      "[FLETCHER_SNAP] Copying from host to device. [host] 0x%016lX --> [dev] 0x%016lX (%lu bytes) (NOT IMPLEMENTED)\n",
      (uint64_t) host_source,
      device_destination,
      size);
  return FLETCHER_STATUS_OK;
}

fstatus_t platformCopyDeviceToHost(da_t device_source, uint8_t *host_destination, int64_t size) {
  debug_print(
      "[FLETCHER_SNAP] Copying from device to host. [dev] 0x%016lX --> [host] 0x%016lX (%lu bytes) (NOT IMPLEMENTED)\n",
      device_source,
      (uint64_t) host_destination,
      size);
  return FLETCHER_STATUS_OK;
}

fstatus_t platformTerminate(void *arg) {
  debug_print("[FLETCHER SNAP] Terminating platform.        Arguments @ [host] 0x%016lX.\n", (uint64_t) arg);
  snap_detach_action(snap_state.action_handle);
  snap_card_free(snap_state.card_handle);
  return FLETCHER_STATUS_OK;
}

fstatus_t platformDeviceMalloc(da_t *device_address, int64_t size) {
  *device_address = buffer_ptr;
  debug_print("[FLETCHER_SNAP] Allocating device memory.    [device] 0x%016lX (%10lu bytes). (NOT IMPLEMENTED)\n",
              (uint64_t) device_address,
              size);
  buffer_ptr += size;
  return FLETCHER_STATUS_OK;
}

fstatus_t platformDeviceFree(da_t device_address) {
  debug_print("[FLETCHER_SNAP] Freeing device memory.       [device] 0x%016lX. (NOT IMPLEMENTED)\n", device_address);
  return FLETCHER_STATUS_OK;
}

fstatus_t platformPrepareHostBuffer(const uint8_t *host_source, da_t *device_destination, int64_t size, int *alloced) {
  *device_destination = (da_t) host_source;
  *alloced = 0;
  debug_print("[FLETCHER_SNAP] Preparing buffer for device. [host] 0x%016lX --> 0x%016lX (%10lu bytes).\n",
              (unsigned long) host_source,
              (unsigned long) *device_destination,
              size);
  buffer_ptr += size;
  return FLETCHER_STATUS_OK;
}

fstatus_t platformCacheHostBuffer(const uint8_t *host_source, da_t *device_destination, int64_t size) {
  *device_destination = buffer_ptr;
  debug_print(
      "[FLETCHER_SNAP] Caching buffer on device.    [host] 0x%016lX --> 0x%016lX (%10lu bytes). (NOT IMPLEMENTED)\n",
      (unsigned long) host_source,
      (unsigned long) *device_destination,
      size);
  buffer_ptr += size;
  return FLETCHER_STATUS_OK;
}
