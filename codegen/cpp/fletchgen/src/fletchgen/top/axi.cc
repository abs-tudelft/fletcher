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

#include "fletchgen/top/axi.h"

#include <cerata/api.h>
#include <memory>

#include "fletchgen/top/axi_template.h"
#include "fletchgen/mantle.h"

namespace fletchgen::top {

using cerata::vhdl::Template;

std::string GenerateAXITop(const Mantle &mantle, const std::vector<std::ostream *> &outputs) {
  // Template for AXI top level
  auto t = Template::FromString(axi_source);

  // Bus properties
  t.Replace("BUS_ADDR_WIDTH", 64);
  t.Replace("BUS_DATA_WIDTH", 512);
  t.Replace("BUS_STROBE_WIDTH", 512 / 8);
  t.Replace("BUS_LEN_WIDTH", 8);
  t.Replace("BUS_BURST_STEP_LEN", 1);
  t.Replace("BUS_BURST_MAX_LEN", 64);

  // MMIO properties
  t.Replace("MMIO_ADDR_WIDTH", 32);
  t.Replace("MMIO_DATA_WIDTH", 32);

  // Do not change this order, TODO: fix this in replacement code
  t.Replace("FLETCHER_WRAPPER_NAME", mantle.name());
  t.Replace("FLETCHER_WRAPPER_INST_NAME", mantle.name() + "_inst");

  if (mantle.schema_set().RequiresReading()) {
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
              "      rd_mst_rreq_valid         => rd_mst_rreq_valid,\n"
              "      rd_mst_rreq_ready         => rd_mst_rreq_ready,\n"
              "      rd_mst_rreq_addr          => rd_mst_rreq_addr,\n"
              "      rd_mst_rreq_len           => rd_mst_rreq_len,\n"
              "      rd_mst_rdat_valid         => rd_mst_rdat_valid,\n"
              "      rd_mst_rdat_ready         => rd_mst_rdat_ready,\n"
              "      rd_mst_rdat_data          => rd_mst_rdat_data,\n"
              "      rd_mst_rdat_last          => rd_mst_rdat_last,");

    t.Replace("AXI_READ_CONVERTER",
              "  -----------------------------------------------------------------------------\n"
              "  -- AXI read converter\n"
              "  -----------------------------------------------------------------------------\n"
              "  -- Buffering bursts is disabled (ENABLE_FIFO=false) because BufferReaders\n"
              "  -- are already able to absorb full bursts.\n"
              "  axi_read_conv_inst: AxiReadConverter\n"
              "    generic map (\n"
              "      ADDR_WIDTH                => BUS_ADDR_WIDTH,\n"
              "      MASTER_DATA_WIDTH         => BUS_DATA_WIDTH,\n"
              "      MASTER_LEN_WIDTH          => BUS_LEN_WIDTH,\n"
              "      SLAVE_DATA_WIDTH          => BUS_DATA_WIDTH,\n"
              "      SLAVE_LEN_WIDTH           => BUS_LEN_WIDTH,\n"
              "      SLAVE_MAX_BURST           => BUS_BURST_MAX_LEN,\n"
              "      ENABLE_FIFO               => false,\n"
              "      SLV_REQ_SLICE_DEPTH       => 0,\n"
              "      SLV_DAT_SLICE_DEPTH       => 0,\n"
              "      MST_REQ_SLICE_DEPTH       => 0,\n"
              "      MST_DAT_SLICE_DEPTH       => 0\n"
              "    )\n"
              "    port map (\n"
              "      clk                       => bcd_clk,\n"
              "      reset_n                   => bcd_reset_n,\n"
              "      slv_bus_rreq_addr         => rd_mst_rreq_addr,\n"
              "      slv_bus_rreq_len          => rd_mst_rreq_len,\n"
              "      slv_bus_rreq_valid        => rd_mst_rreq_valid,\n"
              "      slv_bus_rreq_ready        => rd_mst_rreq_ready,\n"
              "      slv_bus_rdat_data         => rd_mst_rdat_data,\n"
              "      slv_bus_rdat_last         => rd_mst_rdat_last,\n"
              "      slv_bus_rdat_valid        => rd_mst_rdat_valid,\n"
              "      slv_bus_rdat_ready        => rd_mst_rdat_ready,\n"
              "      m_axi_araddr              => m_axi_araddr,\n"
              "      m_axi_arlen               => m_axi_arlen,\n"
              "      m_axi_arvalid             => m_axi_arvalid,\n"
              "      m_axi_arready             => m_axi_arready,\n"
              "      m_axi_arsize              => m_axi_arsize,\n"
              "      m_axi_rdata               => m_axi_rdata,\n"
              "      m_axi_rlast               => m_axi_rlast,\n"
              "      m_axi_rvalid              => m_axi_rvalid,\n"
              "      m_axi_rready              => m_axi_rready\n"
              "    );");
  } else {
    t.Replace("MST_RREQ_DECLARE", "");
    t.Replace("MST_RREQ_INSTANTIATE", "");
    t.Replace("AXI_READ_CONVERTER", "");
  }

