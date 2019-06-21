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

void NodePool::Add(const std::shared_ptr<Node> &node) {
  nodes_.push_back(node);
}

void NodePool::Clear() {
  nodes_.clear();
}

void ComponentPool::Add(const std::shared_ptr<Component> &comp) {
  // Check for potential duplicate
  for (const auto &existing_component : components_) {
    if (existing_component->name() == comp->name()) {
      throw std::runtime_error("Component " + comp->name() + " already exists in component pool.");
    }
  }
  components_.push_back(comp);
}

void ComponentPool::Clear() {
  components_.clear();
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

}  // namespace cerata
