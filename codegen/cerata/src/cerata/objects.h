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
#include <memory>

#include "cerata/utils.h"

namespace cerata {

class Node;
class NodeArray;
class PortArray;
struct Port;
struct Graph;

class Object : public Named {
 public:
  enum ID {
    NODE,
    ARRAY
  } id;
  explicit Object(std::string name, ID id) : Named(std::move(name)), id(id) {}
  virtual ~Object() = default;

  void SetParent(const Graph *parent) {
    if (parent != nullptr) { parent_ = parent; }
    else { throw std::runtime_error("Parent cannot be nullptr."); }
  }
  inline std::optional<const Graph *> parent() { return parent_; }

  virtual std::shared_ptr<Object> Copy() const = 0;

 protected:
  /// An optional parent Graph to which this Node belongs. Initially no value.
  std::optional<const Graph *> parent_ = {};
};

/**
 * @brief Cast an Object to some (typically) less generic Object type T.
 * @tparam T    The new Node type.
 * @param obj   The Node to cast.
 * @return      Optionally, the Node casted to T, if successful.
 */
template<typename T>
std::optional<std::shared_ptr<T>> Cast(const std::shared_ptr<Object> &obj) {
  auto result = std::dynamic_pointer_cast<T>(obj);
  if (result != nullptr) {
    return result;
  } else {
    return {};
  }
}

template<typename T>
Object::ID id_of() {
  // do some c++ magic to make this static assert fail if its not a node or an array
  throw std::runtime_error("Nope");
}

template<>
Object::ID id_of<Node>();
template<>
Object::ID id_of<Port>();
template<>
Object::ID id_of<NodeArray>();
template<>
Object::ID id_of<PortArray>();

}  // cerata;
