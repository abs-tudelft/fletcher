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

#include <vector>
#include <memory>

#include "cerata/pool.h"
#include "cerata/node.h"
#include "cerata/graph.h"

namespace cerata {

void TypePool::Add(const std::shared_ptr<Type> &type) {
  // Check for potential duplicate
  for (const auto &existing_type : types_) {
    if (existing_type->name() == type->name()) {
      CERATA_LOG(FATAL, "Type " + type->ToString(true, true) + " already exists in type pool.");
    }
  }
  types_.push_back(type);
}

std::optional<Type *> TypePool::Get(const std::string &name) {
  // Check for potential duplicate
  for (const auto &existing_type : types_) {
    if (existing_type->name() == name) {
      return existing_type.get();
    }
  }
  return std::nullopt;
}

void TypePool::Clear() {
  types_.clear();
}

void ComponentPool::Add(const std::shared_ptr<Component> &comp) {
  // Check for potential duplicate
  for (const auto &existing_component : components_) {
    if (existing_component->name() == comp->name()) {
      CERATA_LOG(FATAL, "Component " + comp->name() + " already exists in component pool.");
    }
  }
  components_.push_back(comp);
}

std::optional<Component *> ComponentPool::Get(const std::string &name) {
  // Check for potential duplicate
  for (const auto &existing_component : components_) {
    if (existing_component->name() == name) {
      return existing_component.get();
    }
  }
  return std::nullopt;
}

void ComponentPool::Clear() {
  components_.clear();
}

void NodePool::Add(const std::shared_ptr<Node> &node) {
  nodes_.push_back(node);
}

void NodePool::Clear() {
  nodes_.clear();
}

}  // namespace cerata
