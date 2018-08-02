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

#pragma once

#include <string>
#include <vector>
#include <fstream>
#include <map>
#include <regex>
#include <list>

#include "../logging.h"

namespace fletchgen {

// @brief Structure to hold a template replacement string location
struct trloc {
  trloc(size_t line, size_t start) : line(line), start(start) {};
  size_t line;
  size_t start;
};

/// @brief Class to hold and modify a VHDL template file
class vhdt {
 public:
  explicit vhdt(const std::string &filename);

  void replace(const std::string &str, int with) {
    replace(str, std::to_string(with));
  }

  void replace(const std::string &str, const std::string &with) {
    for (const auto &item : replace_list_) {
      if (item.first == str) {
        auto loc = item.second;

        LOGI(item.first + " in " + lines_[loc.line]);

        // +3 for ${}
        lines_[loc.line].replace(loc.start, str.length() + 3, with);
      }
    }
  }

  std::string toString() {
    std::string out;
    for (const auto &l : lines_) {
      out.append(l);
      out.append("\n");
    }
    return out;
  }

 private:
  // Map from a template replacement string to a vector of line numbers.
  std::list<std::pair<std::string, trloc>> replace_list_;
  std::vector<std::string> lines_;
};

} //namespace fletchgen
