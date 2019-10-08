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

#include <deque>

#include "cerata/graph.h"
#include "cerata/type.h"
#include "cerata/object.h"
#include "cerata/node.h"
#include "cerata/node_array.h"

namespace cerata {

void GetAllGraphs(Graph *top_graph, std::deque<Graph *> *graphs_out, bool include_components) {
  // Insert this graph
  graphs_out->push_back(top_graph);

  // If this is a component, it may have child graphs.
  if (top_graph->IsComponent()) {
    // Obtain children, that must always be instances.
    auto comp = dynamic_cast<Component *>(top_graph);
    auto instances = comp->children();
    graphs_out->insert(graphs_out->end(), instances.begin(), instances.end());

    // Recursively add instance components if required.
    if (include_components) {
      for (const auto &instance : instances) {
        Component *instance_component = instance->component();
        GetAllGraphs(instance_component, graphs_out);
      }
    }
  }
}

void GetAllObjects(Component *top_component, std::deque<Object *> *objects, bool include_instances) {
  std::deque<Graph *> graphs;

  if (include_instances) {
    GetAllGraphs(top_component, &graphs, include_instances);
  }
  // Add all pointers to the objects of the subgraphs
  for (const auto &graph : graphs) {
    auto comp_objs = graph->objects();
    objects->insert(objects->end(), comp_objs.begin(), comp_objs.end());
  }
}

void GetAllTypes(Component *top_component, std::deque<Type *> *types, bool include_instances) {
  std::deque<Object *> objects;
  GetAllObjects(top_component, &objects, include_instances);

  for (const auto &o : objects) {
    if (o->IsNode()) {
      auto *n = dynamic_cast<Node *>(o);
      types->push_back(n->type());
    } else if (o->IsArray()) {
      auto *a = dynamic_cast<NodeArray *>(o);
      types->push_back(a->type());
    }
  }
  // Filter out duplicates.
  auto i = std::unique(types->begin(), types->end());
  types->resize(std::distance(types->begin(), i));
}

}  // namespace cerata
