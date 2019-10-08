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

#include <memory>
#include <string>

#include "cerata/utils.h"

namespace cerata {

class Node;

/**
 * @brief A clock domain
 *
 * Placeholder for automatically generated clock domain crossing support
 */
struct ClockDomain : public Named {
  /// @brief Clock domain constructor
  explicit ClockDomain(std::string name);
  /// @brief Create a new clock domain and return a shared pointer to it.
  static std::shared_ptr<ClockDomain> Make(const std::string &name) { return std::make_shared<ClockDomain>(name); }
  // TODO(johanpel): add other properties
};

/// @brief Return a static default clock domain to be used in the whole design.
std::shared_ptr<ClockDomain> default_domain();

/// @brief Return the clock domain of a node, if it has one.
std::optional<std::shared_ptr<ClockDomain>> GetDomain(const Node& node);

}  // namespace cerata
