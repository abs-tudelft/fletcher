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

#include <fstream>
#include "vhdt.h"
#include "vhdt.h"

namespace fletchgen {

VHDLTemplate::VHDLTemplate(const std::string &filename) {
  std::ifstream ifs(filename);
  if (!ifs.is_open()) {
    throw std::runtime_error("Could not open VHDL template file " + filename);
  } else {
    LOGD("Opened template file " + filename);
  }

  // Replacement string regex
  std::regex rs_regex(R"(\$\{[a-zA-Z0-9_]+\})");

  std::string line;

  size_t line_num = 0;

  while (std::getline(ifs, line)) {
    lines_.push_back(line);

    // Check if the line has any matches
    auto rs_begin = std::sregex_iterator(line.begin(), line.end(), rs_regex);
    auto rs_end = std::sregex_iterator();

    // Find the matches in this line
    for (std::sregex_iterator i = rs_begin; i != rs_end; ++i) {
      std::smatch match = *i;
      std::string match_string = match.str();
      std::string replace_string = match_string.substr(2, match_string.length() - 3);
      trloc loc(trloc(line_num, static_cast<size_t>(match.position(0))));
      replace_list_[replace_string].push_back(loc);
    }

    line_num++;
  }

  ifs.close();
}

void VHDLTemplate::replace(const std::string &str, int with) {
  replace(str, std::to_string(with));
}

void VHDLTemplate::replace(const std::string &str, const std::string &with) {
  if (replace_list_.find(str) != replace_list_.end()) {
    for (const auto& loc : replace_list_[str]) {
      // +3 for ${}
      lines_[loc.line].replace(loc.start, str.length() + 3, with);
    }
  }
}

std::string VHDLTemplate::toString() {
  std::string out;
  for (const auto &l : lines_) {
    out.append(l);
    out.append("\n");
  }
  return out;
}

} //namespace fletchgen
