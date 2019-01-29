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

#include "./design.h"

#include <string>
#include <memory>

#include "../graphs.h"

#include "./transformation.h"
#include "./declaration.h"
#include "./architecture.h"

namespace fletchgen {
namespace vhdl {

MultiBlock Design::Generate(const std::shared_ptr<Component> &comp) {
  MultiBlock ret;

  // Sanitize component
  auto vhdl_comp_copy = comp->Copy();
  auto vhdl_comp = *Cast<Component>(vhdl_comp_copy);
  Transformation::ResolvePortToPort(vhdl_comp);

  auto decl_code = Decl::Generate(vhdl_comp);
  auto arch_code = Arch::Generate(vhdl_comp);

  ret << decl_code;
  ret << arch_code;

  return ret;
}

}  // namespace vhdl
}  // namespace fletchgen