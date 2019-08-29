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

#include <memory>

#include "cerata/pool.h"
#include "cerata/node.h"
#include "cerata/graph.h"

namespace cerata {

/// @brief Template specialization for Type objects.
template<>
std::string Pool<Type>::PoolTypeToString(const Type &object) {
  return object.ToString(true, true);
}

}  // namespace cerata
