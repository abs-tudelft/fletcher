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
                           const std::string &dump_srec_path,
                           const std::vector<std::pair<uint32_t, uint32_t>> &firstlastidx) {
  // Fletcher hardware dir
  const char *fhwd = std::getenv("FLETCHER_HARDWARE_DIR");
  if (fhwd == nullptr) {
    throw std::runtime_error("Environment variable FLETCHER_HARDWARE_DIR not set. Please source env.sh.");
  }

  // Number of default registers
  constexpr int ndefault = 4;

  // Number of first/last indices
  size_t nfl = firstlastidx.size();

  // Template file for simulation top-level
  cerata::vhdl::Template t(std::string(fhwd) + "/sim/sim_top.vhdt");

  // Bus properties
  t.replace("BUS_ADDR_WIDTH", 64);
  t.replace("BUS_DATA_WIDTH", 512);
  t.replace("BUS_STROBE_WIDTH", 512 / 8);
  t.replace("BUS_LEN_WIDTH", 8);
  t.replace("BUS_BURST_STEP_LEN", 1);
  t.replace("BUS_BURST_MAX_LEN", 64);

  // Do not change this order, TODO: fix this in replacement code
  t.replace("FLETCHER_WRAPPER_NAME", mantle->name());
  t.replace("FLETCHER_WRAPPER_INST_NAME", mantle->name() + "_inst");

  t.replace("READ_SREC_PATH", read_srec_path);
  t.replace("DUMP_SREC_PATH", dump_srec_path);

  if (!buffers.empty()) {
    std::stringstream bufstr;
    // Loop over all buffer offsets.
    // We skip the last offset as it is the next empty part of the memory in the SREC file.
    for (unsigned int i = 0; i < buffers.size()-1; i++) {
      // Get the low and high part of the address
      auto addr = buffers[i];
      auto addr_lo = (uint32_t) (addr & 0xFFFFFFFF);
      auto addr_hi = (uint32_t) (addr >> 32u);
      bufstr << "    mmio_write("
             << std::dec << 2 * i + (ndefault + 2 * nfl) << ", "
             << "X\"" << std::setfill('0') << std::setw(8) << std::hex << addr_lo << "\","
             << " mmio_source, mmio_sink);"
             << std::endl;

      bufstr << "    mmio_write("
             << std::dec << 2 * i + (ndefault + 2 * nfl) + 1 << ", "
             << "X\"" << std::setfill('0') << std::setw(8) << std::hex << addr_hi << "\", "
             << " mmio_source, mmio_sink);"
             << std::endl;
    }
    t.replace("SREC_BUFFER_ADDRESSES", bufstr.str());
  } else {
    t.replace("SREC_BUFFER_ADDRESSES", "    -- No RecordBatch/SREC was supplied to Fletchgen. \n");
  }
  if (!firstlastidx.empty()) {
    std::stringstream flstr;
    for (unsigned int i = 0; i < firstlastidx.size(); i++) {
      flstr << "    mmio_write("
            << std::dec << 2 * i + (ndefault) << ", "
            << "X\"" << std::setfill('0') << std::setw(8) << std::hex << firstlastidx[i].first << "\","
            << " mmio_source, mmio_sink);"
            << std::endl;

      flstr << "    mmio_write("
            << std::dec << 2 * i + (ndefault) + 1 << ", "
            << "X\"" << std::setfill('0') << std::setw(8) << std::hex << firstlastidx[i].second << "\", "
            << " mmio_source, mmio_sink);"
            << std::endl;
    }
    t.replace("SREC_FIRSTLAST_INDICES", flstr.str());
  } else {
    t.replace("SREC_FIRSTLAST_INDICES", "    -- No RecordBatch/SREC was supplied to Fletchgen. \n");
  }

  for (auto &o : outputs) {
    o->flush();
    *o << t.toString();
  }

  return t.toString();
}

} // namespace fletchgen::top
