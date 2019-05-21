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
#include "cerata/types.h"

namespace cerata {

void GetAllGraphsRecursive(std::deque<Graph *> *graphs,
                           const std::shared_ptr<Graph> &top_graph) {
  if (graphs == nullptr) {
    throw std::runtime_error("Cannot append to nullptr deque of graphs.");
  }
  // If the top_graph is a Component it can have Instances, apply this function recursively to the components of the
  // instances.
  auto comp = Cast<Component>(top_graph);
  if (comp) {
    // Insert all instances
    auto instances = (*comp)->GetAllInstances();
    graphs->insert(graphs->end(), instances.begin(), instances.end());

    // Iterate over all instance components
    for (const auto &inst : instances) {
      graphs->push_back(inst->component.get());
      GetAllGraphsRecursive(graphs, inst->component);
    }
  }
}

void GetAllObjectsRecursive(std::deque<std::shared_ptr<Object>> *objects,
                            const std::shared_ptr<Component> &top_component) {
  if (objects == nullptr) {
    throw std::runtime_error("Objects deque is nullptr.");
  }
  // First obtain all components.
  std::deque<Graph *> graphs = {top_component.get()};
  GetAllGraphsRecursive(&graphs, top_component);

  // Copy all pointers to the objects
  for (const auto &graph : graphs) {
    auto comp_objs = graph->objects();
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

void GetAllTypesRecursive(std::deque<Type *> *types,
                          const std::shared_ptr<Component> &top_component) {
  if (types == nullptr) {
    throw std::runtime_error("Types deque is nullptr.");
  }
  std::deque<std::shared_ptr<Object>> objects;
  GetAllObjectsRecursive(&objects, top_component);

  for (const auto &o : objects) {
    std::deque<FlatType> ft;
    if (o->IsNode()) {
      auto n = *Cast<Node>(o);
      ft = Flatten(n->type().get());
    } else if (o->IsArray()) {
      auto a = *Cast<NodeArray>(o);
      ft = Flatten(a->type().get());
    }
    for (const auto &f : ft) {
      // Drop the const qualifier, because this function is probably used to transform the type.
      auto t = const_cast<Type *>(f.type_);
      types->push_back(t);
    }
  }
  // Filter out duplicates.
  auto i = std::unique(types->begin(), types->end());
  types->resize(std::distance(types->begin(), i));
}

} // namespace cerata
