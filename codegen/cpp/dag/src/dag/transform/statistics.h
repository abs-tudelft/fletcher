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

#include <string>
#include <vector>

#include "dag/dag.h"

#pragma once

namespace dag::transform {

/// @brief Return whether all boolean primitive elements are true.
Graph All(const TypeRef &t);
/// @brief Return whether any boolean primitive element is true.
Graph Any(const TypeRef &t);

Graph Min(const ListRef &t);
Graph Max(const ListRef &t);
Graph Sum(const ListRef &type);
Graph Prod(const ListRef &type);

Graph Mean(const ListRef &t);
Graph Median(const ListRef &t);
Graph Std(const ListRef &t);
Graph Mad(const ListRef &t);

}  // namespace dag::transform
