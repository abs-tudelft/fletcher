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

#include "fletcher/platform.h"

#include <arrow/api.h>
#include <fletcher/common.h>

#include <string>
#include <vector>
#include <memory>
#include <iomanip>
#include <sstream>

#include "fletcher/status.h"

namespace fletcher {

std::string Platform::name() {
  assert(platformGetName != nullptr);
  char buf[64] = {0};
  if (platformGetName != nullptr) {
    platformGetName(buf, 64);
  } else {
    return "INVALID_PLATFORM";
  }
  return std::string(buf);
}

Status Platform::Make(const std::string &name, std::shared_ptr<fletcher::Platform> *platform_out, bool quiet) {
  // Attempt to open shared library
  void *handle = nullptr;
  handle = dlopen(("libfletcher_" + name + DYLIB_EXT).c_str(), RTLD_NOW);

  if (handle) {
    // Create a new platform
    *platform_out = std::make_shared<Platform>();
    // Attempt to link the functions and return the result
    return (*platform_out)->Link(handle, quiet);
  } else {
    // Could not open shared library
    platform_out = nullptr;
    if (!quiet) {
      FLETCHER_LOG(WARNING, dlerror());
    }
    return Status::NO_PLATFORM();
  }
}

Status Platform::Make(std::shared_ptr<fletcher::Platform> *platform_out, bool quiet) {
  Status status = Status::NO_PLATFORM();
  if (!quiet) {
    FLETCHER_LOG(INFO, "Attempting to autodetect Fletcher hardware platform...");
  }
  std::vector<std::string> autodetect_platforms = {FLETCHER_AUTODETECT_PLATFORMS};
  std::string logstr;
  for (const auto &p : autodetect_platforms) {
    // Attempt to create platform
    status = Make(p, platform_out, quiet);
    if (status.ok()) {
      // We've found a working platform, use that.
      return status;
    }
    if (!quiet && (p != autodetect_platforms.back())) {
      FLETCHER_LOG(INFO, "Attempting next platform...");
    }
  }
  return status;
}

Status Platform::Link(void *handle, bool quiet) {
  if (handle) {
    *reinterpret_cast<void **>((&platformInit)) = dlsym(handle, "platformInit");
    *reinterpret_cast<void **>((&platformGetName)) = dlsym(handle, "platformGetName");
    *reinterpret_cast<void **>((&platformWriteMMIO)) = dlsym(handle, "platformWriteMMIO");
    *reinterpret_cast<void **>((&platformReadMMIO)) = dlsym(handle, "platformReadMMIO");
    *reinterpret_cast<void **>((&platformDeviceMalloc)) = dlsym(handle, "platformDeviceMalloc");
    *reinterpret_cast<void **>((&platformDeviceFree)) = dlsym(handle, "platformDeviceFree");
    *reinterpret_cast<void **>((&platformCopyHostToDevice)) = dlsym(handle, "platformCopyHostToDevice");
    *reinterpret_cast<void **>((&platformCopyDeviceToHost)) = dlsym(handle, "platformCopyDeviceToHost");
    *reinterpret_cast<void **>((&platformPrepareHostBuffer)) = dlsym(handle, "platformPrepareHostBuffer");
    *reinterpret_cast<void **>((&platformCacheHostBuffer)) = dlsym(handle, "platformCacheHostBuffer");
    *reinterpret_cast<void **>((&platformTerminate)) = dlsym(handle, "platformTerminate");

    char *err = dlerror();

    if (err == nullptr) {
      return Status::OK();
    } else {
      if (!quiet) {
        FLETCHER_LOG(ERROR, err);
      }
      return Status::ERROR();
    }
  } else {
    FLETCHER_LOG(ERROR, "Cannot link FPGA platform functions. Invalid handle.");
    return Status::ERROR();
  }
}

Status Platform::ReadMMIO64(uint64_t offset, uint64_t *value) {
  freg_t hi, lo;
  Status stat;

  // Read high bits
  stat = ReadMMIO(offset + 1, &hi);
  if (!stat.ok()) {
    return stat;
  }
  *value = ((uint64_t) hi) << 32u;

  // Read low bits
  stat = ReadMMIO(offset, &lo);
  if (!stat.ok()) {
    return stat;
  }
  *value |= lo;

  return Status::OK();
}

Status Platform::MmioToString(std::string *str, uint64_t start, uint64_t stop, bool quiet) {
  std::stringstream ss;
  Status stat;
  for (uint64_t off = start; off < stop; off++) {
    uint32_t val;
    stat = ReadMMIO(off, &val);
    if (!stat.ok()) {
      return stat;
    } else {
      if (!quiet) {
        ss << "R" << std::uppercase << std::hex << std::setw(3) << std::setfill('0') << off
           << ":" << std::uppercase << std::hex << std::setw(8) << std::setfill('0') << val
           << std::endl;
      }
    }
  }
  *str = ss.str();
  return Status::OK();
}

}  // namespace fletcher
