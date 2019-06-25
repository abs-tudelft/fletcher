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

#include <cerata/api.h>

#include <memory>
#include <string>

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
using cerata::Type;

// Bus channel classes:

enum class BusFunction {
  READ,
  WRITE
};

/// @brief Bus specification
struct BusSpec {
  size_t data_width = 512;
  size_t addr_width = 64;
  size_t len_width = 8;
  size_t burst_step = 1;
  size_t max_burst = 128;
  BusFunction function = BusFunction::READ;

  std::string ToString() const;
  std::string ToBusTypeName() const;
};

bool operator==(const BusSpec &lhs, const BusSpec &rhs);

/// @brief Fletcher bus type with access mode conveyed through spec.
std::shared_ptr<Type> bus(BusSpec spec = BusSpec());
std::shared_ptr<Type> bus_read(const std::shared_ptr<Node> &addr_width,
                               const std::shared_ptr<Node> &len_width,
                               const std::shared_ptr<Node> &data_width);
std::shared_ptr<Type> bus_write(const std::shared_ptr<Node> &addr_width,
                                const std::shared_ptr<Node> &len_width,
                                const std::shared_ptr<Node> &data_width);


/// @brief Bus port
struct BusPort : public Port {
  BusSpec spec_;
  BusPort(Port::Dir dir, BusSpec spec, const std::string &name = "")
      : Port(name.empty() ? "bus" : name, bus(spec), dir), spec_(spec) {}
  static std::shared_ptr<BusPort> Make(std::string name, Port::Dir dir, BusSpec spec);
  static std::shared_ptr<BusPort> Make(Port::Dir dir, BusSpec spec);
  std::shared_ptr<Object> Copy() const override;
};

/**
 * @brief Return a Cerata Instance of a BusArbiter.
 *
 * This model corresponds to either:
 *    [`hardware/interconnect/BusReadArbiterVec.vhd`](https://github.com/johanpel/fletcher/blob/develop/hardware/interconnect/BusReadArbiterVec.vhd)
 * or [`hardware/interconnect/BusWriteArbiterVec.vhd`](https://github.com/johanpel/fletcher/blob/develop/hardware/interconnect/BusWriteArbiterVec.vhd)
 * depending on the function parameter.
 *
 * Changes to the implementation of this component in the HDL source must be reflected in the implementation of this
 * function.
 *
 * @param function  The function of the arbiter, either BusPort::Function::READ or BusPort::Function::WRITE.
 * @param spec      The bus specification.
 * @return          A Bus(Read/Write)Arbiter Cerata component model.
 */
std::unique_ptr<Instance> BusArbiterInstance(BusSpec spec = BusSpec());

std::shared_ptr<Component> BusReadSerializer();
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
