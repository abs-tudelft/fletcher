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

#include <memory>
#include <string>
#include <utility>

#include "cerata/domain.h"
#include "cerata/node.h"
#include "cerata/port.h"
#include "cerata/signal.h"

namespace cerata {

ClockDomain::ClockDomain(std::string name) : Named(std::move(name)) {}

std::shared_ptr<ClockDomain> default_domain() {
  static std::shared_ptr<ClockDomain> result = std::make_shared<ClockDomain>("default");
  return result;
}

std::optional<std::shared_ptr<ClockDomain>> GetDomain(const Node &node) {
  if (node.IsPort()) {
    return node.AsPort()->domain();
  } else if (node.IsSignal()) {
    return node.AsSignal()->domain();
  }
  return std::nullopt;
}

}  // namespace cerata


