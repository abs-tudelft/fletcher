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
#include <utility>

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

/// Defines function of a bus interface.
enum class BusFunction {
  READ,  ///< Interface reads from memory.
  WRITE  ///< Interface writes to memory.
};

/// @brief Bus specification
struct BusSpec {
  /// Width of data bus.
  uint32_t data_width = 512;
  /// Width of address bus.
  uint32_t addr_width = 64;
  /// Width of burst length field.
  uint32_t len_width = 8;
  /// Minimum burst size.
  uint32_t burst_step = 1;
  /// Maximum burst size.
  uint32_t max_burst = 128;
  /// Bus function.
  BusFunction function = BusFunction::READ;

  /// @brief Return a human-readable version of the bus specification.
  [[nodiscard]] std::string ToString() const;
  /// @brief Return a type name for a Cerata type based on this bus specification.
  [[nodiscard]] std::string ToBusTypeName() const;
};

/// @brief Returns true if bus specifications are equal, false otherwise.
bool operator==(const BusSpec &lhs, const BusSpec &rhs);

/// @brief Fletcher bus type with access mode conveyed through spec.
std::shared_ptr<Type> bus(BusSpec spec = BusSpec());

/// @brief Return a Cerata type for a Fletcher bus read interface.
std::shared_ptr<Type> bus_read(const std::shared_ptr<Node> &addr_width,
                               const std::shared_ptr<Node> &len_width,
                               const std::shared_ptr<Node> &data_width);

/// @brief Return a Cerata type for a Fletcher bus write interface.
std::shared_ptr<Type> bus_write(const std::shared_ptr<Node> &addr_width,
                                const std::shared_ptr<Node> &len_width,
                                const std::shared_ptr<Node> &data_width);

/// A port derived from a BusSpec.
struct BusPort : public Port {
  /// Bus specification.
  BusSpec spec_;
  /// @brief Construct a new port based on a bus specification.
  BusPort(Port::Dir dir,
          BusSpec spec,
          const std::string &name = "",
          std::shared_ptr<ClockDomain> domain = bus_cd())
      : Port(name.empty() ? "bus" : name, bus(spec), dir, std::move(domain)), spec_(spec) {}
  /// @brief Make a new port and return a shared pointer to it.
  static std::shared_ptr<BusPort> Make(std::string name, Port::Dir dir, BusSpec spec);
  /// @brief Make a new port, name it automatically based on the bus specification, and return a shared pointer to it.
  static std::shared_ptr<BusPort> Make(Port::Dir dir, BusSpec spec);
  /// @brief Deep-copy the BusPort.
  std::shared_ptr<Object> Copy() const override;
};

/**
 * @brief Return a Cerata Instance of a BusArbiter.
 * @param spec      The bus specification.
 * @return          A Bus(Read/Write)Arbiter Cerata component model.
 *
 * This model corresponds to either:
 *    [`hardware/interconnect/BusReadArbiterVec.vhd`](https://github.com/johanpel/fletcher/blob/develop/hardware/interconnect/BusReadArbiterVec.vhd)
 * or [`hardware/interconnect/BusWriteArbiterVec.vhd`](https://github.com/johanpel/fletcher/blob/develop/hardware/interconnect/BusWriteArbiterVec.vhd)
 * depending on the function parameter.
 *
 * Changes to the implementation of this component in the HDL source must be reflected in the implementation of this
 * function.
 */
std::unique_ptr<Instance> BusArbiterInstance(BusSpec spec = BusSpec());

/// @brief Return a BusReadSerializer component
std::shared_ptr<Component> BusReadSerializer();

/// @brief Return a BusWriteSerializer component
std::shared_ptr<Component> BusWriteSerializer();

}  // namespace fletchgen

///  Specialization of std::hash for BusSpec
template<>
struct std::hash<fletchgen::BusSpec> {
  /// @brief Hash a BusSpec.
  size_t operator()(fletchgen::BusSpec const &s) const noexcept {
    return s.data_width + s.addr_width + s.len_width + s.burst_step + s.max_burst;
  }
};
