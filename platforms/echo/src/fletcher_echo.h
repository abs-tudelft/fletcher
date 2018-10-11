#include <stdint.h>

#include <fletcher.h>

#define FLETCHER_PLATFORM_NAME "echo"

fstatus_t platformGetName(char* name, size_t size);

fstatus_t platformInit(void* arg);

fstatus_t platformWriteMMIO(uint64_t offset, uint32_t value);
fstatus_t platformReadMMIO(uint64_t offset, uint32_t *value);

fstatus_t platformCopyHostToDevice(ha_t host_source, da_t device_destination, uint64_t size);
fstatus_t platformCopyDeviceToHost(da_t device_source, ha_t host_destination, uint64_t size);

fstatus_t platformTerminate(void* arg);
