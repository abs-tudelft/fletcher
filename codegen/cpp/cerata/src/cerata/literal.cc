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

#include "cerata/literal.h"
#include "cerata/pool.h"

namespace cerata {

std::string Literal::ToString() const {
  if (storage_type_ == StorageType::BOOL) {
    return std::to_string(Bool_val_);
  } else if (storage_type_ == StorageType::STRING) {
    return String_val_;
  } else {
    return std::to_string(Int_val_);
  }
}

#ifndef LITERAL_IMPL_FACTORY
#define LITERAL_IMPL_FACTORY(NAME, BASETYPE, IDNAME, TYPENAME)                                                       \
  Literal::Literal(std::string name, const std::shared_ptr<Type> &type, TYPENAME value) \
    : MultiOutputNode(std::move(name), Node::NodeID::LITERAL, type), \
      storage_type_(StorageType::IDNAME), \
      NAME##_val_(std::move(value)) {} \
      \
  std::shared_ptr<Literal> Literal::Make##NAME(TYPENAME value) {  \
  std::stringstream str;  \
  str << #NAME << "_" << value; \
  auto ret = std::make_shared<Literal>(str.str(), BASETYPE(), value); \
  return ret; \
}
#endif

LITERAL_IMPL_FACTORY(String, string, STRING, std::string)
LITERAL_IMPL_FACTORY(Bool, boolean, BOOL, bool)
LITERAL_IMPL_FACTORY(Int, integer, INT, int)

std::shared_ptr<Object> Literal::Copy() const {
  switch (storage_type_) {
    default:return strl(String_val_);
    case StorageType::BOOL:return booll(Bool_val_);
    case StorageType::INT:return intl(Int_val_);
  }
}

std::shared_ptr<Edge> Literal::AddSource(Node *source) {
  CERATA_LOG(FATAL, "Cannot drive a literal node.");
  return nullptr;
}

}  // namespace cerata
