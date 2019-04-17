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

#include "cerata/vhdl/vhdl.h"

#include <algorithm>
#include <vector>
#include <string>
#include <memory>
#include <fstream>

#include "cerata/logging.h"
#include "cerata/edges.h"
#include "cerata/nodes.h"
#include "cerata/types.h"
#include "cerata/graphs.h"
#include "cerata/utils.h"

#include "cerata/vhdl/defaults.h"

namespace cerata::vhdl {

void VHDLOutputGenerator::Generate() {
  // Make sure the subdirectory exists.
  CreateDir(subdir());

  for (const auto &g : graphs_) {
    if ((g != nullptr)) {
      if (g->IsComponent()) {
        LOG(INFO, "Transforming Component " + g->name() + " to VHDL compatible version.");
        auto vhdl_design = Design(*Cast<Component>(g), DEFAULT_LIBS);

        LOG(INFO, "Generating VHDL sources for component " + g->name());
        auto vhdl_source = vhdl_design.Generate();
        vhdl_source.ToString();
        auto vhdl_path = subdir() + "/" + g->name() + ".vhd";

        LOG(INFO, "Saving to: " + vhdl_path);
        auto vhdl_file = std::ofstream(vhdl_path);
        vhdl_file << vhdl_source.ToString();
        vhdl_file.close();

      } else {
        LOG(WARNING, "Graph " << g->name() << " is not a component. Skipping VHDL output generation.");
      }
    }
  }
}

}  // namespace cerata::vhdl

