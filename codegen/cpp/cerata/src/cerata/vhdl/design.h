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
#include <utility>

#include "cerata/graph.h"
#include "cerata/vhdl/vhdl.h"
#include "cerata/vhdl/block.h"
#include "cerata/vhdl/defaults.h"

namespace cerata::vhdl {

/// A VHDL design that can generate code for a single file.
struct Design {
  /// The component for this design file.
  Component *component_;
  /// A potential copyright notice to place in the header.
  std::string notice_;
  /// Libraries to place after the header.
  std::string libs_;

  /// @brief Design constructor.
  explicit Design(Component *component, std::string notice = "", std::string header = DEFAULT_LIBS)
      : component_(component), notice_(std::move(notice)), libs_(std::move(header)) {}

  /// @brief Design constructor.
  explicit Design(const std::shared_ptr<Component> &component,
                  std::string notice = "",
                  std::string header = DEFAULT_LIBS)
      : Design(component.get(), std::move(notice), std::move(header)) {}

  /// @brief Generate the design VHDL code.
  MultiBlock Generate();
};

}  // namespace cerata::vhdl
