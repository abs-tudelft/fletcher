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

#include "cerata/vhdl/template.h"

#include <sstream>
#include <iostream>
#include "cerata/logging.h"

namespace cerata::vhdl {

Template::Template(std::istream *str) {
  std::string line;
  while (std::getline(*str, line)) {
    lines_.push_back(line);
  }
  Analyze();
}

Template Template::FromString(const std::string &str) {
  std::stringstream stream;
  stream << str;
  Template result(&stream);
  return result;
}

Template Template::FromFile(const std::string &filename) {
  std::ifstream ifs(filename);
  if (!ifs.is_open()) {
    throw std::runtime_error("Could not open VHDL template file " + filename);
  } else {
    CERATA_LOG(DEBUG, "Opened template file " + filename);
  }
  Template result(&ifs);
  ifs.close();
  return result;
}

void Template::Replace(const std::string &str, int with) {
  Replace(str, std::to_string(with));
}

void Template::Replace(const std::string &str, const std::string &with) {
  if (replace_list_.find(str) != replace_list_.end()) {
    for (const auto &loc : replace_list_[str]) {
      // +3 for ${}
      lines_[loc.line].replace(loc.start, str.length() + 3, with);
    }
  }
}

std::string Template::ToString() {
  std::string out;
  for (const auto &l : lines_) {
    out.append(l);
    out.append("\n");
  }
  return out;
}

void Template::Analyze() {
  // Replacement string regex
  const std::regex rs_regex(R"(\$\{[a-zA-Z0-9_]+\})");

  // Empty the replace list
  replace_list_ = {};

  // Analyze every line for replacement regex
  size_t line_num = 0;
  for (const auto &line : lines_) {
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
}

}  // namespace cerata::vhdl
