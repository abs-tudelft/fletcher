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
#include <stdlib.h>

#include "fletcher/fletcher.h"

#include "./fletcher_echo.h"

#define CHECK_STATUS(identifier) if (identifier != FLETCHER_STATUS_OK) { \
                                   return status;                        \
                                 }                                       \
                                 (void)0

#define echo_print(...) do { if (!options.quiet) fprintf(stdout, __VA_ARGS__); } while (0)

InitOptions options = {0};

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
  if (arg != NULL) {
    options = *(InitOptions *) arg;
  }
  echo_print("[ECHO] Initializing platform.       Arguments @ [host] %016lX.\n", (unsigned long) arg);
  return FLETCHER_STATUS_OK;
}

fstatus_t platformWriteMMIO(uint64_t offset, uint32_t value) {
  echo_print("[ECHO] Writing MMIO register.       %04lu <= 0x%08X\n", offset, value);
  return FLETCHER_STATUS_OK;
}

fstatus_t platformReadMMIO(uint64_t offset, uint32_t *value) {
  *value = 0xDEADBEEF;
  echo_print("[ECHO] Reading MMIO register.       %04lu => 0x%08X\n", offset, *value);
  return FLETCHER_STATUS_OK;
}

fstatus_t platformCopyHostToDevice(const uint8_t *host_source, da_t device_destination, int64_t size) {
  memcpy((void*)device_destination, host_source, size);
  echo_print("[ECHO] Copied from host to device.  [host] 0x%016lX --> [dev] 0x%016lX (%ld bytes)\n",
             (uint64_t) host_source,
             device_destination,
             size);
  return FLETCHER_STATUS_OK;
}

fstatus_t platformCopyDeviceToHost(da_t device_source, uint8_t *host_destination, int64_t size) {
  memcpy(host_destination, (void*)device_source, size);
  echo_print("[ECHO] Copied from device to host.  [dev] 0x%016lX --> [host] 0x%016lX (%ld bytes)\n",
             device_source,
             (uint64_t) host_destination,
             size);
  return FLETCHER_STATUS_OK;
}

fstatus_t platformTerminate(void *arg) {
  echo_print("[ECHO] Terminating platform.        Arguments @ [host] 0x%016lX.\n", (uint64_t) arg);
  return FLETCHER_STATUS_OK;
}

fstatus_t platformDeviceMalloc(da_t *device_address, int64_t size) {
  // Aligned allocate some memory.
  posix_memalign((void**)device_address, FLETCHER_ECHO_ALIGNMENT, (size_t) size);
  echo_print("[ECHO] Allocating device memory.    [device] 0x%016lX (%10lu bytes).\n", (uint64_t)*device_address, size);
  return FLETCHER_STATUS_OK;
}

fstatus_t platformDeviceFree(da_t device_address) {
  free((void *) device_address);
  echo_print("[ECHO] Freeing device memory.       [device] 0x%016lX.\n", device_address);
  return FLETCHER_STATUS_OK;
}

fstatus_t platformPrepareHostBuffer(const uint8_t *host_source, da_t *device_destination, int64_t size, int *alloced) {
  fstatus_t status;

  // Allocate new memory.
  status = platformDeviceMalloc(device_destination, size);
  // We have newly allocated the buffer, signal this back to the caller.
  *alloced = 1;
  CHECK_STATUS(status);

  // Copy data
  status = platformCopyHostToDevice(host_source, *device_destination, size);

  echo_print("[ECHO] Prepared buffer on device.   [host] 0x%016lX --> 0x%016lX (%10lu bytes).\n",
             (unsigned long) host_source,
             (unsigned long) *device_destination,
             size);

  return status;
}

fstatus_t platformCacheHostBuffer(const uint8_t *host_source, da_t *device_destination, int64_t size) {
  fstatus_t status;

  // Allocate new memory.
  status = platformDeviceMalloc(device_destination, size);
  CHECK_STATUS(status);

  // Copy data
  status = platformCopyHostToDevice(host_source, *device_destination, size);

  echo_print("[ECHO] Cached buffer on device.    [host] 0x%016lX --> 0x%016lX (%10lu bytes).\n",
             (unsigned long) host_source,
             (unsigned long) *device_destination,
             size);

  return status;
}
