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

#include "cerata/types.h"
#include "cerata/graphs.h"

// Helper functions for transformations by back-ends.

namespace cerata {

/**
 * @brief Get all components underlying some top-level component.
 * @param components    The deque of components to append to.
 * @param top_component The top-level component.
 */
void GetAllGraphsRecursive(std::deque<std::shared_ptr<Component>> *components,
                           const std::shared_ptr<Component> &top_component);

/**
 * @brief Get all objects from a component and its sub-components.
 * @param objects       The deque of objects to append to.
 * @param top_component The top-level component.
 */
void GetAllObjectsRecursive(std::deque<std::shared_ptr<Object>> *objects,
                            const std::shared_ptr<Component> &top_component);

/**
 * @brief Recursively add all object types used in a component and its sub-components. Does not include subtypes.
 * @param types The deque types to append to.
 * @param graph The top-level component.
 */
void GetAllObjectTypesRecursive(std::deque<std::shared_ptr<Type>> *types,
                                const std::shared_ptr<Component> &top_component);

/**
 * @brief Recursively add all types used in a component and its sub-components, including subtypes.
 * @param types The deque types to append to.
 * @param graph The top-level component.
 */
void GetAllTypesRecursive(std::deque<Type *> *types,
                          const std::shared_ptr<Component> &top_component);

} // namespace cerata
