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
std::shared_ptr<Type> bus_read(const std::shared_ptr<Node> &addr_width = bus_addr_width(),
                               const std::shared_ptr<Node> &len_width = bus_len_width(),
                               const std::shared_ptr<Node> &data_width = bus_data_width());

/// @brief Fletcher bus write request channel
std::shared_ptr<Type> bus_write(const std::shared_ptr<Node> &addr_width = bus_addr_width(),
                                const std::shared_ptr<Node> &len_width = bus_len_width(),
                                const std::shared_ptr<Node> &data_width = bus_data_width());

/// @brief Bus specification
struct BusSpec {
  size_t data_width = 512;
  size_t addr_width = 64;
  size_t len_width = 8;
  size_t burst_step = 1;
  size_t max_burst = 128;

  std::string ToString() const;
  std::string ToShortString() const;
};

bool operator==(const BusSpec &lhs, const BusSpec &rhs);

/// @brief Bus port
struct BusPort : public Port {
  enum class Function {
    READ,
    WRITE
  } function_;

  BusSpec spec_;

  BusPort(Function fun, Port::Dir dir, BusSpec spec, const std::string &name = "")
      : Port(name.empty() ? fun2name(fun) : name, fun2type(fun, spec), dir), function_(fun), spec_(spec) {}

  static std::shared_ptr<BusPort> Make(std::string name, Function fun, Port::Dir dir, BusSpec spec);
  static std::shared_ptr<BusPort> Make(Function fun, Port::Dir dir, BusSpec spec);

  static std::string fun2name(Function fun);
  static std::shared_ptr<Type> fun2type(Function fun, BusSpec spec);

  std::shared_ptr<Object> Copy() const override;

};

std::shared_ptr<Component> BusReadSerializer();
std::shared_ptr<Component> BusReadArbiter(BusSpec spec = BusSpec());

std::shared_ptr<Component> BusWriteSerializer();
std::shared_ptr<Component> BusWriteArbiter();

}  // namespace fletchgen

// Inject a specialization of std::hash for BusSpec
template<>
struct std::hash<fletchgen::BusSpec> {
  size_t operator()(fletchgen::BusSpec const &s) const noexcept {
    return s.data_width + s.addr_width + s.len_width + s.burst_step + s.max_burst;
  }
};
