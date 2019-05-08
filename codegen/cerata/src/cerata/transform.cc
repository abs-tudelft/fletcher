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

#include <string>
#include <memory>

#include "cerata/transform.h"

namespace cerata {

void GetAllComponentsRecursive(std::deque<std::shared_ptr<Component>> *components,
                               const std::shared_ptr<Component> &top_component) {
  if (components == nullptr) {
    throw std::runtime_error("Cannot append to nullptr deque of graphs.");
  }
  // If the top_graph is a Component it can have Instances, apply this function recursively to the components of the
  // instances.
  auto comp = Cast<Component>(top_component);
  if (comp) {
    auto instances = (*comp)->GetAllInstances();
    for (const auto &inst : instances) {
      components->push_back(inst->component);
      GetAllComponentsRecursive(components, inst->component);
    }
  }
}

void GetAllObjectsRecursive(std::deque<std::shared_ptr<Object>> *objects,
                            const std::shared_ptr<Component> &top_component) {
  if (objects == nullptr) {
    throw std::runtime_error("Objects deque is nullptr.");
  }
  // First obtain all components.
  std::deque<std::shared_ptr<Component>> components = {top_component};
  GetAllComponentsRecursive(&components, top_component);

  // Copy all pointers to the objects
  for (const auto &comp : components) {
    auto comp_objs = comp->objects();
    objects->insert(objects->end(), comp_objs.begin(), comp_objs.end());
  }
}

void GetAllObjectTypesRecursive(std::deque<std::shared_ptr<Type>> *types,
                                const std::shared_ptr<Component> &top_component) {
  if (types == nullptr) {
    throw std::runtime_error("Types deque is nullptr.");
  }
  std::deque<std::shared_ptr<Object>> objects;
  GetAllObjectsRecursive(&objects, top_component);

  for (const auto &o : objects) {
    if (o->IsNode()) {
      auto n = *Cast<Node>(o);
      types->push_back(n->type());
    }
    if (o->IsArray()) {
      auto a = *Cast<NodeArray>(o);
      types->push_back(a->type());
    }
  }
}

} // namespace cerata
