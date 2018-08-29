#include "config.h"

namespace fletchgen {
namespace config {
Config fromSchema(arrow::Schema *schema) {
  Config ret;
  std::string val;
  if (!(val = getMeta(schema, "fletcher_bus_addr_width")).empty()) {
    ret.plat.bus.addr_width = (width) std::stoul(val);
  }
  if (!(val = getMeta(schema, "fletcher_bus_data_width")).empty()) {
    ret.plat.bus.data_width = (width) std::stoul(val);
  }
  if (!(val = getMeta(schema, "fletcher_bus_len_width")).empty()) { ret.plat.bus.len_width = (width) std::stoul(val); }
  if (!(val = getMeta(schema, "fletcher_bus_burst_step")).empty()) {
    ret.plat.bus.burst.step = (unsigned int) std::stoul(val);
  }
  if (!(val = getMeta(schema, "fletcher_bus_burst_max")).empty()) {
    ret.plat.bus.burst.max = (unsigned int) std::stoul(val);
  }
  if (!(val = getMeta(schema, "fletcher_reg_width")).empty()) { ret.plat.mmio.data_width = (width) std::stoul(val); }
  if (!(val = getMeta(schema, "fletcher_index_width")).empty()) { ret.arr.index_width = (width) std::stoul(val); }
  if (!(val = getMeta(schema, "fletcher_tag_width")).empty()) { ret.user.tag_width = (width) std::stoul(val); }
  if (!(val = getMeta(schema, "fletcher_num_user_regs")).empty()) {
    ret.user.num_user_regs = (unsigned int) std::stoul(val);
  }
  return ret;
}

} // namespace config
} // namespace fletchgen