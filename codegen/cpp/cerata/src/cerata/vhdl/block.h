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
#include <optional>

namespace cerata::vhdl {

/// A line of code.
struct Line {
  Line() = default;
  /// Line constructor.
  explicit Line(const std::string &str) {
    parts.push_back(str);
  }
  /// @brief Return the line as a single string.
  std::string ToString() const;
  /// The parts of the line of code.
  std::vector<std::string> parts;
};

/// A block of code.
struct Block {
  /// @brief Block constructor.
  explicit Block(int indent = 0) : indent(indent) {}
  /// @brief Return the alignment for each line.
  std::vector<size_t> GetAlignments() const;
  /// @brief Return the block in reverse.
  Block &Reverse();

  /**
   * @brief Sort the lines in the block. Supply a character to stop sorting per line after encountering the character.
   * @param c   The character.
   * @return    A reference to the block itself.
   */
  Block &Sort(std::optional<char> c = std::nullopt);

  /// @brief Return this block as a single string.
  std::string ToString() const;

  /// Lines in the blocks.
  std::vector<Line> lines;
  /// Indenting level of the block.
  int indent = 0;
};

/// A structure to hold multiple blocks.
struct MultiBlock {
  /// @brief Multiblock constructor.
  explicit MultiBlock(int indent = 0) : indent(indent) {}
  /// @brief Return this multiblock as a single string.
  std::string ToString() const;
  /// The blocks in this multiblock.
  std::vector<Block> blocks;
  /// Indent level.
  int indent = 0;
};

/// @brief Append a string to the last line part.
Line &operator+=(Line &lhs, const std::string &str); //NOLINT

/// @brief Append a part to a line.
Line &operator<<(Line &lhs, const std::string &str);

/// @brief Append all parts of a line to another line.
Line &operator<<(Line &lhs, const Line &rhs);

/// @brief Append a line to a block
Block &operator<<(Block &lhs, const Line &line);

/// @brief Append the lines of a block to another block
Block &operator<<(Block &lhs, const Block &rhs);

/// @brief Append a string to the last parts of all lines in a block
Block &operator<<(Block &lhs, const std::string &rhs);

/// @brief Append a string to the last parts of all lines in a block, except the last one.
Block &operator<<=(Block &lhs, const std::string &rhs); //NOLINT

/// @brief Prepend a string to every line of a block.
Block &Prepend(const std::string &lhs, Block *rhs, const std::string &sep = "_");

/// @brief Append a block to a multiblock
MultiBlock &operator<<(MultiBlock &lhs, const Block &rhs);

/// @brief Append a multiblock to a multiblock
MultiBlock &operator<<(MultiBlock &lhs, const MultiBlock &rhs);

/// @brief Append a line to a multiblock
MultiBlock &operator<<(MultiBlock &lhs, const Line &rhs);

/// @brief Return a vector of blocks as a single string.
std::string ToString(const std::vector<Block> &blocks);

}  // namespace cerata::vhdl
