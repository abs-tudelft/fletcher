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

#include <string>
#include <vector>
#include <memory>

#include <arrow/util/logging.h>
#include <iomanip>

#include "common/status.h"

#include "./platform.h"

namespace fletcher {

std::string Platform::getName() {
  assert(platformGetName != nullptr);
  char buf[64] = {0};
  platformGetName(buf, 64);
  return std::string(buf);
}

Status Platform::Make(const std::string &name, std::shared_ptr<fletcher::Platform> *platform, bool quiet) {
  // Attempt to open shared library
  void *handle = nullptr;
  handle = dlopen(("libfletcher_" + name + ".so").c_str(), RTLD_NOW);

  if (handle) {
    // Create a new platform
    *platform = std::make_shared<Platform>();
    // Attempt to link the functions and return the result
    return (*platform)->link(handle, quiet);
  } else {
    // Could not open shared library
    platform = nullptr;
    if (!quiet) {
      ARROW_LOG(ERROR) << dlerror();
    }
    return Status::ERROR();
  }
}

Status Platform::Make(std::shared_ptr<fletcher::Platform> *platform) {
  Status err = Status::ERROR();
  std::vector<std::string> autodetect_platforms = {FLETCHER_AUTODETECT_PLATFORMS};
  std::string logstr;
  for (const auto &p : autodetect_platforms) {
    // Attempt to create platform
    err = Make(p, platform);
    if (err.ok()) {
      return err;
    }
  }
  return err;
}

Status Platform::link(void *handle, bool quiet) {
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
        ARROW_LOG(ERROR) << err;
      }
      return Status::ERROR();
    }
  } else {
    ARROW_LOG(ERROR) << "Cannot link FPGA platform functions. Invalid handle.";
    return Status::ERROR();
  }
}

Status Platform::printMMIO(uint64_t start, uint64_t stop, bool quiet) {
  Status stat;
  for (uint64_t off = start; off < stop; off++) {
    uint32_t val;
    stat = readMMIO(off, &val);
    if (!stat.ok()) {
      return stat;
    } else {
      if (!quiet) {
        std::cout << "R" << std::uppercase << std::hex << std::setw(3) << std::setfill('0') << off
                  << ":" << std::uppercase << std::hex << std::setw(8) << std::setfill('0') << val
                  << std::endl;
      }
    }
  }
  return Status::OK();
}

}  // namespace fletcher
