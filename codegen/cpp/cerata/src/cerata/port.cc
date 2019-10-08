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

#include "cerata/port.h"

#include <memory>
#include <utility>

namespace cerata {

std::shared_ptr<Port> Port::Make(const std::string &name,
                                 const std::shared_ptr<Type> &type,
                                 Term::Dir dir,
                                 const std::shared_ptr<ClockDomain> &domain) {
  return std::make_shared<Port>(name, type, dir, domain);
}

std::shared_ptr<Port> Port::Make(const std::shared_ptr<Type> &type,
                                 Term::Dir dir,
                                 const std::shared_ptr<ClockDomain> &domain) {
  return std::make_shared<Port>(type->name(), type, dir, domain);
}

std::shared_ptr<Object> Port::Copy() const {
  auto result = std::make_shared<Port>(name(), type_, dir(), domain_);
  result->meta = meta;
  return result;
}

Port::Port(std::string name, std::shared_ptr<Type> type, Term::Dir dir, std::shared_ptr<ClockDomain> domain)
    : NormalNode(std::move(name), Node::NodeID::PORT, std::move(type)), Synchronous(std::move(domain)), Term(dir) {}

Port &Port::InvertDirection() {
  dir_ = Term::Invert(dir_);
  return *this;
}

}  // namespace cerata
