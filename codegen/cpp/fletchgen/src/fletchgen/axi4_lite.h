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
#include <utility>
#include <memory>
#include <string>

namespace fletchgen {

using cerata::ClockDomain;
using cerata::Type;
using cerata::Port;

/// @brief AXI-lite bus width specification. Address is always 32, but data can also be 64. Modifiable.
struct Axi4LiteSpec {
  /// The MMIO bus data width.
  size_t data_width = 32;
  /// The MMIO bus address width.
  size_t addr_width = 32;
  /// @brief Return a human-readable representation of this Axi4LiteSpec.
  [[nodiscard]] std::string ToString() const;
  /// @brief Return a Cerata type name based on this Axi4LiteSpec.
  [[nodiscard]] std::string ToAxiTypeName() const;
};

/// An AXI4-lite port derived from an AXI-lite width specification.
struct Axi4LitePort : public Port {
  /// The specification this port was derived from.
  Axi4LiteSpec spec_;

  /// @brief Construct a new MmioPort.
  Axi4LitePort(Port::Dir dir, Axi4LiteSpec spec, std::string name = "mmio",
               std::shared_ptr<ClockDomain> domain = cerata::default_domain());
  /// @brief Make a copy of this AXI4-lite port.
  std::shared_ptr<Object> Copy() const override;
};

/// @brief AXI4-lite port type.
std::shared_ptr<Type> axi4_lite_type(Axi4LiteSpec spec = Axi4LiteSpec());

/**
 * @brief Make a new AXI4-lite port, returning a shared pointer to it.
 * @param dir    The direction of the port.
 * @param spec   The specification of the port.
 * @param domain The clock domain.
 * @return       A shared pointer to the new port.
 */
std::shared_ptr<Axi4LitePort> axi4_lite(Port::Dir dir,
                                        const std::shared_ptr<ClockDomain> &domain = cerata::default_domain(),
                                        Axi4LiteSpec spec = Axi4LiteSpec());

}  // namespace fletchgen
