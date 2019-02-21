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

#include "cerata/vhdl/design.h"

#include <string>
#include <memory>

#include "cerata/graphs.h"
#include "cerata/vhdl/transformation.h"
#include "cerata/vhdl/declaration.h"
#include "cerata/vhdl/architecture.h"

namespace cerata {
namespace vhdl {

MultiBlock Design::Generate() {
  MultiBlock ret;

  // TODO(johanpel): when proper copy is in place, make a copy of the whole structure before sanitizing,
  //  in case multiple back ends are processing the graph
  // This currently modifies the original structure.

  // Sanitize component
  Transformation::ResolvePortToPort(comp);

  if (!head.empty()) {
    Block h;
    h << Line(head);
    ret << h;
  }

  auto decl = Decl::Generate(comp.get(), true);
  auto arch = Arch::Generate(comp);


  ret << decl;
  ret << arch;

  return ret;
}

}  // namespace vhdl
}  // namespace cerata
