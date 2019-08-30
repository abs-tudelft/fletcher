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

#include "cerata/vhdl/block.h"

#include <regex>
#include <string>

namespace cerata::vhdl {

static std::string tab(int n) {
  return std::string(static_cast<uint64_t>(2 * n), ' ');
}

Line &operator<<(Line &lhs, const std::string &str) {
  lhs.parts.push_back(str);
  return lhs;
}

Line &operator<<(Line &lhs, const Line &rhs) {
  lhs.parts.insert(lhs.parts.end(), rhs.parts.begin(), rhs.parts.end());
  return lhs;
}

Line &operator+=(Line &lhs, const std::string &str) { //NOLINT
  lhs.parts.back().append(str);
  return lhs;
}

std::vector<size_t> Block::GetAlignments() const {
  std::vector<size_t> ret = {0};
  for (const auto &l : lines) {
    for (size_t p = 0; p < l.parts.size(); p++) {
      if (p >= ret.size()) {
        ret.push_back(l.parts[p].length());
      } else if (l.parts[p].length() > ret[p]) {
        ret[p] = l.parts[p].length();
      }
    }
  }
  return ret;
}

std::string Block::ToString() const {
  std::stringstream ret;
  auto a = GetAlignments();
  for (const auto &l : lines) {
    std::stringstream m;
    m << tab(indent);
    for (size_t p = 0; p < l.parts.size(); p++) {
      auto align = a[p];
      auto plen = l.parts[p].length();
      auto diff = align - plen;
      if (diff != 0) {
        auto padding = std::string(diff, ' ');
        m << l.parts[p] + padding;
      } else {
        m << l.parts[p];
      }
    }
    // strip trailing whitespace
    ret << std::regex_replace(m.str(), std::regex("\\s+$"), std::string("")) + "\n";
  }
  return ret.str();
}

Block &Block::Reverse() {
  std::reverse(lines.begin(), lines.end());
  return *this;
}

Block &Block::Sort(std::optional<char> c) {
  std::stable_sort(lines.begin(), lines.end(),
                   [&](const Line &la, const Line &lb) -> bool {
                     auto a = la.ToString();
                     auto b = lb.ToString();
                     if (c) {
                       return a.substr(0, a.find_first_of(*c)) > b.substr(0, b.find_first_of(*c));
                     } else {
                       return a > b;
                     }
                   });
  return *this;
}

Block &operator<<(Block &lhs, const Line &line) {
  lhs.lines.push_back(line);
  return lhs;
}

Block &operator<<(Block &lhs, const Block &rhs) {
  lhs.lines.insert(std::end(lhs.lines), std::begin(rhs.lines), std::end(rhs.lines));
  return lhs;
}

Block &Prepend(const std::string &lhs, Block *rhs, const std::string &sep) {
  if (!lhs.empty()) {
    for (auto &l : rhs->lines) {
      if (!l.parts.empty()) {
        if (l.parts.front() == " : ") {
          l.parts.insert(l.parts.begin(), lhs);
        } else {
          l.parts.front() = lhs + sep + l.parts.front();
        }
      } else {
        l << lhs;
      }
    }
  }
  return *rhs;
}

Block &operator<<(Block &lhs, const std::string &rhs) {
  if (!lhs.lines.empty()) {
    for (auto &l : lhs.lines) {
      if (!l.parts.empty()) {
        l.parts.back().append(rhs);
      }
    }
  } else {
    Line t;
    t << rhs;
    lhs << t;
  }
  return lhs;
}

Block &operator<<=(Block &lhs, const std::string &rhs) { //NOLINT
  if (!lhs.lines.empty()) {
    for (size_t i = 0; i < lhs.lines.size() - 1; i++) {
      lhs.lines[i].parts.back().append(rhs);
    }
  }
  return lhs;
}

MultiBlock &operator<<(MultiBlock &lhs, const Block &rhs) {
  lhs.blocks.push_back(rhs);
  return lhs;
}

MultiBlock &operator<<(MultiBlock &lhs, const Line &rhs) {
  Block tmp(lhs.indent);
  tmp << rhs;
  lhs << tmp;
  return lhs;
}

MultiBlock &operator<<(MultiBlock &lhs, const MultiBlock &rhs) {
  for (const auto &b : rhs.blocks) {
    lhs << b;
  }
  return lhs;
}

std::string MultiBlock::ToString() const {
  std::stringstream ret;
  for (const auto &b : blocks) {
    ret << b.ToString();
  }
  return ret.str();
}

std::string ToString(const std::vector<Block> &blocks) {
  std::stringstream ret;
  for (const auto &b : blocks) {
    ret << b.ToString();
  }
  return ret.str();
}

std::string Line::ToString() const {
  std::stringstream str;
  for (const auto &p : parts) {
    str << p;
  }
  return str.str();
}
}  // namespace cerata::vhdl
