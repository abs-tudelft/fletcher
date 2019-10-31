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

#include <cerata/api.h>

#include <memory>
#include <string>
#include <utility>
#include <vector>

#include "fletchgen/basic_types.h"

namespace fletchgen {

using cerata::Instance;
using cerata::Component;
using cerata::Port;
using cerata::intl;
using cerata::Object;

// Bus channel constructs.
PARAM_DECL_FACTORY(bus_addr_width, 64)
PARAM_DECL_FACTORY(bus_data_width, 512)
PARAM_DECL_FACTORY(bus_len_width, 8)
PARAM_DECL_FACTORY(bus_burst_step_len, 4)
PARAM_DECL_FACTORY(bus_burst_max_len, 16)

/// Defines function of a bus interface (read/write).
enum class BusFunction {
  READ,  ///< Interface reads from memory.
  WRITE  ///< Interface writes to memory.
};

/// Holds bus interface dimensions.
struct BusDim {
  uint32_t aw = 64;   ///< Address width
  uint32_t dw = 512;  ///< Data width
  uint32_t lw = 8;    ///< Len width
  uint32_t bs = 1;    ///< Burst step length
  uint32_t bm = 16;   ///< Burst max length

  /// @brief Returns a BusDim from a string. See [common/cpp/include/fletcher/arrow-utils.h] for more info.
  static BusDim FromString(const std::string &str, BusDim default_to);

  /// @brief Return a human-readable version of the bus dimensions.
  [[nodiscard]] std::string ToString() const;
  /// @brief Return a shorter somewhat human-readable name for this BusDims, can be used for comparisons.
  [[nodiscard]] std::string ToName() const;
};

/// @brief Returns true if BusDims are equal.
bool operator==(const BusDim &lhs, const BusDim &rhs);

/// Holds bus parameters based on bus dimensions, that has actual nodes representing the dimensions.
struct BusDimParams {
  /// @brief Construct a new bunch of bus parameters based on a bus spec and function, and add them to a graph.
  explicit BusDimParams(cerata::Graph *parent, BusDim dim = BusDim{}, const std::string &prefix = "");
  /// @brief Construct a new bunch of bus parameters based on a bus spec and function, and add them to a graph.
  explicit BusDimParams(const std::shared_ptr<cerata::Graph> &parent,
                        BusDim spec = BusDim{},
                        const std::string &prefix = "")
      : BusDimParams(parent.get(), spec, prefix) {}
  /// Plain bus dimensions, not as nodes.
  BusDim plain;
  /// Value nodes.
  std::shared_ptr<Node> aw;  ///< Address width node
  std::shared_ptr<Node> dw;  ///< Data width node
  std::shared_ptr<Node> lw;  ///< Len width node
  std::shared_ptr<Node> bs;  ///< Burst step length node
  std::shared_ptr<Node> bm;  ///< Burst max length node

  /// @brief Return all parameters as an object vector.
  [[nodiscard]] std::vector<std::shared_ptr<Object>> all() const;
};

/// Holds bus parameters and function based on bus dimensions, that has actual nodes representing the dimensions.
struct BusSpecParams {
  /// Bus dimensions.
  BusDimParams dim;
  /// Bus function.
  BusFunction func;
  /// @brief Return a shorter somewhat human-readable name, can be used for comparisons.
  [[nodiscard]] std::string ToName() const;
};

/// Holds bus dimensions and function, without instantiating Cerata nodes.
struct BusSpec {
  /// @brief Default BusSpec constructor.
  BusSpec() = default;
  /// @brief BusSpec constructor.
  explicit BusSpec(const BusSpecParams &params) : dim(params.dim.plain), func(params.func) {}
  /// Bus dimensions.
  BusDim dim;
  /// Bus function.
  BusFunction func = BusFunction::READ;
  /// @brief Return a shorter somewhat human-readable name, can be used for comparisons.
  [[nodiscard]] std::string ToName() const;
};

/// @brief Returns true if BusSpecs are equal.
bool operator==(const BusSpec &lhs, const BusSpec &rhs);

/// @brief Return a Cerata type for a Fletcher bus read interface.
std::shared_ptr<Type> bus_read(const std::shared_ptr<Node> &addr_width,
                               const std::shared_ptr<Node> &data_width,
                               const std::shared_ptr<Node> &len_width);

/// @brief Return a Cerata type for a Fletcher bus write interface.
std::shared_ptr<Type> bus_write(const std::shared_ptr<Node> &addr_width,
                                const std::shared_ptr<Node> &data_width,
                                const std::shared_ptr<Node> &len_width);

/// @brief Fletcher bus type with access mode conveyed through spec of params.
std::shared_ptr<Type> bus(const BusSpecParams &param);

/// A port derived from bus parameters.
struct BusPort : public Port {
  /// @brief Construct a new port based on a bus parameters..
  BusPort(const std::string &name,
          Port::Dir dir,
          const BusSpecParams &params,
          std::shared_ptr<ClockDomain> domain = bus_cd())
      : Port(name, bus(params), dir, std::move(domain)), spec_(params) {}

  /// The bus spec to which the type generics of the bus port are bound.
  BusSpecParams spec_;

  /// @brief Deep-copy the BusPort.
  std::shared_ptr<Object> Copy() const override;
};
/// @brief Make a new port and return a shared pointer to it.
std::shared_ptr<BusPort> bus_port(const std::string &name, Port::Dir dir, const BusSpecParams &params);
/// @brief Make a new port, name it automatically based on the bus parameters, and return a shared pointer to it.
std::shared_ptr<BusPort> bus_port(Port::Dir dir, const BusSpecParams &params);

// TODO(johanpel): Perhaps generalize and build some sort of parameter struct/bundle in cerata for fast connection.
/// @brief Find and connect all prefixed bus params on a graph to the supplied source params, and append a rebind map.
void ConnectBusParam(cerata::Graph *dst,
                     const std::string &prefix,
                     const BusDimParams &src,
                     cerata::NodeMap *rebinding);

/**
 * @brief Return a Cerata model of a BusArbiter.
 * @param function  The function of the bus; either read or write.
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
Component *bus_arbiter(BusFunction function);

/// @brief Return a BusReadSerializer component
std::shared_ptr<Component> BusReadSerializer();

/// @brief Return a BusWriteSerializer component
std::shared_ptr<Component> BusWriteSerializer();

}  // namespace fletchgen


///  Specialization of std::hash for BusSpec
template<>
struct std::hash<fletchgen::BusSpec> {
  /// @brief Hash a BusSpec.
  size_t operator()(fletchgen::BusSpec const &spec) const noexcept {
    auto str = spec.ToName();
    return std::hash<std::string>()(str);
  }
};
