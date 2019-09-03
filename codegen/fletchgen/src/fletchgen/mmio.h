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
#include <string>
#include <memory>
#include <utility>

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
using cerata::ClockDomain;

/// @brief MMIO bus specification
struct MmioSpec {
  /// The MMIO bus data width.
  size_t data_width = 32;
  /// The MMIO bus address width.
  size_t addr_width = 32;
  /// @brief Return a human-readable representation of this MmmioSpec.
  [[nodiscard]] std::string ToString() const;
  /// @brief Return a Cerata type name based on this MmioSpec.
  [[nodiscard]] std::string ToMMIOTypeName() const;
};

/// @brief MMIO type
std::shared_ptr<Type> mmio(MmioSpec spec = MmioSpec());

/// A port derived from an MMIO specification.
struct MmioPort : public Port {
  /// The MMIO specification this port was derived from.
  MmioSpec spec_;

  /// @brief Construct a new MmioPort.
  MmioPort(Port::Dir dir,
           MmioSpec spec,
           std::string name = "mmio",
           std::shared_ptr<ClockDomain> domain = cerata::default_domain()) :
      Port(std::move(name), mmio(spec), dir, std::move(domain)), spec_(spec) {}

  /**
   * @brief Make a new MmioPort, returning a shared pointer to it.
   * @param dir   The direction of the port.
   * @param spec  The specification of the port.
   * @return      A shared pointer to the new port.
   */
  static std::shared_ptr<MmioPort> Make(Port::Dir dir,
                                        MmioSpec spec = MmioSpec(),
                                        const std::shared_ptr<ClockDomain>& domain = cerata::default_domain());
};

}  // namespace fletchgen
