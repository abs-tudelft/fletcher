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

#include <vector>
#include <string>
#include <algorithm>

namespace cerata::vhdl {

struct Line {
  Line()=default;
  explicit Line(const std::string &str) {
    parts.push_back(str);
  }
  std::vector<std::string> parts;
};

struct Block {
  explicit Block(int indent=0) : indent(indent) {}
  std::vector<Line> lines;
  std::vector<size_t> GetAlignments() const;
  void reverse() {
    std::reverse(lines.begin(), lines.end());
  }
  std::string str() const;
  int indent = 0;
};

struct MultiBlock {
  explicit MultiBlock(int indent=0) : indent(indent) {}
  std::vector<Block> blocks;
  std::string ToString() const;
  int indent = 0;
};

/// @brief Append a string to the last line part.
Line &operator+=(Line &lhs, const std::string &str);

/// @brief Append a part to a line.
Line &operator<<(Line &lhs, const std::string &str);

/// @brief Append all parts of a line to another line.
Line &operator<<(Line &lhs, const Line& rhs);

/// @brief Append a line to a block
Block &operator<<(Block &lhs, const Line &line);

/// @brief Append the lines of a block to another block
Block &operator<<(Block &lhs, const Block &rhs);

/// @brief Append a string to the last parts of all lines in a block
Block &operator<<(Block &lhs, const std::string &rhs);

/// @brief Append a string to the last parts of all lines in a block, except the last one.
Block &operator<<=(Block& lhs, const std::string &rhs);

/// @brief Prepend a string to every line of a block.
Block &Prepend(const std::string &lhs, Block* rhs, std::string sep = "_");

/// @brief Append a block to a multiblock
MultiBlock &operator<<(MultiBlock &lhs, const Block &rhs);

/// @brief Append a multiblock to a multiblock
MultiBlock &operator<<(MultiBlock &lhs, const MultiBlock &rhs);

/// @brief Append a line to a multiblock
MultiBlock &operator<<(MultiBlock &lhs, const Line &rhs);

std::string ToString(std::vector<Block> blocks);

}  // namespace cerata::vhdl
