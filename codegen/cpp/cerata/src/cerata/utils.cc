// Copyright 2018-2019 Delft University of Technology
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

#include <unordered_map>
#include <string>

#include "cerata/logging.h"

namespace cerata {

std::string ToUpper(std::string str) {
  for (auto &ch : str) ch = std::toupper(ch);
  return str;
}

std::string ToLower(std::string str) {
  for (auto &ch : str) ch = std::tolower(ch);
  return str;
}

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
  // TODO(johanpel): Create directories in a portable manner, or just wait for <filesystem>
  int ret = system(("mkdir -p " + dir_name).c_str());
  if (ret == -1) {
    CERATA_LOG(ERROR, "Could not create directory.");
  }
}

bool FileExists(const std::string &name) {
  std::ifstream f(name.c_str());
  return f.good();
}

}  // namespace cerata
