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

#include "cerata/transform.h"

#include <string>
#include <memory>
#include <deque>

#include "cerata/graph.h"
#include "cerata/type.h"
#include "cerata/object.h"
#include "cerata/node.h"
#include "cerata/node_array.h"

namespace cerata {

void GetAllGraphsRecursive(Graph *top_graph, std::deque<Graph *> *graphs_out) {
  // If the top_graph is a Component it can have Instances, apply this function recursively to the components of these
  // instances.
  if (top_graph->IsComponent()) {
    auto comp = dynamic_cast<Component *>(top_graph);
    // Insert all instances
    auto instances = comp->children();
    graphs_out->insert(graphs_out->end(), instances.begin(), instances.end());

    // Iterate over all instance components
    for (const auto &inst : instances) {
      Component* inst_component = inst->component();
      // Push back its component
      graphs_out->push_back(inst_component);
      GetAllGraphsRecursive(inst_component, graphs_out);
    }
  }
}

void GetAllObjectsRecursive(Component *top_component, std::deque<Object *> *objects) {
  if (objects == nullptr) {
    throw std::runtime_error("Objects deque is nullptr.");
  }
  // Add all objects of the top component
  auto top_objects = top_component->objects();
  objects->insert(objects->end(), top_objects.begin(), top_objects.end());

  // Obtain all subgraphs
  std::deque<Graph *> graphs;
  GetAllGraphsRecursive(top_component, &graphs);

  // Add all pointers to the objects of the subgraphs
  for (const auto &graph : graphs) {
    auto comp_objs = graph->objects();
    objects->insert(objects->end(), comp_objs.begin(), comp_objs.end());
  }
}

void GetAllObjectTypesRecursive(Component *top_component, std::deque<Type *> *types) {
  if (types == nullptr) {
    throw std::runtime_error("Types deque is nullptr.");
  }
  std::deque<Object *> objects;
  GetAllObjectsRecursive(top_component, &objects);

  for (const auto &o : objects) {
    if (o->IsNode()) {
      auto node = dynamic_cast<Node *>(o);
      types->push_back(node->type());
    }
    if (o->IsArray()) {
      auto array = dynamic_cast<NodeArray *>(o);
      types->push_back(array->type());
    }
  }
}

void GetAllTypesRecursive(Component *top_component, std::deque<Type *> *types) {
  if (types == nullptr) {
    throw std::runtime_error("Types deque is nullptr.");
  }
  std::deque<Object *> objects;
  GetAllObjectsRecursive(top_component, &objects);

  for (const auto &o : objects) {
    std::deque<FlatType> ft;
    if (o->IsNode()) {
      auto n = *Cast<Node>(o);
      ft = Flatten(n->type());
    } else if (o->IsArray()) {
      auto a = *Cast<NodeArray>(o);
      ft = Flatten(a->type());
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
