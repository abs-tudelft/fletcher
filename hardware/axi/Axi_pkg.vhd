-- Copyright 2018 Delft University of Technology
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

package Axi_pkg is

  component AxiReadConverter is
    generic (
      ADDR_WIDTH                : natural;
      MASTER_DATA_WIDTH         : natural;
      MASTER_LEN_WIDTH          : natural;
      SLAVE_DATA_WIDTH          : natural;
      SLAVE_LEN_WIDTH           : natural;
      SLAVE_MAX_BURST           : natural;
      ENABLE_FIFO               : boolean := true;
      SLV_REQ_SLICE_DEPTH       : natural := 2;
      SLV_DAT_SLICE_DEPTH       : natural := 2;
      MST_REQ_SLICE_DEPTH       : natural := 2;
      MST_DAT_SLICE_DEPTH       : natural := 2
    );

    port (
      clk                       : in  std_logic;
      reset_n                   : in  std_logic;
      slv_bus_rreq_addr         : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
      slv_bus_rreq_len          : in  std_logic_vector(SLAVE_LEN_WIDTH-1 downto 0);
      slv_bus_rreq_valid        : in  std_logic;
      slv_bus_rreq_ready        : out std_logic;
      slv_bus_rdat_data         : out std_logic_vector(SLAVE_DATA_WIDTH-1 downto 0);
      slv_bus_rdat_last         : out std_logic;
      slv_bus_rdat_valid        : out std_logic;
      slv_bus_rdat_ready        : in  std_logic;
      m_axi_araddr              : out std_logic_vector(ADDR_WIDTH-1 downto 0);
      m_axi_arlen               : out std_logic_vector(MASTER_LEN_WIDTH-1 downto 0);
      m_axi_arvalid             : out std_logic;
      m_axi_arready             : in  std_logic;
      m_axi_arsize              : out std_logic_vector(2 downto 0);
      m_axi_rdata               : in  std_logic_vector(MASTER_DATA_WIDTH-1 downto 0);
      m_axi_rlast               : in  std_logic;
      m_axi_rvalid              : in  std_logic;
      m_axi_rready              : out std_logic
    );
  end component;
  
  component AxiWriteConverter is
    generic (
      ADDR_WIDTH                : natural;
      MASTER_DATA_WIDTH         : natural;
      MASTER_LEN_WIDTH          : natural;
      SLAVE_DATA_WIDTH          : natural;
      SLAVE_LEN_WIDTH           : natural;
      SLAVE_MAX_BURST           : natural;
      ENABLE_FIFO               : boolean := true;
      SLV_REQ_SLICE_DEPTH       : natural := 2;
      SLV_DAT_SLICE_DEPTH       : natural := 2;
      SLV_REP_SLICE_DEPTH       : natural := 2;
      MST_REQ_SLICE_DEPTH       : natural := 2;
      MST_DAT_SLICE_DEPTH       : natural := 2;
      MST_REP_SLICE_DEPTH       : natural := 2
    );
    port (
      clk                       : in  std_logic;
      reset_n                   : in  std_logic;
      slv_bus_wreq_valid        : in  std_logic;
      slv_bus_wreq_ready        : out std_logic;
      slv_bus_wreq_addr         : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
      slv_bus_wreq_len          : in  std_logic_vector(SLAVE_LEN_WIDTH-1 downto 0);
      slv_bus_wreq_last         : in  std_logic;
      slv_bus_wdat_valid        : in  std_logic;
      slv_bus_wdat_ready        : out std_logic;
      slv_bus_wdat_data         : in  std_logic_vector(SLAVE_DATA_WIDTH-1 downto 0);
      slv_bus_wdat_strobe       : in  std_logic_vector(SLAVE_DATA_WIDTH/8-1 downto 0);
      slv_bus_wdat_last         : in  std_logic;
      slv_bus_wrep_valid        : out std_logic;
      slv_bus_wrep_ready        : in  std_logic;
      slv_bus_wrep_ok           : out std_logic;
      m_axi_awaddr              : out std_logic_vector(ADDR_WIDTH-1 downto 0);
      m_axi_awlen               : out std_logic_vector(MASTER_LEN_WIDTH-1 downto 0);
      m_axi_awvalid             : out std_logic;
      m_axi_awready             : in  std_logic;
      m_axi_awsize              : out std_logic_vector(2 downto 0);
      m_axi_awuser              : out std_logic_vector(0 downto 0);
      m_axi_wvalid              : out std_logic;
      m_axi_wready              : in  std_logic;
      m_axi_wdata               : out std_logic_vector(MASTER_DATA_WIDTH-1 downto 0);
      m_axi_wstrb               : out std_logic_vector(MASTER_DATA_WIDTH/8-1 downto 0);
      m_axi_wlast               : out std_logic;
      m_axi_bvalid              : in  std_logic;
      m_axi_bready              : out std_logic;
      m_axi_bresp               : in  std_logic_vector(1 downto 0)
    );
  end component;

  component AxiMmio is
    generic (
      BUS_ADDR_WIDTH            : natural := 32;
      BUS_DATA_WIDTH            : natural := 32;
      NUM_REGS                  : natural;
      REG_CONFIG                : string  := "";
      REG_RESET                 : string  := "";
      SLV_R_SLICE_DEPTH         : natural := 2;
      SLV_W_SLICE_DEPTH         : natural := 2
    );
    port (
      clk                       : in  std_logic;
      reset_n                   : in  std_logic;
      s_axi_awvalid             : in  std_logic;
      s_axi_awready             : out std_logic;
      s_axi_awaddr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      s_axi_wvalid              : in  std_logic;
      s_axi_wready              : out std_logic;
      s_axi_wdata               : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      s_axi_wstrb               : in  std_logic_vector((BUS_DATA_WIDTH/8)-1 downto 0);
      s_axi_bvalid              : out std_logic;
      s_axi_bready              : in  std_logic;
      s_axi_bresp               : out std_logic_vector(1 downto 0);
      s_axi_arvalid             : in  std_logic;
      s_axi_arready             : out std_logic;
      s_axi_araddr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      s_axi_rvalid              : out std_logic;
      s_axi_rready              : in  std_logic;
      s_axi_rdata               : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      s_axi_rresp               : out std_logic_vector(1 downto 0);
      regs_out                  : out std_logic_vector(BUS_DATA_WIDTH*NUM_REGS-1 downto 0);
      regs_in                   : in  std_logic_vector(BUS_DATA_WIDTH*NUM_REGS-1 downto 0);
      regs_in_en                : in  std_logic_vector(NUM_REGS-1 downto 0)
    );
  end component;

end Axi_pkg;
