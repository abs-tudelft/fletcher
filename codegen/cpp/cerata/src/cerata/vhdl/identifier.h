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

#include <optional>
#include <string>
#include <vector>
#include <deque>
#include <algorithm>

namespace cerata::vhdl {

/// @brief Return the upper-case version of a string.
std::string to_upper(std::string str);

/**
 * @brief A VHDL Identifier convenience structure.
 */
class Identifier {
 public:
  Identifier() = default;
  /// @brief Construct an identifier from a bunch of strings.
  Identifier(std::initializer_list<std::string> parts, std::optional<char> sep = '_');
  /// @brief Construct an identifier from a bunch of strings.
  explicit Identifier(std::deque<std::string> parts, std::optional<char> sep = '_');
  /// @brief Append a part to the Identifier.
  Identifier &append(const std::string &part);
  /// @brief Append a part to the Identifier.
  Identifier &prepend(const std::string &part);
  /// @brief Append a part to the Identifier.
  Identifier &operator+=(const std::string &rhs);
  /// @brief Create a copy and add a new part to the Identifier.
  Identifier operator+(const std::string &rhs) const;
  /// @brief Return a human-readable string of the identifier.
  std::string ToString() const;
 private:
  /// The separator character between different parts of the identifier.
  std::optional<char> separator_ = '_';
  /// The parts of the identifier.
  std::deque<std::string> parts_;
};

}  // namespace cerata::vhdl
