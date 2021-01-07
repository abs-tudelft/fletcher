// Copyright 2018-2019 Delft University of Technology
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

#include "fletchgen/top/sim.h"

#include <fletcher/fletcher.h>
#include <cerata/api.h>
#include <cerata/vhdl/vhdl.h>
#include <string>
#include <iomanip>
#include <cstdlib>

#include "fletchgen/top/sim_template.h"
#include "fletchgen/mantle.h"

namespace fletchgen::top {

using fletcher::RecordBatchDescription;
using cerata::vhdl::Template;

static std::string GenMMIOWrite(uint32_t idx, uint32_t value, const std::string &comment = "") {
  std::stringstream str;
  str << "    mmio_write32("
      << std::dec << idx << ", "
      << "X\"" << std::setfill('0') << std::setw(8) << std::hex << value << "\","
      << " mmio_source, mmio_sink, bcd_clk, bcd_reset);";
  if (!comment.empty()) {
    str << " -- " << comment;
  }
  str << std::endl;
  return str.str();
}

static std::string GenMMIORead(uint32_t idx,
                               const std::string &print_prefix,
                               bool hex_ndec = true,
                               const std::string &comment = "") {
  std::stringstream str;
  str << "    mmio_read32("
      << std::dec << idx << ", "
      << " read_data, "
      << " mmio_source, mmio_sink, bcd_clk, bcd_reset);";
  if (!comment.empty()) {
    str << " -- " << comment;
  }
  str << "\n";
  str << R"(    println(")" + print_prefix;
  if (hex_ndec) {
    str << R"(: " & slvToHex(read_data));)" << std::endl;
  } else {
    str << R"(: " & slvToDec(read_data));)" << std::endl;
  }
  return str.str();
}

static std::string CanonicalizePath(const std::string &path) {
  std::string result;
  if (!path.empty()) {
    char *p = realpath(path.c_str(), nullptr);
    if (p == nullptr) {
      FLETCHER_LOG(FATAL, "Could not canonicalize path: " << path);
    }
    result = std::string(p);
    free(p);
  }
  return result;
}

