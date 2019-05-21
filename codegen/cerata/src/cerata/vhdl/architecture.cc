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

#include "cerata/vhdl/architecture.h"

#include <memory>

#include "cerata/graphs.h"
#include "cerata/vhdl/block.h"
#include "cerata/vhdl/declaration.h"
#include "cerata/vhdl/instantiation.h"

namespace cerata::vhdl {

MultiBlock Arch::Generate(const std::shared_ptr<Component> &comp) {
  MultiBlock ret;
  Line header_line;
  header_line << "architecture Implementation of " + comp->name() + " is";
  ret << header_line;

  // Component declarations
  auto components_used = GetAllUniqueComponents(comp.get());
  for (const auto &c : components_used) {
    // Check for metadata that this component is not marked primitive
    // In this case, a library package has been added at the top of the design file.
    if ((c->meta.count("primitive") == 0) || (c->meta.at("primitive") != "true")) {
      // TODO(johanpel): generate packages with component declarations
      auto comp_decl = Decl::Generate(c);
      ret << comp_decl;
    }
  }

  // Signal declarations
  auto signals = comp->GetAll<Signal>();
  for (const auto &s : signals) {
    auto signal_decl = Decl::Generate(s, 1);
    ret << signal_decl;
  }

  Line header_end;
  header_end << "begin";
  ret << header_end;

  // Component instantiations
  auto instances = comp->GetAllInstances();
  for (const auto &i : instances) {
    auto inst_decl = Inst::Generate(i);
    ret << inst_decl;
  }

  //TODO(johanpel): Signal connections

  Line footer;
  footer << "end architecture;";
  ret << footer;

  return ret;
}

}  // namespace cerata::vhdl
