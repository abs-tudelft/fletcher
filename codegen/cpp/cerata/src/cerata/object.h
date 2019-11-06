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

#pragma once

#include <utility>
#include <string>
#include <memory>
#include <vector>
#include <unordered_map>

#include "cerata/utils.h"

namespace cerata {

class Node;
class NodeArray;
class PortArray;
class Port;
class Graph;

/// A Cerata Object on a graph.
class Object : public Named {
 public:
  /// Object type ID to conveniently cast the object during run-time.
  enum ID {
    NODE,   ///< Node object.
    ARRAY   ///< Array object.
  };

  /**
   * @brief Cerata object constructor.
   * @param name  The name of the object.
   * @param id    The type ID of the object.
   */
  explicit Object(std::string name, ID id) : Named(std::move(name)), obj_id_(id) {}

  /// @brief Return the object ID of this object.
  ID obj_id() const { return obj_id_; }
  /// @brief Return true if this object is a node.
  bool IsNode() const { return obj_id_ == NODE; }
  /// @brief Return true if this object is an array.
  bool IsArray() const { return obj_id_ == ARRAY; }

  /// @brief Set the parent graph of this object.
  virtual void SetParent(Graph *parent);
  /// @brief Return the parent graph of this object, if any. Returns empty option otherwise.
  virtual std::optional<Graph *> parent() const;
  /// @brief Deep-copy the object.
  virtual std::shared_ptr<Object> Copy() const = 0;

  /// @brief Append all objects that this object owns to the output.
  virtual void AppendReferences(std::vector<Object *> *out) const = 0;

  /// @brief KV storage for metadata of tools or specific backend implementations
  std::unordered_map<std::string, std::string> meta;

 protected:
  /// The object type ID.
  ID obj_id_;
  /// An optional parent Graph to which this Object belongs. Initially no value.
  std::optional<Graph *> parent_ = {};
};

}  // namespace cerata
