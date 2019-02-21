#include <utility>

#include <utility>

#include <utility>

#include <utility>

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

#pragma once

#include <memory>

#include "cerata/graphs.h"
#include "cerata/types.h"
#include "cerata/nodes.h"

#include "fletchgen/basic_types.h"

namespace fletchgen {

using cerata::Component;
using cerata::Instance;
using cerata::Node;
using cerata::Port;
using cerata::Parameter;
using cerata::ArrayPort;
using cerata::integer;
using cerata::Cast;

std::shared_ptr<Component> BusReadArbiter();
std::shared_ptr<Component> BusWriteArbiter();

/**
 * @brief A component used to route multiple bus request and data channels onto a single master port.
 */
struct Artery : Component {
  /// The address width of all request ports.
  std::shared_ptr<Node> address_width_;
  /// The width of the master port.
  std::shared_ptr<Node> master_width_;
  /// The widths of all slave port arrays.
  std::deque<std::shared_ptr<Node>> slave_widths_;

  Artery(std::shared_ptr<Node> address_width,
         std::shared_ptr<Node> master_width,
         std::deque<std::shared_ptr<Node>> slave_widths);

  static std::shared_ptr<Artery> Make(std::shared_ptr<Node> address_width,
                                      std::shared_ptr<Node> master_width,
                                      std::deque<std::shared_ptr<Node>> slave_widths);
};

/**
 * @brief An instance of an Artery component.
 */
struct ArteryInstance : Instance {
  explicit ArteryInstance(std::string name, const std::shared_ptr<Artery> &comp)
      : Instance(std::move(name), std::dynamic_pointer_cast<Component>(comp)) {}
  static std::unique_ptr<ArteryInstance> Make(const std::shared_ptr<Artery> &comp) {
    return std::make_unique<ArteryInstance>(comp->name() + "_inst", comp);
  }
  std::shared_ptr<ArrayPort> read_data(const std::shared_ptr<Node> &width);
  std::shared_ptr<ArrayPort> read_request(const std::shared_ptr<Node> &width);

  template<int W>
  std::shared_ptr<ArrayPort> read_data() {
    return read_data(cerata::intl<W>());
  }
};

}  // namespace fletchgen
