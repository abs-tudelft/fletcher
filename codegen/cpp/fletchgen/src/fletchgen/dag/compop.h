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

#include "fletchgen/dag/dag.h"

#pragma once

namespace fletchgen::dag {

// Comparison operations:

/// @brief Comparison of primitive t0 with primitive t1.
Transform CompOp(const PrimRef &t0, const std::string &op, const PrimRef &t1);
/// @brief Element-wise comparison of t0 elements with primitive t1.
Transform CompOp(const ListRef &t0, const std::string &op, const PrimRef &t1);
/// @brief Element-wise comparison of t0 elements with t1 elements.
Transform CompOp(const ListRef &t0, const std::string &op, const ListRef &t1);
/// @brief Element-wise comparison of t0 elements with primitive t1.
Transform CompOp(const StructRef &t0, const std::string &op, const PrimRef &t1);
/// @brief Element-wise comparison of every column element of t0, with every element at the same row index of t1.
Transform CompOp(const StructRef &t0, const std::string &op, const ListRef &t1);
/// @brief Element-wise comparison of t0 elements with t1 elements.
Transform CompOp(const StructRef &t0, const std::string &op, const StructRef &t1);

} // namespace fletchgen::dag