std::string GenerateSimTop(const Design &design,
                           const std::vector<std::ostream *> &outputs,
                           const std::string &read_srec_path,
                           const std::string &write_srec_path,
                           const std::vector<RecordBatchDescription> &recordbatches) {
  // Template file for simulation top-level
  auto t = Template::FromString(sim_source);

  // Offset of schema specific registers
  constexpr int ndefault = FLETCHER_REG_SCHEMA;

  // Obtain read/write schemas.
  auto read_schemas = design.schema_set->read_schemas();
  auto write_schemas = design.schema_set->write_schemas();

  // Total number of RecordBatches
  size_t num_rbs = read_schemas.size() + write_schemas.size();

  // Bus properties
  t.Replace("BUS_ADDR_WIDTH", 64);
  t.Replace("BUS_DATA_WIDTH", 512);
  t.Replace("BUS_LEN_WIDTH", 8);
  t.Replace("BUS_BURST_STEP_LEN", 1);
  t.Replace("BUS_BURST_MAX_LEN", 64);

  t.Replace("MMIO_DATA_WIDTH", design.mmio_spec.data_width);
  t.Replace("MMIO_ADDR_WIDTH", design.mmio_spec.addr_width);
  t.Replace("MMIO_STRB", design.mmio_spec.data_width == 64 ? R"(X"0F" when idx mod 2 = 0 else X"F0")" : R"(X"F")");
  t.Replace("MMIO_RW_DATA_RANGE",
            design.mmio_spec.data_width == 64 ? R"((32 * (1 + idx mod 2)-1 downto 32 * (idx mod 2)))" : "");
  t.Replace("MMIO_OFFSET", design.mmio_spec.offset);

  // Do not change this order, TODO: fix this in replacement code
  t.Replace("FLETCHER_WRAPPER_NAME", design.mantle_comp->name());
  t.Replace("FLETCHER_WRAPPER_INST_NAME", design.mantle_comp->name() + "_inst");

  t.Replace("READ_SREC_PATH", read_srec_path);
  t.Replace("WRITE_SREC_PATH", write_srec_path);

  // Mantle declaration
  t.Replace("MANTLE_DECL", cerata::vhdl::Decl::Generate(*design.mantle_comp, false, 1).ToString());

  // Generate all the buffer and recordbatch metadata
  std::stringstream buffer_meta;
  std::stringstream rb_meta;

  FLETCHER_LOG(DEBUG, "SIM: Generating MMIO writes for " << num_rbs << " RecordBatches.");

  // Loop over all RecordBatches
  size_t buffer_offset = 0;
  size_t rb_offset = 0;
  for (const auto &rb : recordbatches) {
    for (const auto &f : rb.fields) {
      for (const auto &b : f.buffers) {
        // Get the low and high part of the address
        auto addr = reinterpret_cast<uint64_t>(b.raw_buffer_);
        auto addr_lo = (uint32_t) (addr & 0xFFFFFFFF);
        auto addr_hi = (uint32_t) (addr >> 32u);
        uint32_t buffer_idx = 2 * (buffer_offset) + (ndefault + 2 * num_rbs);
        buffer_meta << GenMMIOWrite(buffer_idx,
                                    addr_lo,
                                    rb.name + " " + fletcher::ToString(b.desc_) + " buffer address.");
        buffer_meta << GenMMIOWrite(buffer_idx + 1,
                                    addr_hi);
        buffer_offset++;
      }
    }
    uint32_t rb_idx = 2 * (rb_offset) + ndefault;
    rb_meta << GenMMIOWrite(rb_idx, 0, rb.name + " first index.");
    rb_meta << GenMMIOWrite(rb_idx + 1, rb.rows, rb.name + " last index.");
    rb_offset++;
  }
  t.Replace("SREC_BUFFER_ADDRESSES", buffer_meta.str());
  t.Replace("SREC_FIRSTLAST_INDICES", rb_meta.str());

  std::stringstream kri;
  if (!design.kernel_regs.empty()) {
    for (const auto &cr : design.kernel_regs) {
      if (cr.behavior == MmioBehavior::CONTROL) {
        // TODO(johanpel): fix this for non-32 bit regs
        auto val = cr.init ? *cr.init : 0;
        kri << GenMMIOWrite(cr.addr.value() / 4, val, "Write register \"" + cr.name + "\" initial value.");
      }
    }
  }
  t.Replace("KERNEL_REGS_INIT", kri.str());

  // Profiling registers.
  if (!design.profiling_regs.empty()) {
    std::stringstream profile_reads;
    uint32_t addr = 0;
    int i = 0;
    for (const auto &pr : design.profiling_regs) {
      if (pr.name == "Profile_enable") {
        // Profiling register should have an address now.
        addr = pr.addr.value();
      } else if (pr.name == "Profile_clear") {
        // do nothing
      } else if (pr.function == MmioFunction::PROFILE) {
        i++;
        std::stringstream profile_prefix;
        profile_prefix << std::setw(42) << ("Profile " + pr.name);
        profile_reads << GenMMIORead(pr.addr.value() / 4, profile_prefix.str(), false);
      }
    }
    t.Replace("PROFILE_START", GenMMIOWrite(addr / 4, 1, "Start profiling."));
    t.Replace("PROFILE_STOP", GenMMIOWrite(addr / 4, 0, "Stop profiling."));
    t.Replace("PROFILE_READ", profile_reads.str());
  } else {
    t.Replace("PROFILE_START", "");
    t.Replace("PROFILE_STOP", "");
    t.Replace("PROFILE_READ", "");
  }

  // Read/write specific memory models
  if (design.schema_set->RequiresReading()) {
    auto abs_path = CanonicalizePath(read_srec_path);
    t.Replace("BUS_READ_SLAVE_MOCK",
              "  rmem_inst: BusReadSlaveMock\n"
              "  generic map (\n"
              "    BUS_ADDR_WIDTH              => BUS_ADDR_WIDTH,\n"
              "    BUS_LEN_WIDTH               => BUS_LEN_WIDTH,\n"
              "    BUS_DATA_WIDTH              => BUS_DATA_WIDTH,\n"
              "    SEED                        => 1337,\n"
              "    RANDOM_REQUEST_TIMING       => false,\n"
              "    RANDOM_RESPONSE_TIMING      => false,\n"
              "    SREC_FILE                   => \"" +
                  abs_path
                  + "\"\n"
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

    t.Replace("MST_RREQ_DECLARE",
              "      rd_mst_rreq_valid         : out std_logic;\n"
              "      rd_mst_rreq_ready         : in  std_logic;\n"
              "      rd_mst_rreq_addr          : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);\n"
              "      rd_mst_rreq_len           : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);\n"
              "      rd_mst_rdat_valid         : in  std_logic;\n"
              "      rd_mst_rdat_ready         : out std_logic;\n"
              "      rd_mst_rdat_data          : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);\n"
              "      rd_mst_rdat_last          : in  std_logic;\n");

    t.Replace("MST_RREQ_INSTANTIATE",
              "      rd_mst_rreq_valid         => bus_rreq_valid,\n"
              "      rd_mst_rreq_ready         => bus_rreq_ready,\n"
              "      rd_mst_rreq_addr          => bus_rreq_addr,\n"
              "      rd_mst_rreq_len           => bus_rreq_len,\n"
              "      rd_mst_rdat_valid         => bus_rdat_valid,\n"
              "      rd_mst_rdat_ready         => bus_rdat_ready,\n"
              "      rd_mst_rdat_data          => bus_rdat_data,\n"
              "      rd_mst_rdat_last          => bus_rdat_last,\n");
  } else {
    t.Replace("BUS_READ_SLAVE_MOCK", "");
    t.Replace("MST_RREQ_DECLARE", "");
    t.Replace("MST_RREQ_INSTANTIATE", "");
  }
  if (design.schema_set->RequiresWriting()) {
    t.Replace("BUS_WRITE_SLAVE_MOCK",
              "  wmem_inst: BusWriteSlaveMock\n"
              "  generic map (\n"
              "    BUS_ADDR_WIDTH              => BUS_ADDR_WIDTH,\n"
              "    BUS_LEN_WIDTH               => BUS_LEN_WIDTH,\n"
              "    BUS_DATA_WIDTH              => BUS_DATA_WIDTH,\n"
              "    SEED                        => 1337,\n"
              "    RANDOM_REQUEST_TIMING       => false,\n"
              "    RANDOM_RESPONSE_TIMING      => false,\n"
              "    SREC_FILE                   => \""
                  + CanonicalizePath(write_srec_path)
                  + "\"\n"
                    "  )\n"
                    "  port map (\n"
                    "    clk                         => bcd_clk,\n"
                    "    reset                       => bcd_reset,\n"
                    "    wreq_valid                  => bus_wreq_valid,\n"
                    "    wreq_ready                  => bus_wreq_ready,\n"
                    "    wreq_addr                   => bus_wreq_addr,\n"
                    "    wreq_len                    => bus_wreq_len,\n"
                    "    wreq_last                   => bus_wreq_last,\n"
                    "    wdat_valid                  => bus_wdat_valid,\n"
                    "    wdat_ready                  => bus_wdat_ready,\n"
                    "    wdat_data                   => bus_wdat_data,\n"
                    "    wdat_strobe                 => bus_wdat_strobe,\n"
                    "    wdat_last                   => bus_wdat_last,\n"
                    "    wrep_valid                  => bus_wrep_valid,\n"
                    "    wrep_ready                  => bus_wrep_ready,\n"
                    "    wrep_ok                     => bus_wrep_ok\n"
                    "  );");

    t.Replace("MST_WREQ_DECLARE",
              "      wr_mst_wreq_valid         : out std_logic;\n"
              "      wr_mst_wreq_ready         : in std_logic;\n"
              "      wr_mst_wreq_addr          : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);\n"
              "      wr_mst_wreq_len           : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);\n"
              "      wr_mst_wreq_last          : out std_logic;\n"
              "      wr_mst_wdat_valid         : out std_logic;\n"
              "      wr_mst_wdat_ready         : in std_logic;\n"
              "      wr_mst_wdat_data          : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);\n"
              "      wr_mst_wdat_strobe        : out std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0);\n"
              "      wr_mst_wdat_last          : out std_logic;"
              "      wr_mst_wrep_valid         : in  std_logic;\n"
              "      wr_mst_wrep_ready         : out std_logic;\n"
              "      wr_mst_wrep_ok            : in  std_logic;\n");

    t.Replace("MST_WREQ_INSTANTIATE",
              "      wr_mst_wreq_valid         => bus_wreq_valid,\n"
              "      wr_mst_wreq_ready         => bus_wreq_ready,\n"
              "      wr_mst_wreq_addr          => bus_wreq_addr,\n"
              "      wr_mst_wreq_len           => bus_wreq_len,\n"
              "      wr_mst_wreq_last          => bus_wreq_last,\n"
              "      wr_mst_wdat_valid         => bus_wdat_valid,\n"
              "      wr_mst_wdat_ready         => bus_wdat_ready,\n"
              "      wr_mst_wdat_data          => bus_wdat_data,\n"
              "      wr_mst_wdat_strobe        => bus_wdat_strobe,\n"
              "      wr_mst_wdat_last          => bus_wdat_last,\n"
              "      wr_mst_wrep_valid         => bus_wrep_valid,\n"
              "      wr_mst_wrep_ready         => bus_wrep_ready,\n"
              "      wr_mst_wrep_ok            => bus_wrep_ok,");
  } else {
    t.Replace("BUS_WRITE_SLAVE_MOCK", "");
    t.Replace("MST_WREQ_DECLARE", "");
    t.Replace("MST_WREQ_INSTANTIATE", "");
  }

  if (design.external) {
    auto ext = design.external.value();
    auto p_mantle = cerata::port("ext", ext, cerata::Port::Dir::IN);
    auto s_top = cerata::signal("ext", ext);
    cerata::Connect(p_mantle, s_top);

    auto inst_block = cerata::vhdl::Inst::GeneratePortMaps(*p_mantle);
    inst_block.indent = 3;
    inst_block << ",";

    auto decl_block = cerata::vhdl::Decl::Generate(*s_top, 1);

    t.Replace("EXTERNAL_SIG_DECL", decl_block.ToString());
    t.Replace("EXTERNAL_INST_MAP", inst_block.ToString());
  } else {
    t.Replace("EXTERNAL_SIG_DECL", "");
    t.Replace("EXTERNAL_INST_MAP", "");
  }

  for (auto &o : outputs) {
    o->flush();
    *o << t.ToString();
  }

  return t.ToString();
}

}  // namespace fletchgen::top
