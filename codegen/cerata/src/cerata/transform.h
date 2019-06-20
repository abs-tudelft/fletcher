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

#include "cerata/type.h"
#include "cerata/graph.h"

// Helper functions for transformations by back-ends.

namespace cerata {

/**
 * @brief Get all components underlying some top-level component.
 * @param components    The deque of components to append to.
 * @param top_component The top-level component.
 */
void GetAllGraphsRecursive(Graph *top_graph, std::deque<Graph *> *graphs_out);

/**
 * @brief Get all objects from a component and its sub-components.
 * @param objects       The deque of objects to append to.
 * @param top_component The top-level component.
 */
void GetAllObjectsRecursive(Component *top_component, std::deque<Object *> *objects_out);

/**
 * @brief Recursively add all object types used in a component and its sub-components. Does not include subtypes.
 * @param types The deque types to append to.
 * @param graph The top-level component.
 */
void GetAllObjectTypesRecursive(Component *top_component, std::deque<Type *> *types_out);

/**
 * @brief Recursively add all types used in a component and its sub-components, including subtypes.
 * @param types The deque types to append to.
 * @param graph The top-level component.
 */
void GetAllTypesRecursive(Component *top_component, std::deque<Type *> *types_out);

} // namespace cerata
