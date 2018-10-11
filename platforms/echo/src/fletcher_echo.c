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

fstatus_t platformWriteMMIO(uint64_t offset, uint32_t value) {
  printf("[ECHO] Writing register %4lu <= %08X\n", offset, value);
  return FLETCHER_STATUS_OK;
}

fstatus_t platformReadMMIO(uint64_t offset, uint32_t *value) {
  *value = 0xDEADBEEF;
  printf("[ECHO] Reading register %4lu => %08X\n", offset, *value);
  return FLETCHER_STATUS_OK;
}

fstatus_t platformCopyHostToDevice(ha_t host_source, da_t device_destination, uint64_t size) {
  printf("[ECHO] Copying %lu bytes from host: %016lX to device: %016lX.\n",
         size,
         (unsigned long) host_source,
         device_destination);
  return FLETCHER_STATUS_OK;
}

fstatus_t platformCopyDeviceToHost(da_t device_source, ha_t host_destination, uint64_t size) {
  printf("[ECHO] Copying %lu bytes from device: %016lX to host: %016lX.\n", size, device_source,
         (unsigned long) host_destination);
  return FLETCHER_STATUS_OK;
}