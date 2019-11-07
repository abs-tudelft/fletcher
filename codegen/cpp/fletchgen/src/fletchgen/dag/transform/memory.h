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

namespace fletchgen::dag::transform {

/// @brief Create a transformation that sources a stream from memory.
Transform Source(const std::string &name, const TypeRef &output);
/// @brief Create a transformation that sources a stream from memory, and desynchronizes all struct fields.
Transform DesyncedSource(const std::string &name, const StructRef &output);

/// @brief Create a transformation that sinks a stream to memory.
Transform Sink(const std::string &name, const TypeRef &input);
/// @brief Create a transformation that sinks a stream to memory, and desynchronizes all struct fields.
Transform DesyncedSink(const std::string &name, const StructRef &input);

}  // namespace fletchgen::dag::transform