  if (mantle.schema_set().RequiresWriting()) {
    t.Replace("MST_WREQ_DECLARE",
              "      wr_mst_wreq_valid         : out std_logic;\n"
              "      wr_mst_wreq_ready         : in std_logic;\n"
              "      wr_mst_wreq_addr          : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);\n"
              "      wr_mst_wreq_len           : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);\n"
              "      wr_mst_wdat_valid         : out std_logic;\n"
              "      wr_mst_wdat_ready         : in std_logic;\n"
              "      wr_mst_wdat_data          : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);\n"
              "      wr_mst_wdat_strobe        : out std_logic_vector(BUS_STROBE_WIDTH-1 downto 0);\n"
              "      wr_mst_wdat_last          : out std_logic;");

    t.Replace("MST_WREQ_INSTANTIATE",
              "      wr_mst_wreq_valid         => wr_mst_wreq_valid,\n"
              "      wr_mst_wreq_ready         => wr_mst_wreq_ready,\n"
              "      wr_mst_wreq_addr          => wr_mst_wreq_addr,\n"
              "      wr_mst_wreq_len           => wr_mst_wreq_len,\n"
              "      wr_mst_wdat_valid         => wr_mst_wdat_valid,\n"
              "      wr_mst_wdat_ready         => wr_mst_wdat_ready,\n"
              "      wr_mst_wdat_data          => wr_mst_wdat_data,\n"
              "      wr_mst_wdat_strobe        => wr_mst_wdat_strobe,\n"
              "      wr_mst_wdat_last          => wr_mst_wdat_last,");
    t.Replace("AXI_WRITE_CONVERTER",
              "  -----------------------------------------------------------------------------\n"
              "  -- AXI write converter\n"
              "  -----------------------------------------------------------------------------\n"
              "  -- Buffering bursts is disabled (ENABLE_FIFO=false) because BufferWriters\n"
              "  -- are already able to absorb full bursts.\n"
              "  axi_write_conv_inst: AxiWriteConverter\n"
              "    generic map (\n"
              "      ADDR_WIDTH                => BUS_ADDR_WIDTH,\n"
              "      MASTER_DATA_WIDTH         => BUS_DATA_WIDTH,\n"
              "      MASTER_LEN_WIDTH          => BUS_LEN_WIDTH,\n"
              "      SLAVE_DATA_WIDTH          => BUS_DATA_WIDTH,\n"
              "      SLAVE_LEN_WIDTH           => BUS_LEN_WIDTH,\n"
              "      SLAVE_MAX_BURST           => BUS_BURST_MAX_LEN,\n"
              "      ENABLE_FIFO               => false,\n"
              "      SLV_REQ_SLICE_DEPTH       => 0,\n"
              "      SLV_DAT_SLICE_DEPTH       => 0,\n"
              "      MST_REQ_SLICE_DEPTH       => 0,\n"
              "      MST_DAT_SLICE_DEPTH       => 0\n"
              "    )\n"
              "    port map (\n"
              "      clk                       => bcd_clk,\n"
              "      reset_n                   => bcd_reset_n,\n"
              "      slv_bus_wreq_addr         => wr_mst_wreq_addr,\n"
              "      slv_bus_wreq_len          => wr_mst_wreq_len,\n"
              "      slv_bus_wreq_valid        => wr_mst_wreq_valid,\n"
              "      slv_bus_wreq_ready        => wr_mst_wreq_ready,\n"
              "      slv_bus_wdat_data         => wr_mst_wdat_data,\n"
              "      slv_bus_wdat_strobe       => wr_mst_wdat_strobe,\n"
              "      slv_bus_wdat_last         => wr_mst_wdat_last,\n"
              "      slv_bus_wdat_valid        => wr_mst_wdat_valid,\n"
              "      slv_bus_wdat_ready        => wr_mst_wdat_ready,\n"
              "      m_axi_awaddr              => m_axi_awaddr,\n"
              "      m_axi_awlen               => m_axi_awlen,\n"
              "      m_axi_awvalid             => m_axi_awvalid,\n"
              "      m_axi_awready             => m_axi_awready,\n"
              "      m_axi_awsize              => m_axi_awsize,\n"
              "      m_axi_wdata               => m_axi_wdata,\n"
              "      m_axi_wstrb               => m_axi_wstrb,\n"
              "      m_axi_wlast               => m_axi_wlast,\n"
              "      m_axi_wvalid              => m_axi_wvalid,\n"
              "      m_axi_wready              => m_axi_wready\n"
              "    );");
  } else {
    t.Replace("MST_WREQ_DECLARE", "");
    t.Replace("MST_WREQ_INSTANTIATE", "");
    t.Replace("AXI_WRITE_CONVERTER", "");
  }

  for (auto &o : outputs) {
    o->flush();
    *o << t.ToString();
  }

  return t.ToString();
}

}  // namespace fletchgen::top
