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

#include "cerata/vhdl/design.h"

#include <string>
#include <unordered_map>
#include <vector>
#include <algorithm>

#include "cerata/logging.h"
#include "cerata/vhdl/resolve.h"
#include "cerata/vhdl/declaration.h"
#include "cerata/vhdl/architecture.h"

namespace cerata::vhdl {

MultiBlock Design::Generate() {
  MultiBlock ret;

  // TODO(johanpel): when proper copy is in place, make a deep copy of the whole structure before sanitizing,
  //  in case multiple back ends are processing the graph. This currently modifies the original structure.

  // Resolve VHDL specific problems
  // Make signals out of all ports, because of a whole bunch of reasons, including the most annoying locally static
  // errors for port maps when wanting to use generics on the left hand side.
  Resolve::SignalizePorts(component_);

  // Place header
  Block h;
  if (!notice_.empty()) {
    h << notice_;
    h << Line();
  }

  if (!libs_.empty()) {
    h << Line(libs_);
    h << Line();
    ret << h;
  }

  // Figure out potential libs and packages used for primitive components.
  std::unordered_map<std::string, std::vector<std::string>> libs_and_packages;
  for (const auto &c : component_->GetAllInstanceComponents()) {
    if (c->meta().count(meta::PRIMITIVE) > 0) {
      if (c->meta().at(meta::PRIMITIVE) == "true") {
        std::string lib = c->meta().at(meta::LIBRARY);
        std::string pkg = c->meta().at(meta::PACKAGE);
        // Create the kv-pair if there is none yet
        if (libs_and_packages.count(lib) == 0) {
          libs_and_packages[lib] = std::vector<std::string>({pkg});
        } else {
          libs_and_packages.at(lib).push_back(pkg);
        }
      }
    }
  }

  // Sort and remove duplicate packages for each library
  for (auto &v : libs_and_packages) {
    auto &vec = v.second;
    std::sort(vec.begin(), vec.end());
    vec.erase(std::unique(vec.begin(), vec.end()), vec.end());
  }

  Block incl;
  for (const auto &kv : libs_and_packages) {
    incl << Line("library " + kv.first + ";");
    for (const auto &pkg : kv.second) {
      // TODO(johanpel): consider also allowing non-all.
      incl << Line("use " + kv.first + "." + pkg + ".all;");
    }
    incl << Line();
  }

  ret << incl;

  // Place any libraries from sub-components

  auto decl = Decl::Generate(*component_, true);
  auto arch = Arch::Generate(*component_);

  ret << decl;
  ret << Line();
  ret << arch;

  return ret;
}

}  // namespace cerata::vhdl
