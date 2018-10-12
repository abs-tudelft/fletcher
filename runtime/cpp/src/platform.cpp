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

#include "platform.h"

namespace fletcher {

std::string Platform::getName() {
  assert(platformGetName != nullptr);
  char buf[64] = {0};
  platformGetName(buf, 64);
  return std::string(buf);
}

Status Platform::create(const std::string &name, std::shared_ptr<fletcher::Platform> *platform, bool quiet) {
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
      std::cerr << dlerror() << std::endl;
    }
    return Status::ERROR();
  }
}

Status Platform::link(void *handle, bool quiet) {
  if (handle) {
    *reinterpret_cast<void **>((&platformInit))               = dlsym(handle, "platformInit");
    *reinterpret_cast<void **>((&platformGetName))            = dlsym(handle, "platformGetName");
    *reinterpret_cast<void **>((&platformWriteMMIO))          = dlsym(handle, "platformWriteMMIO");
    *reinterpret_cast<void **>((&platformReadMMIO))           = dlsym(handle, "platformReadMMIO");
    *reinterpret_cast<void **>((&platformDeviceMalloc))       = dlsym(handle, "platformDeviceMalloc");
    *reinterpret_cast<void **>((&platformDeviceFree))         = dlsym(handle, "platformDeviceFree");
    *reinterpret_cast<void **>((&platformCopyHostToDevice))   = dlsym(handle, "platformCopyHostToDevice");
    *reinterpret_cast<void **>((&platformCopyDeviceToHost))   = dlsym(handle, "platformCopyDeviceToHost");
    *reinterpret_cast<void **>((&platformPrepareHostBuffer))  = dlsym(handle, "platformPrepareHostBuffer");
    *reinterpret_cast<void **>((&platformCacheHostBuffer))    = dlsym(handle, "platformCacheHostBuffer");
    *reinterpret_cast<void **>((&platformTerminate))          = dlsym(handle, "platformTerminate");

    char *err = dlerror();

    if (err == nullptr) {
      return Status::OK();
    } else {
      if (!quiet) {
        std::cerr << err << std::endl;
      }
      return Status::ERROR();
    }
  } else {
    std::cerr << "Cannot link FPGA platform functions. Invalid handle." << std::endl;
    return Status::ERROR();
  }
}

Status Platform::create(std::shared_ptr<fletcher::Platform> *platform) {
  Status err = Status::ERROR();
  std::vector<std::string> autodetect_platforms = {FLETCHER_AUTODETECT_PLATFORMS};
  for (const auto &p : autodetect_platforms) {
    // Attempt to create platform
    std::cerr << "[FLETCHER] Attempting to autodetect " << p << ": ";
    err = create(p, platform);
    if (err.ok()) {
      std::cerr << "SUCCESS." << std::endl;
      return err;
    } else {
      std::cerr << "FAILED." << std::endl;
    }
  }
  return err;
}

}  // namespace fletcher
