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

#include "cerata/vhdl/identifier.h"

#include <utility>
#include <string>
#include <vector>

namespace cerata::vhdl {

std::string Identifier::ToString() const {
  std::string ret;
  for (const auto &p : parts_) {
    ret += p;
    if (separator_) {
      if (p != parts_.back()) {
        ret += *separator_;
      }
    }
  }
  return ret;
}

Identifier::Identifier(std::initializer_list<std::string> parts, std::optional<char> sep) : separator_(std::move(sep)) {
  for (const auto &p : parts) {
    parts_.push_back(p);
  }
}

Identifier::Identifier(std::deque<std::string> parts, std::optional<char> sep) : separator_(std::move(sep)) {
  parts_ = std::move(parts);
}

Identifier &Identifier::append(const std::string &part) {
  if (!part.empty()) {
    parts_.push_back(part);
  }
  return *this;
}

Identifier &Identifier::prepend(const std::string &part) {
  if (!part.empty()) {
    parts_.push_front(part);
  }
  return *this;
}

/**
 * \brief
 * \param rhs
 * \return
 */
Identifier &Identifier::operator+=(const std::string &rhs) {
  return append(rhs);
}

Identifier Identifier::operator+(const std::string &rhs) const {
  Identifier ret = *this;
  ret.append(rhs);
  return ret;
}

}  // namespace cerata::vhdl
