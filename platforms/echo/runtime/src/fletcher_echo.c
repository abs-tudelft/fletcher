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
#include <malloc.h>

#include "../../../../common/c/src/fletcher.h"

#include "fletcher_echo.h"

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
  printf("[ECHO] Initializing platform.       Arguments @ [host] %016lX.\n", (unsigned long) arg);
  return FLETCHER_STATUS_OK;
}

fstatus_t platformWriteMMIO(uint64_t offset, uint32_t value) {
  printf("[ECHO] Writing MMIO register.       %04lu <= 0x%08X\n", offset, value);
  return FLETCHER_STATUS_OK;
}

fstatus_t platformReadMMIO(uint64_t offset, uint32_t *value) {
  *value = 0xDEADBEEF;
  printf("[ECHO] Reading MMIO register.       %04lu => 0x%08X\n", offset, *value);
  return FLETCHER_STATUS_OK;
}

fstatus_t platformCopyHostToDevice(const uint8_t *host_source, da_t device_destination, int64_t size) {
  printf("[ECHO] Copying from host to device. [host] 0x%016lX --> [dev] 0x%016lX (%lu bytes)\n",
         (uint64_t) host_source,
         device_destination,
         size);
  return FLETCHER_STATUS_OK;
}

fstatus_t platformCopyDeviceToHost(da_t device_source, uint8_t *host_destination, int64_t size) {
  printf("[ECHO] Copying from device to host. [dev] 0x%016lX --> [host] 0x%016lX (%lu bytes)\n",
         device_source,
         (uint64_t) host_destination,
         size);
  return FLETCHER_STATUS_OK;
}

fstatus_t platformTerminate(void *arg) {
  printf("[ECHO] Terminating platform.        Arguments @ [host] 0x%016lX.\n", (uint64_t) arg);
  return FLETCHER_STATUS_OK;
}

fstatus_t platformDeviceMalloc(da_t *device_address, int64_t size) {
  *device_address = (da_t) malloc((size_t) size);
  printf("[ECHO] Allocating device memory.    [device] 0x%016lX (%10lu bytes).\n", (uint64_t) device_address, size);
  buffer_ptr += size;
  return FLETCHER_STATUS_OK;
}

fstatus_t platformDeviceFree(da_t device_address) {
  free((void*)device_address);
  printf("[ECHO] Freeing device memory.       [device] 0x%016lX.\n", device_address);
  return FLETCHER_STATUS_OK;
}

fstatus_t platformPrepareHostBuffer(const uint8_t *host_source, da_t *device_destination, int64_t size, int *alloced) {
  *device_destination = buffer_ptr;
  *alloced = 1;
  printf("[ECHO] Preparing buffer for device. [host] 0x%016lX --> 0x%016lX (%10lu bytes).\n",
         (unsigned long) host_source,
         (unsigned long) *device_destination,
         size);
  buffer_ptr += size;
  return FLETCHER_STATUS_OK;
}

fstatus_t platformCacheHostBuffer(const uint8_t *host_source, da_t *device_destination, int64_t size) {
  *device_destination = buffer_ptr;
  printf("[ECHO] Caching buffer on device.    [host] 0x%016lX --> 0x%016lX (%10lu bytes).\n",
         (unsigned long) host_source,
         (unsigned long) *device_destination,
         size);
  buffer_ptr += size;
  return FLETCHER_STATUS_OK;
}
