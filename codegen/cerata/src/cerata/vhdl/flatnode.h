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

#include <memory>
#include <deque>
#include <string>
#include <utility>

#include "cerata/nodes.h"
#include "cerata/vhdl/identifier.h"

namespace cerata {
namespace vhdl {

/// @brief Structure to get flattened list of VHDL identifiers out of a Node with potentially nested type
struct FlatNode {
  /// @brief The Node from which this structure is derived.
  const std::shared_ptr<Node> node_;
  /// @brief An (Identifier, Type) pair.
  std::deque<std::pair<Identifier, std::shared_ptr<Type>>> tuples_;
  /// @brief FlatNode constructor
  explicit FlatNode(std::shared_ptr<Node> node);

  /// @brief Flatten a Record type and prefix all resulting identifiers.
  void Flatten(const Identifier &prefix, const std::shared_ptr<Record> &record);

  /// @brief Flatten a Stream type and prefix all resulting identifiers.
  void Flatten(const Identifier &prefix, const std::shared_ptr<Stream> &stream);

  /// @brief Flatten a generic type and prefix all resulting identifiers.
  void Flatten(const Identifier &prefix, const std::shared_ptr<Type> &type);

  std::string ToString() const;

  /// @brief Get all tuples of this FlatNode
  std::deque<std::pair<Identifier, std::shared_ptr<Type>>> pairs() const;

  /// @brief Get tuple i of this FlatNode
  std::pair<Identifier, std::shared_ptr<Type>> pair(size_t i) const;

  /// @brief Get the number of tuples of this FlatNode
  size_t size();
};

std::shared_ptr<Node> WidthOf(const FlatNode &a, const std::deque<FlatNode> &others, size_t tuple_index);

}  // namespace vhdl
}  // namespace cerata
