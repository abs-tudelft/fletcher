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
#include <cerata/api.h>

#include "fletchgen/basic_types.h"

namespace fletchgen {

using cerata::Component;
using cerata::Instance;
using cerata::Node;
using cerata::Literal;
using cerata::Port;
using cerata::Parameter;
using cerata::PortArray;
using cerata::integer;
using cerata::Cast;

// Bus channel types:

/// @brief Fletcher bus read request channel
std::shared_ptr<Type> bus_read_request(const std::shared_ptr<Node> &addr_width = bus_addr_width(),
                                       const std::shared_ptr<Node> &len_width = bus_len_width());
/// @brief Fletcher bus read data channel
std::shared_ptr<Type> bus_read_data(const std::shared_ptr<Node> &width = bus_data_width());

/// @brief Fletcher bus write request channel
std::shared_ptr<Type> bus_write_request(const std::shared_ptr<Node> &addr_width = bus_addr_width(),
                                        const std::shared_ptr<Node> &len_width = bus_len_width());

/// @brief Fletcher bus write data channel
std::shared_ptr<Type> bus_write_data(const std::shared_ptr<Node> &width = bus_data_width());

// Bus channel
struct BusChannel : public Port {
  enum class Function {
    READ_REQ,
    READ_DAT,
    WRITE_REQ,
    WRITE_DAT
  } function;

  BusChannel(Function fun, Port::Dir dir, size_t data_width = 512, size_t addr_width = 64, size_t len_width = 8)
      : Port(fun2name(fun), fun2type(fun, data_width, addr_width, len_width), dir), function(fun) {}

  static std::string fun2name(Function fun);
  static std::shared_ptr<Type> fun2type(Function fun, size_t data_width, size_t addr_width, size_t len_width);
};

std::shared_ptr<Component> BusReadSerializer();
std::shared_ptr<Component> BusReadArbiter();

std::shared_ptr<Component> BusWriteSerializer();
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

  Artery(const std::string &prefix,
         std::shared_ptr<Node> address_width,
         std::shared_ptr<Node> master_width,
         std::deque<std::shared_ptr<Node>> slave_widths);

  static std::shared_ptr<Artery> Make(std::string prefix,
                                      std::shared_ptr<Node> address_width,
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
  std::shared_ptr<PortArray> read_data(const std::shared_ptr<Node> &width);
  std::shared_ptr<PortArray> read_request(const std::shared_ptr<Node> &width);

  template<int W>
  std::shared_ptr<PortArray> read_data() {
    return read_data(cerata::intl<W>());
  }
};

}  // namespace fletchgen
