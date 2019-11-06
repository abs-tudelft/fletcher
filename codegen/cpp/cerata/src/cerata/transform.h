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

#include <string>
#include <memory>
#include <vector>

#include "cerata/type.h"
#include "cerata/graph.h"

// Helper functions for transformations.

namespace cerata {

/**
 * @brief Get all potential child graphs of a graph.
 * @param top_graph           The top-level graph to inspect.
 * @param graphs_out          A list of graphs to append the output to.
 * @param include_components  Whether to recurse down the components used by any instances in the graph.
 */
void GetAllGraphs(Graph *top_graph, std::vector<Graph *> *graphs_out, bool include_components = false);

/**
 * @brief Get all objects from a component.
 * @param top_component       The top-level component to inspect.
 * @param objects_out         A list of objects to append the output to.
 * @param include_instances   Whether to recurse down the instances in the top-level graph.
 */
void GetAllObjects(Component *top_component, std::vector<Object *> *objects_out, bool include_instances = false);

/**
 * @brief Get all types used in a component, including nested types.
 * @param top_component       The top-level component to inspect.
 * @param types_out           A list of types to append the output to.
 * @param include_instances   Whether to recurse down the instances in the top-level graph.
 */
void GetAllTypes(Component *top_component, std::vector<Type *> *types_out, bool include_instances = false);

}  // namespace cerata
