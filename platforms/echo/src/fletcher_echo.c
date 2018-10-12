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
#include <string.h>

#include "fletcher.h"

#include "fletcher_echo.h"

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
  printf("[ECHO] Writing register.            %04lu <= %08X\n", offset, value);
  return FLETCHER_STATUS_OK;
}

fstatus_t platformReadMMIO(uint64_t offset, uint32_t *value) {
  *value = 0xDEADBEEF;
  printf("[ECHO] Reading register.            %04lu => %08X\n", offset, *value);
  return FLETCHER_STATUS_OK;
}

fstatus_t platformCopyHostToDevice(ha_t host_source, da_t device_destination, uint64_t size) {
  printf("[ECHO] Copying from host to device. [host] %016lX (%10lu bytes) => [dev]  %016lX.\n",
         (unsigned long) host_source,
         size,
         device_destination);
  return FLETCHER_STATUS_OK;
}

fstatus_t platformCopyDeviceToHost(da_t device_source, ha_t host_destination, uint64_t size) {
  printf("[ECHO] Copying from device to host. [dev]  %016lX (%8lu bytes) => [host] %016lX.\n",
         device_source,
         size,
         (unsigned long) host_destination);
  return FLETCHER_STATUS_OK;
}

fstatus_t platformTerminate(void *arg) {
  printf("[ECHO] Terminating platform.        Arguments @ [host] %016lX.\n", (unsigned long) arg);
  return FLETCHER_STATUS_OK;
}

fstatus_t platformDeviceMalloc(da_t *device_address, size_t size) {
  *device_address = 0xFEEDBEEFDEADBEEF;
  printf("[ECHO] Allocating device memory.    %lu bytes @ [device] %016lX.\n", size, (unsigned long) device_address);
  return FLETCHER_STATUS_OK;
}

fstatus_t platformDeviceFree(da_t device_address) {
  printf("[ECHO] Freeing device memory.       @ [device] %016lX.\n", (unsigned long) device_address);
  return FLETCHER_STATUS_OK;
}

fstatus_t platformPrepareHostBuffer(ha_t host_source, da_t *device_destination, uint64_t size) {
  *device_destination = 0xFEEDBEEFDEADBEEF;
  printf("[ECHO] Preparing buffer for device. Preparing %8lu bytes @ [host] %016lX => %016lX.\n",
         size,
         (unsigned long) host_source,
         (unsigned long) *device_destination);
  return FLETCHER_STATUS_OK;
}

fstatus_t platformCacheHostBuffer(ha_t host_source, da_t *device_destination, uint64_t size) {
  printf("[ECHO] Caching buffer on device.    Preparing %8lu bytes @ [host] %016lX => %016lX.\n",
         size,
         (unsigned long) host_source,
         (unsigned long) *device_destination);
  return FLETCHER_STATUS_OK;
}
