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

#include "./types.h"

#include <string>

#include "./nodes.h"

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

std::shared_ptr<Type> Stream::Make(std::string name, std::shared_ptr<Type> element_type, int epc) {
  return std::make_shared<Stream>(name, element_type, "", epc);
}

std::shared_ptr<Type> Stream::Make(std::string name,
                                   std::shared_ptr<Type> element_type,
                                   std::string element_name,
                                   int epc) {
  return std::make_shared<Stream>(name, element_type, element_name, epc);
}

std::deque<std::shared_ptr<Type>> FlattenStreams(const std::shared_ptr<Type> &type) {
  std::deque<std::shared_ptr<Type>> ret;
  if (type->Is(Type::STREAM)) {
    ret.push_back(type);
    auto dt = Cast<Stream>(type)->element_type();
    auto children = FlattenStreams(dt);
    ret.insert(ret.end(), children.begin(), children.end());
  } else if (type->Is(Type::RECORD)) {
    auto rdt = Cast<Record>(type);
    for (const auto &rf : rdt->fields()) {
      auto children = FlattenStreams(rf->type());
      ret.insert(ret.end(), children.begin(), children.end());
    }
  }
  return ret;
}

bool IsNested(const std::shared_ptr<Type> &type) {
  return type->Is(Type::STREAM) || type->Is(Type::RECORD);
}

#define TOSTRING_FACTORY(TYPE)     \
  template<>                       \
    std::string ToString<TYPE>() { \
    return #TYPE;                  \
  }

TOSTRING_FACTORY(Clock)
TOSTRING_FACTORY(Reset)
TOSTRING_FACTORY(Bit)
TOSTRING_FACTORY(Vector)
TOSTRING_FACTORY(Record)
TOSTRING_FACTORY(Stream)
TOSTRING_FACTORY(Natural)
TOSTRING_FACTORY(String)
TOSTRING_FACTORY(Boolean)

}  // namespace fletchgen
