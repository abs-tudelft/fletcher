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
#include <deque>

#include "cerata/type.h"
#include "cerata/graph.h"

// Helper functions for transformations.

namespace cerata {

/**
 * @brief Get all components underlying some top-level component.
 * @param components          The deque of components to append to.
 * @param top_component       The top-level component.
 */
void GetAllGraphs(Graph *top_graph, std::deque<Graph *> *graphs_out, bool include_components = false);

/**
 * @brief Get all objects from a component and its sub-components.
 * @param objects             The deque of objects to append to.
 * @param top_component       The top-level component.
 * @param include_instances   Whether to traverse down the child instances of the component.
 */
void GetAllObjects(Component *top_component, std::deque<Object *> *objects_out, bool include_instances = false);

/**
 * @brief Recursively add all types used in a component and its sub-components, including subtypes.
 * @param types               The deque types to append to.
 * @param graph               The top-level component.
 * @param recursive           Whether to traverse down the child instances of the component.
 */
void GetAllTypes(Component *top_component, std::deque<Type *> *types_out, bool include_instances = false);

}  // namespace cerata
