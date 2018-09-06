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

library work;
use work.axi.all;

-- AXI4 compatible top level for Fletcher generated accelerators.
entity axi_top is
  generic (
    -- Host bus properties
    BUS_ADDR_WIDTH              : natural := 64;
    BUS_DATA_WIDTH              : natural := 512;
    BUS_STROBE_WIDTH            : natural := 64;
    BUS_LEN_WIDTH               : natural := 8;
    BUS_BURST_MAX_LEN           : natural := 64;
    BUS_BURST_STEP_LEN          : natural := 1;
    
    -- MMIO bus properties
    SLV_BUS_ADDR_WIDTH          : natural := 32;
    SLV_BUS_DATA_WIDTH          : natural := 32;
  
    -- Arrow properties
    INDEX_WIDTH                 : natural := 32;
  
    -- Accelerator properties
    TAG_WIDTH                   : natural := 1;
    NUM_ARROW_BUFFERS           : natural := 1;
    NUM_USER_REGS               : natural := 0;
    NUM_REGS                    : natural := 8;
    REG_WIDTH                   : natural := SLV_BUS_DATA_WIDTH
  );

  port (
    acc_clk                     : in  std_logic;
    acc_reset                   : in  std_logic;
    bus_clk                     : in  std_logic;
    bus_reset_n                 : in  std_logic;

    ---------------------------------------------------------------------------
    -- AXI4 master as Host Memory Interface
    ---------------------------------------------------------------------------
    -- Read address channel
    m_axi_araddr                : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    m_axi_arlen                 : out std_logic_vector(7 downto 0);
    m_axi_arvalid               : out std_logic;
    m_axi_arready               : in  std_logic;
    m_axi_arsize                : out std_logic_vector(2 downto 0);

    -- Read data channel
    m_axi_rdata                 : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    m_axi_rresp                 : in  std_logic_vector(1 downto 0);
    m_axi_rlast                 : in  std_logic;
    m_axi_rvalid                : in  std_logic;
    m_axi_rready                : out std_logic;

    -- Write address channel
    m_axi_awvalid               : out std_logic;
    m_axi_awready               : in  std_logic;
    m_axi_awaddr                : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    m_axi_awlen                 : out std_logic_vector(7 downto 0);
    m_axi_awsize                : out std_logic_vector(2 downto 0);

    -- Write data channel
    m_axi_wvalid                : out std_logic;
    m_axi_wready                : in  std_logic;
    m_axi_wdata                 : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    m_axi_wlast                 : out std_logic;
    m_axi_wstrb                 : out std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0);

    ---------------------------------------------------------------------------
    -- AXI4-lite Slave as MMIO interface
    ---------------------------------------------------------------------------
    -- Write adress channel
    s_axi_awvalid               : in std_logic;
    s_axi_awready               : out std_logic;
    s_axi_awaddr                : in std_logic_vector(SLV_BUS_ADDR_WIDTH-1 downto 0);

    -- Write data channel
    s_axi_wvalid                : in std_logic;
    s_axi_wready                : out std_logic;
    s_axi_wdata                 : in std_logic_vector(SLV_BUS_DATA_WIDTH-1 downto 0);
    s_axi_wstrb                 : in std_logic_vector((SLV_BUS_DATA_WIDTH/8)-1 downto 0);

    -- Write response channel
    s_axi_bvalid                : out std_logic;
    s_axi_bready                : in std_logic;
    s_axi_bresp                 : out std_logic_vector(1 downto 0);

    -- Read address channel
    s_axi_arvalid               : in std_logic;
    s_axi_arready               : out std_logic;
    s_axi_araddr                : in std_logic_vector(SLV_BUS_ADDR_WIDTH-1 downto 0);

    -- Read data channel
    s_axi_rvalid                : out std_logic;
    s_axi_rready                : in std_logic;
    s_axi_rdata                 : out std_logic_vector(SLV_BUS_DATA_WIDTH-1 downto 0);
    s_axi_rresp                 : out std_logic_vector(1 downto 0)
  );
end axi_top;

