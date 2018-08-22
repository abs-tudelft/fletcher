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

#include <fcntl.h>
#include <unistd.h>
#include <omp.h>
#include <fstream>

#include <arrow/api.h>

#include "../logging.h"
#include "echo.h"

namespace fletcher {

EchoPlatform::EchoPlatform() {
  LOGI("[ECHO] Platform created.");
}

EchoPlatform::~EchoPlatform() {
  LOGI("[ECHO] Platform destroyed.");
}

uint64_t EchoPlatform::organize_buffers(const std::vector<BufConfig> &source_buffers,
                                        std::vector<BufConfig> &dest_buffers) {
  uint64_t bytes = 0;

  // Simply copy the source to the destination BufConfigs
  for (auto const &src : source_buffers) {
    bytes += src.size;
    dest_buffers.push_back(src);
  }

  return bytes;
}

inline int EchoPlatform::write_mmio(uint64_t offset, fr_t value) {
  LOGI("[ECHO] Write to  " << STRHEX64 << offset << " value: " << STRHEX64 << value);
  return fletcher::OK;
}

inline int EchoPlatform::read_mmio(uint64_t offset, fr_t *dest) {
  *dest = 0xDEADBEEF;

  LOGI("[ECHO] Read from " << STRHEX64 << offset << " value: ? ");

  fr_t x;
  std::cin >> std::hex >> x;

  *dest = x;

  return fletcher::OK;
}

bool EchoPlatform::good() {
  return true;
}

}
