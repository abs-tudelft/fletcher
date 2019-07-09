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

#include "cerata/utils.h"

#include <filesystem>
#include <unordered_map>
#include <string>

#include "cerata/logging.h"

namespace cerata {

std::string ToString(const std::unordered_map<std::string, std::string> &meta) {
  std::string result;
  if (!meta.empty()) {
    result += "{";
    size_t i = 0;
    for (const auto &kv : meta) {
      result += kv.first + "=" + kv.second;
      if (i != meta.size() - 1) {
        result += ",";
      }
      i++;
    }
    result += "}";
  }
  return result;
}

void CreateDir(const std::string &dir_name) {
  // Check if the directory already exists, if not, create it.
  if (!std::filesystem::exists(dir_name)) {
    std::error_code err;
    bool result = std::filesystem::create_directories(dir_name, err);
    if (!result) {
      CERATA_LOG(ERROR, "Could not create directories: " + dir_name + " Error message:" + err.message());
    }
  }
}

bool FileExists(const std::string &name) {
  std::ifstream f(name.c_str());
  return f.good();
}

}  // namespace cerata
