#include "config.h"

namespace fletchgen {
namespace config {
Config fromSchema(arrow::Schema *schema) {
  Config ret;
  std::string val;
  if (!(val = getMeta(schema, "FLETCHGEN_BUS_ADDR_WIDTH")).empty()) {
    ret.plat.bus.addr_width = (width) std::stoul(val);
  }
  if (!(val = getMeta(schema, "FLETCHGEN_BUS_DATA_WIDTH")).empty()) {
    ret.plat.bus.data_width = (width) std::stoul(val);
  }
  if (!(val = getMeta(schema, "FLETCHGEN_BUS_LEN_WIDTH")).empty()) { ret.plat.bus.len_width = (width) std::stoul(val); }
  if (!(val = getMeta(schema, "FLETCHGEN_BUS_BURST_STEP")).empty()) {
    ret.plat.bus.burst.step = (unsigned int) std::stoul(val);
  }
  if (!(val = getMeta(schema, "FLETCHGEN_BUS_BURST_MAX")).empty()) {
    ret.plat.bus.burst.max = (unsigned int) std::stoul(val);
  }
  if (!(val = getMeta(schema, "FLETCHGEN_REG_WIDTH")).empty()) { ret.plat.reg.reg_width = (width) std::stoul(val); }
  if (!(val = getMeta(schema, "FLETCHGEN_INDEX_WIDTH")).empty()) { ret.arr.index_width = (width) std::stoul(val); }
  if (!(val = getMeta(schema, "FLETCHGEN_TAG_WIDTH")).empty()) { ret.user.tag_width = (width) std::stoul(val); }
  if (!(val = getMeta(schema, "FLETCHGEN_NUM_USER_REGS")).empty()) {
    ret.user.num_user_regs = (unsigned int) std::stoul(val);
  }
  return ret;
}

} // namespace config
} // namespace fletchgen