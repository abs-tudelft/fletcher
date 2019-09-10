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
#include <regex>
#include <map>

namespace cerata::vhdl {

/// Structure to hold a template replacement string location
struct trloc {
  /// @brief Template replacement location constructor.
  trloc(size_t line, size_t start) : line(line), start(start) {}
  /// The line.
  size_t line;
  /// The starting character index on the line.
  size_t start;
};

/// @brief Class to hold and modify a VHDL template file.
class Template {
 public:
  /// @brief Construct a Template from an input stream.
  explicit Template(std::istream *str);
  /// @brief Construct a Template from an input string.
  static Template FromString(const std::string& str);
  /// @brief Construct a Template from a file.
  static Template FromFile(const std::string &filename);
  /// @brief Mark the locations of all replaceable template strings.
  void Analyze();
  /// @brief Replace a template replacement string with some number.
  void Replace(const std::string &str, int with);
  /// @brief Replace a template replacement string with some other string.
  void Replace(const std::string &str, const std::string &with);
  /// @brief Return the file as a string.
  std::string ToString();

 private:
  /// Map from a template replacement string to a vector of line numbers.
  std::map<std::string, std::vector<trloc>> replace_list_;
  /// Lines of the file.
  std::vector<std::string> lines_;
};

}  // namespace cerata::vhdl
