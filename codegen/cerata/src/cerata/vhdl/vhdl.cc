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
  size_t num_graphs = 0;
  for (const auto &o : outputs_) {
    if ((o.graph != nullptr)) {
      if (o.graph->IsComponent()) {
        CERATA_LOG(INFO, "VHDL: Transforming Component " + o.graph->name() + " to VHDL-compatible version.");
        auto vhdl_design = Design(*Cast<Component>(o.graph), DEFAULT_LIBS);

        CERATA_LOG(INFO, "VHDL: Generating sources for component " + o.graph->name());
        auto vhdl_source = vhdl_design.Generate();
        vhdl_source.ToString();
        auto vhdl_path = subdir() + "/" + o.graph->name() + ".vhd";

        bool overwrite = false;

        if (o.meta.count("overwrite") > 0) {
          if (o.meta.at("overwrite") == "true") {
            overwrite = true;
          }
        }

        CERATA_LOG(INFO, "VHDL: Saving design to: " + vhdl_path);
        if (!FileExists(vhdl_path) || overwrite) {
          auto vhdl_file = std::ofstream(vhdl_path);
          vhdl_file << vhdl_source.ToString();
          vhdl_file.close();
        } else {
          CERATA_LOG(INFO, "VHDL: File exists, saving to " + vhdl_path + "t");
          // Save as a vhdt file.
          auto vhdl_file = std::ofstream(vhdl_path + "t");
          vhdl_file << vhdl_source.ToString();
          vhdl_file.close();
        }

        num_graphs++;
      } else {
        CERATA_LOG(WARNING, "VHDL: Graph " + o.graph->name() + " is not a component. Skipping output generation.");
      }
    } else {
      throw std::runtime_error("Graph is nullptr.");
    }
  }
  CERATA_LOG(INFO, "VHDL: Generated output for " + std::to_string(num_graphs) + " graphs.");
}

}  // namespace cerata::vhdl

