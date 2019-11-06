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

#pragma once

#include <vector>
#include <string>
#include <memory>

#include "cerata/node.h"

namespace cerata {

/**
 * @brief A Signal Node.
 *
 * A Signal Node can have a single input and multiple outputs.
 */
class Signal : public NormalNode, public Synchronous {
 public:
  /// @brief Signal constructor.
  Signal(std::string name, std::shared_ptr<Type> type, std::shared_ptr<ClockDomain> domain = default_domain());
  /// @brief Create a copy of this Signal.
  std::shared_ptr<Object> Copy() const override;

  std::string ToString() const override;
};

/// @brief Create a new Signal and return a smart pointer to it.
std::shared_ptr<Signal> signal(const std::string &name,
                               const std::shared_ptr<Type> &type,
                               const std::shared_ptr<ClockDomain> &domain = default_domain());
/// @brief Create a new Signal and return a smart pointer to it. The Signal name is derived from the Type name.
std::shared_ptr<Signal> signal(const std::shared_ptr<Type> &type,
                               const std::shared_ptr<ClockDomain> &domain = default_domain());

}  // namespace cerata
