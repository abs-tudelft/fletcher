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

#pragma once

namespace fletchgen::top {

// TODO(johanpel): Insert this template through resource linking.
/// AXI top-level template source.
static char axi_source[] =
    "-- Copyright 2018-2019 Delft University of Technology\n"
    "--\n"
    "-- Licensed under the Apache License, Version 2.0 (the \"License\");\n"
    "-- you may not use this file except in compliance with the License.\n"
    "-- You may obtain a copy of the License at\n"
    "--\n"
    "--     http://www.apache.org/licenses/LICENSE-2.0\n"
    "--\n"
    "-- Unless required by applicable law or agreed to in writing, software\n"
    "-- distributed under the License is distributed on an \"AS IS\" BASIS,\n"
    "-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.\n"
    "-- See the License for the specific language governing permissions and\n"
    "-- limitations under the License.\n"
    "\n"
    "library ieee;\n"
    "use ieee.std_logic_1164.all;\n"
    "use ieee.numeric_std.all;\n"
    "use ieee.std_logic_misc.all;\n"
    "\n"
    "library work;\n"
    "use work.Axi_pkg.all;\n"
    "use work.UtilInt_pkg.all;\n"
    "use work.UtilConv_pkg.all;\n"
    "use work.UtilMisc_pkg.all;\n"
    "\n"
    "-------------------------------------------------------------------------------\n"
    "-- AXI4 compatible top level for Fletcher generated accelerators.\n"
    "-------------------------------------------------------------------------------\n"
    "-- Requires an AXI4 port to host memory.\n"
    "-- Requires an AXI4-lite port from host for MMIO.\n"
    "-------------------------------------------------------------------------------\n"
    "entity AxiTop is\n"
    "  generic (\n"
    "    -- Accelerator properties\n"
    "    INDEX_WIDTH                 : natural := 32;\n"
    "    REG_WIDTH                   : natural := 32;\n"
    "    TAG_WIDTH                   : natural := 1;\n"
    "    -- AXI4 (full) bus properties for memory access.\n"
    "    BUS_ADDR_WIDTH              : natural := ${BUS_ADDR_WIDTH};\n"
    "    BUS_DATA_WIDTH              : natural := ${BUS_DATA_WIDTH};\n"
    "    BUS_LEN_WIDTH               : natural := ${BUS_LEN_WIDTH};\n"
    "    BUS_BURST_MAX_LEN           : natural := ${BUS_BURST_MAX_LEN};\n"
    "    BUS_BURST_STEP_LEN          : natural := ${BUS_BURST_STEP_LEN}\n"
    "  );\n"
    "\n"
    "  port (\n"
    "    -- Kernel clock domain.\n"
    "    kcd_clk                     : in  std_logic;\n"
    "    kcd_reset                   : in  std_logic;\n"
    "    \n"
    "    -- Bus clock domain.\n"
    "    bcd_clk                     : in  std_logic;\n"
    "    bcd_reset                   : in  std_logic;\n"
    "\n"
    "    ---------------------------------------------------------------------------\n"
    "    -- External signals\n"
    "    ---------------------------------------------------------------------------\n"
    "${EXTERNAL_PORT_DECL}\n"
    "    ---------------------------------------------------------------------------\n"
    "    -- AXI4 master as Host Memory Interface\n"
    "    ---------------------------------------------------------------------------\n"
    "    -- Read address channel\n"
    "    m_axi_araddr                : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);\n"
    "    m_axi_arlen                 : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);\n"
    "    m_axi_arvalid               : out std_logic := '0';\n"
    "    m_axi_arready               : in  std_logic;\n"
    "    m_axi_arsize                : out std_logic_vector(2 downto 0);\n"
    "\n"
    "    -- Read data channel\n"
    "    m_axi_rdata                 : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);\n"
    "    m_axi_rresp                 : in  std_logic_vector(1 downto 0);\n"
    "    m_axi_rlast                 : in  std_logic;\n"
    "    m_axi_rvalid                : in  std_logic;\n"
    "    m_axi_rready                : out std_logic := '0';\n"
    "\n"
    "    -- Write address channel\n"
    "    m_axi_awvalid               : out std_logic := '0';\n"
    "    m_axi_awready               : in  std_logic;\n"
    "    m_axi_awaddr                : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);\n"
    "    m_axi_awlen                 : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);\n"
    "    m_axi_awsize                : out std_logic_vector(2 downto 0);\n"
    "    m_axi_awuser                : out std_logic_vector(0 downto 0);\n"
    "\n"
    "    -- Write data channel\n"
    "    m_axi_wvalid                : out std_logic := '0';\n"
    "    m_axi_wready                : in  std_logic;\n"
    "    m_axi_wdata                 : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);\n"
    "    m_axi_wlast                 : out std_logic;\n"
    "    m_axi_wstrb                 : out std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0);\n"
    "\n"
    "    -- Write response channel\n"
    "    m_axi_bvalid                : in  std_logic;\n"
    "    m_axi_bready                : out std_logic;\n"
    "    m_axi_bresp                 : in  std_logic_vector(1 downto 0);\n"
    "    ---------------------------------------------------------------------------\n"
    "    -- AXI4-lite Slave as MMIO interface\n"
    "    ---------------------------------------------------------------------------\n"
    "    -- Write address channel\n"
    "    s_axi_awvalid               : in std_logic;\n"
    "    s_axi_awready               : out std_logic;\n"
    "    s_axi_awaddr                : in std_logic_vector(${MMIO_ADDR_WIDTH}-1 downto 0);\n"
    "\n"
    "    -- Write data channel\n"
    "    s_axi_wvalid                : in std_logic;\n"
    "    s_axi_wready                : out std_logic;\n"
    "    s_axi_wdata                 : in std_logic_vector(${MMIO_DATA_WIDTH}-1 downto 0);\n"
    "    s_axi_wstrb                 : in std_logic_vector((${MMIO_DATA_WIDTH}/8)-1 downto 0);\n"
    "\n"
    "    -- Write response channel\n"
    "    s_axi_bvalid                : out std_logic;\n"
    "    s_axi_bready                : in std_logic;\n"
    "    s_axi_bresp                 : out std_logic_vector(1 downto 0);\n"
    "\n"
    "    -- Read address channel\n"
    "    s_axi_arvalid               : in std_logic;\n"
    "    s_axi_arready               : out std_logic;\n"
    "    s_axi_araddr                : in std_logic_vector(${MMIO_ADDR_WIDTH}-1 downto 0);\n"
    "\n"
    "    -- Read data channel\n"
    "    s_axi_rvalid                : out std_logic;\n"
    "    s_axi_rready                : in std_logic;\n"
    "    s_axi_rdata                 : out std_logic_vector(${MMIO_DATA_WIDTH}-1 downto 0);\n"
    "    s_axi_rresp                 : out std_logic_vector(1 downto 0)\n"
    "  );\n"
    "end AxiTop;\n"
    "\n"
    "architecture Behavorial of AxiTop is\n"
    "\n"
    "  -----------------------------------------------------------------------------\n"
    "  -- Generated top-level wrapper component.\n"
    "  -----------------------------------------------------------------------------\n"
    "  ${MANTLE_DECL}"
    "  -----------------------------------------------------------------------------\n"
    "  -- Internal signals.  \n"
    "  \n"
    "  -- Active low reset for bus clock domain\n"
    "  signal bcd_reset_n            : std_logic;\n"
    "  \n"
    "  -- Bus signals to convert to AXI.\n"
    "  signal rd_mst_rreq_addr       : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);\n"
    "  signal rd_mst_rreq_len        : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);\n"
    "  signal rd_mst_rreq_valid      : std_logic;\n"
    "  signal rd_mst_rreq_ready      : std_logic;\n"
    "  signal rd_mst_rdat_data       : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);\n"
    "  signal rd_mst_rdat_last       : std_logic;\n"
    "  signal rd_mst_rdat_valid      : std_logic;\n"
    "  signal rd_mst_rdat_ready      : std_logic;\n"
    "  signal wr_mst_wreq_valid      : std_logic;\n"
    "  signal wr_mst_wreq_ready      : std_logic;\n"
    "  signal wr_mst_wreq_addr       : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);\n"
    "  signal wr_mst_wreq_len        : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);\n"
    "  signal wr_mst_wreq_last       : std_logic;\n"
    "  signal wr_mst_wdat_valid      : std_logic;\n"
    "  signal wr_mst_wdat_ready      : std_logic;\n"
    "  signal wr_mst_wdat_data       : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);\n"
    "  signal wr_mst_wdat_strobe     : std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0);\n"
    "  signal wr_mst_wdat_last       : std_logic;\n"
    "  signal wr_mst_wrep_valid      : std_logic;\n"
    "  signal wr_mst_wrep_ready      : std_logic;\n"
    "  signal wr_mst_wrep_ok         : std_logic;\n"
    "\n"
    "begin\n"
    "\n"
    "  -- Active low reset\n"
    "  bcd_reset_n <= not bcd_reset;\n"
    "\n"
    "  -----------------------------------------------------------------------------\n"
    "  -- Fletcher generated wrapper\n"
    "  -----------------------------------------------------------------------------\n"
    "  ${FLETCHER_WRAPPER_INST_NAME} : ${FLETCHER_WRAPPER_NAME}\n"
    "    generic map (\n"
    "      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,\n"
    "      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,\n"
    "      BUS_BURST_STEP_LEN        => BUS_BURST_STEP_LEN,\n"
    "      BUS_BURST_MAX_LEN         => BUS_BURST_MAX_LEN,\n"
    "      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,\n"
    "      INDEX_WIDTH               => INDEX_WIDTH,\n"
    "      TAG_WIDTH                 => TAG_WIDTH\n"
    "    )\n"
    "    port map (\n"
    "      kcd_clk                   => kcd_clk,\n"
    "      kcd_reset                 => kcd_reset,\n"
    "      bcd_clk                   => bcd_clk,\n"
    "      bcd_reset                 => bcd_reset,\n"
    "${EXTERNAL_INST_MAP}\n"
    "${MST_RREQ_INSTANTIATE}\n"
    "${MST_WREQ_INSTANTIATE}\n"
    "      mmio_awvalid              => s_axi_awvalid,\n"
    "      mmio_awready              => s_axi_awready,\n"
    "      mmio_awaddr               => s_axi_awaddr,\n"
    "      mmio_wvalid               => s_axi_wvalid,\n"
    "      mmio_wready               => s_axi_wready,\n"
    "      mmio_wdata                => s_axi_wdata,\n"
    "      mmio_wstrb                => s_axi_wstrb,\n"
    "      mmio_bvalid               => s_axi_bvalid,\n"
    "      mmio_bready               => s_axi_bready,\n"
    "      mmio_bresp                => s_axi_bresp,\n"
    "      mmio_arvalid              => s_axi_arvalid,\n"
    "      mmio_arready              => s_axi_arready,\n"
    "      mmio_araddr               => s_axi_araddr,\n"
    "      mmio_rvalid               => s_axi_rvalid,\n"
    "      mmio_rready               => s_axi_rready,\n"
    "      mmio_rdata                => s_axi_rdata,\n"
    "      mmio_rresp                => s_axi_rresp\n"
    "    );\n"
    "\n"
    "${AXI_READ_CONVERTER}\n"
    "${AXI_WRITE_CONVERTER}\n"
    "\n"
    "end architecture;";

}  // namespace fletchgen::top
