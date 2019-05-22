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
  const char *fhwd = std::getenv("FLETCHER_DIR");
  if (fhwd == nullptr) {
    throw std::runtime_error("Environment variable FLETCHER_DIR not set.\n"
                             "Please point FLETCHER_DIR to the Fletcher repository.");
  }

  // Number of default registers
  constexpr int ndefault = 4;

  // Number of first/last indices
  size_t nfl = firstlastidx.size();

  // Template file for simulation top-level
  cerata::vhdl::Template t(std::string(fhwd) + "/hardware/sim/sim_top.vhdt");

  // Bus properties
  t.Replace("BUS_ADDR_WIDTH", 64);
  t.Replace("BUS_DATA_WIDTH", 512);
  t.Replace("BUS_STROBE_WIDTH", 512 / 8);
  t.Replace("BUS_LEN_WIDTH", 8);
  t.Replace("BUS_BURST_STEP_LEN", 1);
  t.Replace("BUS_BURST_MAX_LEN", 64);

  // Do not change this order, TODO: fix this in replacement code
  t.replace("FLETCHER_WRAPPER_NAME", mantle->name());
  t.replace("FLETCHER_WRAPPER_INST_NAME", mantle->name() + "_inst");

  t.replace("READ_SREC_PATH", read_srec_path);
  t.replace("DUMP_SREC_PATH", dump_srec_path);

  if (!buffers.empty()) {
    std::stringstream bufstr;
    // Loop over all buffer offsets.
    // We skip the last offset as it is the next empty part of the memory in the SREC file.
    for (unsigned int i = 0; i < buffers.size() - 1; i++) {
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

  // Read/write specific stuff
  if (mantle->schema_set_->RequiresReading()) {
    t.replace("BUS_READ_SLAVE_MOCK",
              "  rmem_inst: BusReadSlaveMock\n"
              "  generic map (\n"
              "    BUS_ADDR_WIDTH              => BUS_ADDR_WIDTH,\n"
              "    BUS_LEN_WIDTH               => BUS_LEN_WIDTH,\n"
              "    BUS_DATA_WIDTH              => BUS_DATA_WIDTH,\n"
              "    SEED                        => 1337,\n"
              "    RANDOM_REQUEST_TIMING       => false,\n"
              "    RANDOM_RESPONSE_TIMING      => false,\n"
              "    SREC_FILE                   => \"" + read_srec_path + "\"\n"
                                                                         "  )\n"
                                                                         "  port map (\n"
                                                                         "    clk                         => bcd_clk,\n"
                                                                         "    reset                       => bcd_reset,\n"
                                                                         "    rreq_valid                  => bus_rreq_valid,\n"
                                                                         "    rreq_ready                  => bus_rreq_ready,\n"
                                                                         "    rreq_addr                   => bus_rreq_addr,\n"
                                                                         "    rreq_len                    => bus_rreq_len,\n"
                                                                         "    rdat_valid                  => bus_rdat_valid,\n"
                                                                         "    rdat_ready                  => bus_rdat_ready,\n"
                                                                         "    rdat_data                   => bus_rdat_data,\n"
                                                                         "    rdat_last                   => bus_rdat_last\n"
                                                                         "  );\n"
                                                                         "\n");

    t.replace("MST_RREQ_DECLARE",
              "      mst_rreq_valid            : out std_logic;\n"
              "      mst_rreq_ready            : in  std_logic;\n"
              "      mst_rreq_addr             : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);\n"
              "      mst_rreq_len              : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);\n"
              "      mst_rdat_valid            : in  std_logic;\n"
              "      mst_rdat_ready            : out std_logic;\n"
              "      mst_rdat_data             : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);\n"
              "      mst_rdat_last             : in  std_logic;\n");

    t.replace("MST_RREQ_INSTANTIATE",
              "      mst_rreq_valid            => bus_rreq_valid,\n"
              "      mst_rreq_ready            => bus_rreq_ready,\n"
              "      mst_rreq_addr             => bus_rreq_addr,\n"
              "      mst_rreq_len              => bus_rreq_len,\n"
              "      mst_rdat_valid            => bus_rdat_valid,\n"
              "      mst_rdat_ready            => bus_rdat_ready,\n"
              "      mst_rdat_data             => bus_rdat_data,\n"
              "      mst_rdat_last             => bus_rdat_last,\n");
  } else {
    t.replace("BUS_READ_SLAVE_MOCK", "");
    t.replace("MST_RREQ_DECLARE", "");
    t.replace("MST_RREQ_INSTANTIATE", "");
  }
  if (mantle->schema_set_->RequiresWriting()) {
    t.replace("BUS_WRITE_SLAVE_MOCK",
              "  wmem_inst: BusWriteSlaveMock\n"
              "  generic map (\n"
              "    BUS_ADDR_WIDTH              => BUS_ADDR_WIDTH,\n"
              "    BUS_LEN_WIDTH               => BUS_LEN_WIDTH,\n"
              "    BUS_DATA_WIDTH              => BUS_DATA_WIDTH,\n"
              "    BUS_STROBE_WIDTH            => BUS_STROBE_WIDTH,\n"
              "    SEED                        => 1337,\n"
              "    RANDOM_REQUEST_TIMING       => false,\n"
              "    RANDOM_RESPONSE_TIMING      => false,\n"
              "    SREC_FILE                   => \"" + dump_srec_path + "\"\n"
                                                                         "  )\n"
                                                                         "  port map (\n"
                                                                         "    clk                         => bcd_clk,\n"
                                                                         "    reset                       => bcd_reset,\n"
                                                                         "    wreq_valid                  => bus_wreq_valid,\n"
                                                                         "    wreq_ready                  => bus_wreq_ready,\n"
                                                                         "    wreq_addr                   => bus_wreq_addr,\n"
                                                                         "    wreq_len                    => bus_wreq_len,\n"
                                                                         "    wdat_valid                  => bus_wdat_valid,\n"
                                                                         "    wdat_ready                  => bus_wdat_ready,\n"
                                                                         "    wdat_data                   => bus_wdat_data,\n"
                                                                         "    wdat_strobe                 => bus_wdat_strobe,\n"
                                                                         "    wdat_last                   => bus_wdat_last\n"
                                                                         "  );");

    t.replace("MST_WREQ_DECLARE",
              "      mst_wreq_valid            : out std_logic;\n"
              "      mst_wreq_ready            : in std_logic;\n"
              "      mst_wreq_addr             : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);\n"
              "      mst_wreq_len              : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);\n"
              "      mst_wdat_valid            : out std_logic;\n"
              "      mst_wdat_ready            : in std_logic;\n"
              "      mst_wdat_data             : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);\n"
              "      mst_wdat_strobe           : out std_logic_vector(BUS_STROBE_WIDTH-1 downto 0);\n"
              "      mst_wdat_last             : out std_logic;");

    t.replace("MST_WREQ_INSTANTIATE",
              "      mst_wreq_valid            => bus_wreq_valid,\n"
              "      mst_wreq_ready            => bus_wreq_ready,\n"
              "      mst_wreq_addr             => bus_wreq_addr,\n"
              "      mst_wreq_len              => bus_wreq_len,\n"
              "      mst_wdat_valid            => bus_wdat_valid,\n"
              "      mst_wdat_ready            => bus_wdat_ready,\n"
              "      mst_wdat_data             => bus_wdat_data,\n"
              "      mst_wdat_strobe           => bus_wdat_strobe,\n"
              "      mst_wdat_last             => bus_wdat_last");
  } else {
    t.replace("BUS_WRITE_SLAVE_MOCK", "");
    t.replace("MST_WREQ_DECLARE", "");
    t.replace("MST_WREQ_INSTANTIATE", "");
  }

  for (auto &o : outputs) {
    o->flush();
    *o << t.toString();
  }

  return t.toString();
}

} // namespace fletchgen::top
