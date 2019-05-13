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

#include <iomanip>

#include <cerata/api.h>

#include "fletchgen/mantle.h"

namespace fletchgen::top {

std::string GenerateSimTop(const std::shared_ptr<Mantle> &mantle,
                           const std::vector<std::ostream *> &outputs,
                           const std::string &read_srec_path,
                           std::vector<uint64_t> buffers,
                           const std::string &dump_srec_path) {
  const char *fhwd = std::getenv("FLETCHER_HARDWARE_DIR");
  if (fhwd == nullptr) {
    throw std::runtime_error("Environment variable FLETCHER_HARDWARE_DIR not set. Please source env.sh.");
  }

  cerata::vhdl::Template t(std::string(fhwd) + "/sim/sim_top.vhdt");

  // Bus properties
  t.replace("BUS_ADDR_WIDTH", 64);
  t.replace("BUS_DATA_WIDTH", 512);
  t.replace("BUS_STROBE_WIDTH", 512 / 8);
  t.replace("BUS_LEN_WIDTH", 8);
  t.replace("BUS_BURST_STEP_LEN", 1);
  t.replace("BUS_BURST_MAX_LEN", 64);

  // MMIO properties
  t.replace("MMIO_ADDR_WIDTH", 32);
  t.replace("MMIO_DATA_WIDTH", 32);

  // Arrow properties
  t.replace("ARROW_INDEX_WIDTH", 32);

  // Do not change this order, TODO: fix this in replacement code
  t.replace("FLETCHER_WRAPPER_NAME", mantle->name());
  t.replace("FLETCHER_WRAPPER_INST_NAME", mantle->name() + "_inst");

  t.replace("READ_SREC_PATH", read_srec_path);
  t.replace("DUMP_SREC_PATH", dump_srec_path);

  if (!buffers.empty()) {
    std::stringstream bufstr;

    for (unsigned int i = 0; i < buffers.size() - 1; i++) {
      auto addr = buffers[i];
      auto msb = (uint32_t) (addr >> 32u);
      auto lsb = (uint32_t) (addr & 0xFFFFFFFF);

      bufstr << "    mmio_write(" << std::dec << 2 * i + 6 << ", X\"" << std::setfill('0') << std::setw(8) << std::hex
             << lsb << "\", regs_in);" << std::endl;
      bufstr << "    wait until rising_edge(acc_clk);" << std::endl;
      bufstr << "    mmio_write(" << std::dec << 2 * i + 1 + 6 << ", X\"" << std::setfill('0') << std::setw(8)
             << std::hex << msb << "\", regs_in);" << std::endl;
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

} // namespace fletchgen::top