architecture Behavorial of axi_top is

  -----------------------------------------------------------------------------
  -- Default wrapper component.
  -----------------------------------------------------------------------------
  component fletcher_wrapper is
    generic(
      BUS_DATA_WIDTH            : natural;
      BUS_ADDR_WIDTH            : natural;
      BUS_STROBE_WIDTH          : natural;
      BUS_LEN_WIDTH             : natural;
      BUS_BURST_STEP_LEN        : natural;
      BUS_BURST_MAX_LEN         : natural;
      INDEX_WIDTH               : natural;
      NUM_ARROW_BUFFERS         : natural;
      NUM_REGS                  : natural;
      NUM_USER_REGS             : natural;
      REG_WIDTH                 : natural;
      TAG_WIDTH                 : natural
    );
    port(
      acc_clk                   : in std_logic;
      acc_reset                 : in std_logic;
      bus_clk                   : in std_logic;
      bus_reset                 : in std_logic;
      mst_rreq_valid            : out std_logic;
      mst_rreq_ready            : in std_logic;
      mst_rreq_addr             : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      mst_rreq_len              : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
      mst_rdat_valid            : in std_logic;
      mst_rdat_ready            : out std_logic;
      mst_rdat_data             : in std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      mst_rdat_last             : in std_logic;
      mst_wreq_valid            : out std_logic;
      mst_wreq_ready            : in std_logic;
      mst_wreq_addr             : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      mst_wreq_len              : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
      mst_wdat_valid            : out std_logic;
      mst_wdat_ready            : in std_logic;
      mst_wdat_data             : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      mst_wdat_strobe           : out std_logic_vector(BUS_STROBE_WIDTH-1 downto 0);
      mst_wdat_last             : out std_logic;
      regs_in                   : in std_logic_vector(NUM_REGS*REG_WIDTH-1 downto 0);
      regs_out                  : out std_logic_vector(NUM_REGS*REG_WIDTH-1 downto 0);
      regs_out_en               : out std_logic_vector(NUM_REGS-1 downto 0)
    );
  end component;
  -----------------------------------------------------------------------------

  -- Fletcher bus signals
  signal bus_reset              : std_logic;

  signal bus_rreq_addr          : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal bus_rreq_len           : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
  signal bus_rreq_valid         : std_logic;
  signal bus_rreq_ready         : std_logic;

  signal bus_rdat_data          : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal bus_rdat_last          : std_logic;
  signal bus_rdat_valid         : std_logic;
  signal bus_rdat_ready         : std_logic;

  signal bus_wreq_valid         : std_logic;
  signal bus_wreq_ready         : std_logic;
  signal bus_wreq_addr          : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal bus_wreq_len           : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);

  signal bus_wdat_valid         : std_logic;
  signal bus_wdat_ready         : std_logic;
  signal bus_wdat_data          : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal bus_wdat_strobe        : std_logic_vector(BUS_STROBE_WIDTH-1 downto 0);
  signal bus_wdat_last          : std_logic;

  -- MMIO registers
  signal regs_in                : std_logic_vector(NUM_REGS*REG_WIDTH-1 downto 0);
  signal regs_out               : std_logic_vector(NUM_REGS*REG_WIDTH-1 downto 0);
  signal regs_out_en            : std_logic_vector(NUM_REGS-1 downto 0);
