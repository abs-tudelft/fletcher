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
#include <memory>
#include <utility>

#include "cerata/signal.h"

namespace cerata {

Signal::Signal(std::string name, std::shared_ptr<Type> type, std::shared_ptr<ClockDomain> domain)
    : NormalNode(std::move(name), Node::NodeID::SIGNAL, std::move(type)), Synchronous(std::move(domain)) {}

std::shared_ptr<Object> Signal::Copy() const {
  auto result = signal(this->name(), this->type_, this->domain_);
  result->meta = this->meta;
  return result;
}

std::string Signal::ToString() const {
  return name() + ":" + type()->name();
}

std::shared_ptr<Signal> signal(const std::string &name,
                               const std::shared_ptr<Type> &type,
                               const std::shared_ptr<ClockDomain> &domain) {
  auto ret = std::make_shared<Signal>(name, type, domain);
  return ret;
}

std::shared_ptr<Signal> signal(const std::shared_ptr<Type> &type, const std::shared_ptr<ClockDomain> &domain) {
  auto ret = std::make_shared<Signal>(type->name() + "_signal", type, domain);
  return ret;
}

}  // namespace cerata
