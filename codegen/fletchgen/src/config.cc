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

#include <vector>
#include <memory>

#include "./config.h"

namespace fletchgen {
namespace config {

using fletcher::getMeta;

std::vector<Config> fromSchemas(std::vector<std::shared_ptr<arrow::Schema>> schemas) {
  std::vector<Config> configs;
  for (const auto &schema : schemas) {
    Config cfg;
    std::string val;
    if (!(val = getMeta(schema, "fletcher_bus_addr_width")).empty()) {
      cfg.plat.bus.addr_width = (width) std::stoul(val);
    }
    if (!(val = getMeta(schema, "fletcher_bus_data_width")).empty()) {
      cfg.plat.bus.data_width = (width) std::stoul(val);
    }
    if (!(val = getMeta(schema, "fletcher_bus_len_width")).empty()) {
      cfg.plat.bus.len_width = (width) std::stoul(val);
    }
    if (!(val = getMeta(schema, "fletcher_bus_burst_step")).empty()) {
      cfg.plat.bus.burst.step = (unsigned int) std::stoul(val);
    }
    if (!(val = getMeta(schema, "fletcher_bus_burst_max")).empty()) {
      cfg.plat.bus.burst.max = (unsigned int) std::stoul(val);
    }
    if (!(val = getMeta(schema, "fletcher_reg_width")).empty()) {
      cfg.plat.mmio.data_width = (width) std::stoul(val);
    }
    if (!(val = getMeta(schema, "fletcher_index_width")).empty()) {
      cfg.arr.index_width = (width) std::stoul(val);
    }
    if (!(val = getMeta(schema, "fletcher_tag_width")).empty()) {
      cfg.user.tag_width = (width) std::stoul(val);
    }
    if (!(val = getMeta(schema, "fletcher_num_user_regs")).empty()) {
      cfg.user.num_user_regs = (unsigned int) std::stoul(val);
    }
    configs.push_back(cfg);
  }
  return configs;
}

}  // namespace config
}  // namespace fletchgen
