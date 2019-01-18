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

#include "types.h"
#include "nodes.h"

namespace fletchgen {

bool Type::Is(Type::ID type_id) {
  return type_id == id;
}

Vector::Vector(std::string name, std::shared_ptr<Node> width)
    : Type(std::move(name), Type::VECTOR) {
  // Check if width is parameter or literal node
  if (!(width->IsParameter() || width->IsLiteral())) {
    throw std::runtime_error("Vector width can only be parameter or literal node.");
  } else {
    width_ = std::move(width);
  }
}
}  // namespace fletchgen
