#include <iomanip>
#include "sim.h"

#include "../vhdt/vhdt.h"

namespace top {

std::string generateSimTop(const std::shared_ptr<fletchgen::ColumnWrapper> &col_wrapper,
                           const std::vector<std::ostream *> &outputs,
                           const std::string &read_srec_path,
                           std::vector<uint64_t> buffers,
                           const std::string &dump_srec_path) {
  const char *fhwd = std::getenv("FLETCHER_HARDWARE_DIR");
  if (fhwd == nullptr) {
    throw std::runtime_error("Environment variable FLETCHER_HARDWARE_DIR not set. Please source env.sh.");
  }

  fletchgen::VHDLTemplate t(std::string(fhwd) + "/vhdl/sim/sim_top.vhdt");

  fletchgen::config::Config cfg = col_wrapper->configs()[0];

  // Bus properties
  t.replace("BUS_ADDR_WIDTH", cfg.plat.bus.addr_width);
  t.replace("BUS_DATA_WIDTH", cfg.plat.bus.data_width);
  t.replace("BUS_STROBE_WIDTH", cfg.plat.bus.strobe_width);
  t.replace("BUS_LEN_WIDTH", cfg.plat.bus.len_width);
  t.replace("BUS_BURST_STEP_LEN", cfg.plat.bus.burst.step);
  t.replace("BUS_BURST_MAX_LEN", cfg.plat.bus.burst.max);

  // MMIO properties
  t.replace("MMIO_ADDR_WIDTH", cfg.plat.mmio.addr_width);
  t.replace("MMIO_DATA_WIDTH", cfg.plat.mmio.data_width);

  // Arrow properties
  t.replace("ARROW_INDEX_WIDTH", cfg.arr.index_width);

  // User properties
  t.replace("NUM_ARROW_BUFFERS", col_wrapper->countBuffers());
  t.replace("NUM_REGS", col_wrapper->countRegisters());
  t.replace("NUM_USER_REGS", col_wrapper->user_regs());
  t.replace("USER_TAG_WIDTH", cfg.user.tag_width);

  // Do not change this order, TODO: fix this in replacement code
  t.replace("FLETCHER_WRAPPER_NAME", col_wrapper->entity()->name());
  t.replace("FLETCHER_WRAPPER_INST_NAME", nameFrom({col_wrapper->entity()->name(), "inst"}));

  t.replace("READ_SREC_PATH", read_srec_path);
  t.replace("DUMP_SREC_PATH", dump_srec_path);

  if (!buffers.empty()) {
    std::stringstream bufstr;

    for (unsigned int i = 0; i < buffers.size() - 1; i++) {
      auto addr = buffers[i];
      auto msb = (uint32_t) (addr >> 32u);
      auto lsb = (uint32_t) (addr & 0xFFFFFFFF);

      bufstr << "    uc_reg_write(" << 2 * i << ", X\"" << std::setfill('0') << std::setw(8) << std::hex << lsb
             << "\", regs_in);" << std::endl;
      bufstr << "    wait until rising_edge(acc_clk);" << std::endl;
      bufstr << "    uc_reg_write(" << 2 * i + 1 << ", X\"" << std::setfill('0') << std::setw(8) << std::hex << msb
             << "\", regs_in);" << std::endl;
      bufstr << "    wait until rising_edge(acc_clk);" << std::endl;
    }
    t.replace("SREC_BUFFER_ADDRESSES", bufstr.str());
  } else {
    t.replace("SREC_BUFFER_ADDRESSES", "    -- No RecordBatch/SREC was supplied to Fletchgen. \n"
                                       "    -- Register buffer addresses here. Example: \n"
                                       "    -- uc_reg_write(0, X\"00000000\", regs_in); -- LSBs of first buffer address \n"
                                       "    -- wait until rising_edge(acc_clk);\n"
                                       "    -- uc_reg_write(1, X\"00000000\", regs_in); -- MSBs of first buffer address\n"
                                       "    -- wait until rising_edge(acc_clk);\n"
                                       "    -- uc_reg_write(2, X\"000000c0\", regs_in); -- LSBS of second buffer address\n"
                                       "    -- wait until rising_edge(acc_clk);\n"
                                       "    -- uc_reg_write(3, X\"00000000\", regs_in); -- MSBs of second buffer address\n"
                                       "    -- wait until rising_edge(acc_clk);"
                                       "    -- etc...\n");
  }

  for (auto &o : outputs) {
    o->flush();
    *o << t.toString();
  }

  return t.toString();
}

}