begin

  -- Active high reset
  bus_reset <= '1' when bus_reset_n = '0' else '0';

  -----------------------------------------------------------------------------
  -- Fletcher generated wrapper
  -----------------------------------------------------------------------------
  fletcher_wrapper_inst : fletcher_wrapper
    generic map (
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_STROBE_WIDTH          => BUS_STROBE_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_BURST_STEP_LEN        => BUS_BURST_STEP_LEN,
      BUS_BURST_MAX_LEN         => BUS_BURST_MAX_LEN,
      INDEX_WIDTH               => INDEX_WIDTH,
      NUM_ARROW_BUFFERS         => NUM_ARROW_BUFFERS,
      NUM_REGS                  => NUM_REGS,
      NUM_USER_REGS             => NUM_USER_REGS,
      REG_WIDTH                 => REG_WIDTH,
      TAG_WIDTH                 => TAG_WIDTH
    )
    port map (
      acc_clk                   => acc_clk,
      acc_reset                 => acc_reset,
      bus_clk                   => bus_clk,
      bus_reset                 => bus_reset,
      mst_rreq_valid            => bus_rreq_valid,
      mst_rreq_ready            => bus_rreq_ready,
      mst_rreq_addr             => bus_rreq_addr,
      mst_rreq_len              => bus_rreq_len,
      mst_rdat_valid            => bus_rdat_valid,
      mst_rdat_ready            => bus_rdat_ready,
      mst_rdat_data             => bus_rdat_data,
      mst_rdat_last             => bus_rdat_last,
      mst_wreq_valid            => bus_wreq_valid,
      mst_wreq_ready            => bus_wreq_ready,
      mst_wreq_addr             => bus_wreq_addr,
      mst_wreq_len              => bus_wreq_len,
      mst_wdat_valid            => bus_wdat_valid,
      mst_wdat_ready            => bus_wdat_ready,
      mst_wdat_data             => bus_wdat_data,
      mst_wdat_strobe           => bus_wdat_strobe,
      mst_wdat_last             => bus_wdat_last,
      regs_in                   => regs_in,
      regs_out                  => regs_out,
      regs_out_en               => regs_out_en
    );

  -----------------------------------------------------------------------------
  -- AXI read converter
  -----------------------------------------------------------------------------
  axi_read_conv_inst: axi_read_converter
    generic map (
      ADDR_WIDTH                => BUS_ADDR_WIDTH,
      MASTER_DATA_WIDTH         => BUS_DATA_WIDTH,
      MASTER_LEN_WIDTH          => BUS_LEN_WIDTH,
      SLAVE_DATA_WIDTH          => BUS_DATA_WIDTH,
      SLAVE_LEN_WIDTH           => BUS_LEN_WIDTH,
      SLAVE_MAX_BURST           => BUS_BURST_MAX_LEN,
      ENABLE_FIFO               => false
    )
    port map (
      clk                       => bus_clk,
      reset_n                   => bus_reset_n,
      slv_bus_rreq_addr         => bus_rreq_addr,
      slv_bus_rreq_len          => bus_rreq_len,
      slv_bus_rreq_valid        => bus_rreq_valid,
      slv_bus_rreq_ready        => bus_rreq_ready,
      slv_bus_rdat_data         => bus_rdat_data,
      slv_bus_rdat_last         => bus_rdat_last,
      slv_bus_rdat_valid        => bus_rdat_valid,
      slv_bus_rdat_ready        => bus_rdat_ready,
      m_axi_araddr              => m_axi_araddr,
      m_axi_arlen               => m_axi_arlen,
      m_axi_arvalid             => m_axi_arvalid,
      m_axi_arready             => m_axi_arready,
      m_axi_arsize              => m_axi_arsize,
      m_axi_rdata               => m_axi_rdata,
      m_axi_rlast               => m_axi_rlast,
      m_axi_rvalid              => m_axi_rvalid,
      m_axi_rready              => m_axi_rready
    );
    
  -----------------------------------------------------------------------------
  -- AXI write converter
  -----------------------------------------------------------------------------
  axi_write_conv_inst: axi_write_converter
    generic map (
      ADDR_WIDTH                => BUS_ADDR_WIDTH,
      MASTER_DATA_WIDTH         => BUS_DATA_WIDTH,
      MASTER_LEN_WIDTH          => BUS_LEN_WIDTH,
      SLAVE_DATA_WIDTH          => BUS_DATA_WIDTH,
      SLAVE_LEN_WIDTH           => BUS_LEN_WIDTH,
      SLAVE_MAX_BURST           => BUS_BURST_MAX_LEN,
      ENABLE_FIFO               => false
    )
    port map (
      clk                       => bus_clk,
      reset_n                   => bus_reset_n,
      slv_bus_wreq_addr         => bus_wreq_addr,
      slv_bus_wreq_len          => bus_wreq_len,
      slv_bus_wreq_valid        => bus_wreq_valid,
      slv_bus_wreq_ready        => bus_wreq_ready,
      slv_bus_wdat_data         => bus_wdat_data,
      slv_bus_wdat_strobe       => bus_wdat_strobe,
      slv_bus_wdat_last         => bus_wdat_last,
      slv_bus_wdat_valid        => bus_wdat_valid,
      slv_bus_wdat_ready        => bus_wdat_ready,
      m_axi_awaddr              => m_axi_awaddr,
      m_axi_awlen               => m_axi_awlen,
      m_axi_awvalid             => m_axi_awvalid,
      m_axi_awready             => m_axi_awready,
      m_axi_awsize              => m_axi_awsize,
      m_axi_wdata               => m_axi_wdata,
      m_axi_wstrb               => m_axi_wstrb,
      m_axi_wlast               => m_axi_wlast,
      m_axi_wvalid              => m_axi_wvalid,
      m_axi_wready              => m_axi_wready
    );

  -----------------------------------------------------------------------------
  -- AXI MMIO
  -----------------------------------------------------------------------------
  axi_mmio_inst : axi_mmio
    generic map (
      BUS_ADDR_WIDTH            => SLV_BUS_ADDR_WIDTH,
      BUS_DATA_WIDTH            => SLV_BUS_DATA_WIDTH,
      NUM_REGS                  => NUM_REGS
    )
    port map (
      clk                       => bus_clk,
      reset_n                   => bus_reset_n,
      s_axi_awvalid             => s_axi_awvalid,
      s_axi_awready             => s_axi_awready,
      s_axi_awaddr              => s_axi_awaddr,
      s_axi_wvalid              => s_axi_wvalid,
      s_axi_wready              => s_axi_wready,
      s_axi_wdata               => s_axi_wdata,
      s_axi_wstrb               => s_axi_wstrb,
      s_axi_bvalid              => s_axi_bvalid,
      s_axi_bready              => s_axi_bready,
      s_axi_bresp               => s_axi_bresp,
      s_axi_arvalid             => s_axi_arvalid,
      s_axi_arready             => s_axi_arready,
      s_axi_araddr              => s_axi_araddr,
      s_axi_rvalid              => s_axi_rvalid,
      s_axi_rready              => s_axi_rready,
      s_axi_rdata               => s_axi_rdata,
      s_axi_rresp               => s_axi_rresp,
      regs_out                  => regs_in,
      regs_in                   => regs_out,
      regs_in_en                => regs_out_en
    );

end architecture;
