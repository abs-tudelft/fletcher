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

// Binary operators:

/// @brief Binary operation of primitive t0 with primitive t1.
Graph BinOp(const TypeRef &t, const std::string &op);

// Unary operators:

Graph inverse(const PrimRef &t);
Graph abs(const PrimRef &t);
Graph clip(const PrimRef &t);

// Trigonometry:
Graph sIn(const PrimRef &t);
Graph cos(const PrimRef &t);
Graph tan(const PrimRef &t);

}  // namespace dag::transform
