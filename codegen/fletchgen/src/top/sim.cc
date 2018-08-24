#include "sim.h"

#include "../vhdt/vhdt.h"

namespace top {

std::string generateSimTop(const std::shared_ptr<fletchgen::ColumnWrapper> &col_wrapper,
                           const std::vector<std::ostream *> &outputs,
                           std::string read_srec_path,
                           std::string write_srec_path) {
  const char *fhwd = std::getenv("FLETCHER_HARDWARE_DIR");
  if (fhwd == nullptr) {
    throw std::runtime_error("Environment variable FLETCHER_HARDWARE_DIR not set. Please source env.sh.");
  }

  fletchgen::VHDLTemplate t(std::string(fhwd) + "/vhdl/sim/sim_top.vhdt");

  // Bus properties
  t.replace("BUS_ADDR_WIDTH", col_wrapper->config().plat.bus.addr_width);
  t.replace("BUS_DATA_WIDTH", col_wrapper->config().plat.bus.data_width);
  t.replace("BUS_STROBE_WIDTH", col_wrapper->config().plat.bus.strobe_width);
  t.replace("BUS_LEN_WIDTH", col_wrapper->config().plat.bus.len_width);
  t.replace("BUS_BURST_STEP_LEN", col_wrapper->config().plat.bus.burst.step);
  t.replace("BUS_BURST_MAX_LEN", col_wrapper->config().plat.bus.burst.max);

  // MMIO properties
  t.replace("MMIO_ADDR_WIDTH", col_wrapper->config().plat.mmio.addr_width);
  t.replace("MMIO_DATA_WIDTH", col_wrapper->config().plat.mmio.data_width);

  // Arrow properties
  t.replace("ARROW_INDEX_WIDTH", col_wrapper->config().arr.index_width);

  // User properties
  t.replace("NUM_ARROW_BUFFERS", col_wrapper->countBuffers());
  t.replace("NUM_REGS", col_wrapper->countRegisters());
  t.replace("NUM_USER_REGS", col_wrapper->user_regs());
  t.replace("USER_TAG_WIDTH", col_wrapper->config().user.tag_width);

  // Do not change this order, TODO: fix this in replacement code
  t.replace("FLETCHER_WRAPPER_NAME", col_wrapper->entity()->name());
  t.replace("FLETCHER_WRAPPER_INST_NAME", nameFrom({col_wrapper->entity()->name(), "inst"}));

  t.replace("READ_SREC_PATH", read_srec_path);
  t.replace("WRITE_SREC_PATH", write_srec_path);

  for (auto &o : outputs) {
    o->flush();
    *o << t.toString();
  }

  return t.toString();
}

}