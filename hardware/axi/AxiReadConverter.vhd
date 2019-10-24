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
use work.Stream_pkg.all;
use work.Interconnect_pkg.all;
use work.UtilInt_pkg.all;
use work.UtilConv_pkg.all;
use work.UtilMisc_pkg.all;

-- This entity converts read requests of a specific len and size on the slave port
-- to proper len and size on the master port. It assumed the addresses and lens are
-- already aligned to the master data width. So for example, if the slave width is
-- 32 bits and the master width is 512, the slave len should be integer multiples of
-- 16.
-- It also subtracts the Fletcher side len with 1 and decreases the number
-- of bits used to whatever is specified on the slave port.

entity AxiReadConverter is
  generic (
    ADDR_WIDTH                  : natural;

    MASTER_DATA_WIDTH           : natural;
    MASTER_LEN_WIDTH            : natural;

    SLAVE_DATA_WIDTH            : natural;
    SLAVE_LEN_WIDTH             : natural;
    SLAVE_MAX_BURST             : natural;

    -- If the master bus already contains an output FIFO, this
    -- should be set to false to prevent redundant buffering
    -- of the master bus response channel
    ENABLE_FIFO                 : boolean := true;
    
    -- Slice depth on each channel
    SLV_REQ_SLICE_DEPTH         : natural := 2;
    SLV_DAT_SLICE_DEPTH         : natural := 2;
    MST_REQ_SLICE_DEPTH         : natural := 2;
    MST_DAT_SLICE_DEPTH         : natural := 2
  );

  port (
    clk                         :  in std_logic;
    reset_n                     :  in std_logic;

    -- Fletcher bus
    -- Read address channel
    slv_bus_rreq_addr           :  in std_logic_vector(ADDR_WIDTH-1 downto 0);
    slv_bus_rreq_len            :  in std_logic_vector(SLAVE_LEN_WIDTH-1 downto 0);
    slv_bus_rreq_valid          :  in std_logic;
    slv_bus_rreq_ready          : out std_logic;

    -- Read data channel
    slv_bus_rdat_data           : out std_logic_vector(SLAVE_DATA_WIDTH-1 downto 0);
    slv_bus_rdat_last           : out std_logic;
    slv_bus_rdat_valid          : out std_logic;
    slv_bus_rdat_ready          :  in std_logic;

    -- AXI BUS
    -- Read address channel
    m_axi_araddr                : out std_logic_vector(ADDR_WIDTH-1 downto 0);
    m_axi_arlen                 : out std_logic_vector(MASTER_LEN_WIDTH-1 downto 0);
    m_axi_arvalid               : out std_logic;
    m_axi_arready               : in  std_logic;
    m_axi_arsize                : out std_logic_vector(2 downto 0);

    -- Read data channel
    m_axi_rdata                 : in  std_logic_vector(MASTER_DATA_WIDTH-1 downto 0);
    m_axi_rlast                 : in  std_logic;
    m_axi_rvalid                : in  std_logic;
    m_axi_rready                : out std_logic
  );
end entity AxiReadConverter;

architecture rtl of AxiReadConverter is

  -- The ratio between the master and slave
  constant RATIO                : natural := MASTER_DATA_WIDTH / SLAVE_DATA_WIDTH;

  -- The amount of shifting required on the len signal
  constant LEN_SHIFT            : natural := log2ceil(RATIO);

  -- AXI arsize is fixed corresponding to beat size = 1 bus data word
  constant MASTER_SIZE          : std_logic_vector(2 downto 0) := slv(u(log2ceil(MASTER_DATA_WIDTH/8),3));

  -- Maximum burst the FIFO should be able to handle
  constant MASTER_MAX_BURST     : natural := SLAVE_MAX_BURST / RATIO;

  -- Signal for length conversion
  signal new_len                : unsigned(SLAVE_LEN_WIDTH-1 downto 0);

  -- BusBuffer signals
  signal buf_mst_req_valid      : std_logic;
  signal buf_mst_req_ready      : std_logic;
  signal buf_mst_req_addr       : std_logic_vector(ADDR_WIDTH-1 downto 0);
  signal buf_mst_req_len        : std_logic_vector(MASTER_LEN_WIDTH downto 0);
  signal buf_mst_resp_valid     : std_logic;
  signal buf_mst_resp_ready     : std_logic;
  signal buf_mst_resp_data      : std_logic_vector(MASTER_DATA_WIDTH-1 downto 0);
  signal buf_mst_resp_last      : std_logic;
  signal buf_slv_req_valid      : std_logic;
  signal buf_slv_req_ready      : std_logic;
  signal buf_slv_req_addr       : std_logic_vector(ADDR_WIDTH-1 downto 0);
  signal buf_slv_req_len        : std_logic_vector(MASTER_LEN_WIDTH downto 0);
  signal buf_slv_resp_valid     : std_logic;
  signal buf_slv_resp_ready     : std_logic;
  signal buf_slv_resp_data      : std_logic_vector(MASTER_DATA_WIDTH-1 downto 0);
  signal buf_slv_resp_last      : std_logic;

  -- StreamGearboxSerializer input & output
  signal ser_in_ready           : std_logic;
  signal ser_in_valid           : std_logic;
  signal ser_in_data            : std_logic_vector(MASTER_DATA_WIDTH-1 downto 0);
  signal ser_in_last            : std_logic;

  signal ser_out_ready          : std_logic;
  signal ser_out_valid          : std_logic;
  signal ser_out_data           : std_logic_vector(SLAVE_DATA_WIDTH-1 downto 0);
  signal ser_out_last           : std_logic;

  signal reset                  : std_logic;

  -- Internal signals for slicing/buffering:

  -- Fletcher Read Address Channel Indices
  constant FRACI : nat_array := cumulative((
    1 => slv_bus_rreq_addr'length,
    0 => slv_bus_rreq_len'length
  ));

  -- Fletcher Read Data Channel Indices
  constant FRDCI : nat_array := cumulative((
    1 => slv_bus_rdat_data'length,
    0 => 1
  ));

  -- AXI Read Address Channel Indices
  constant ARACI : nat_array := cumulative((
    1 => m_axi_araddr'length,
    0 => m_axi_arlen'length
  ));

  -- AXI Read Data Channel Indices
  constant ARDCI : nat_array := cumulative((
    1 => m_axi_rdata'length,
    0 => 1
  ));

  signal int_slv_bus_rreq_addr  : std_logic_vector(ADDR_WIDTH-1 downto 0);
  signal int_slv_bus_rreq_len   : std_logic_vector(SLAVE_LEN_WIDTH-1 downto 0);
  signal int_slv_bus_rreq_valid : std_logic;
  signal int_slv_bus_rreq_ready : std_logic;
  signal int_slv_bus_rdat_data  : std_logic_vector(SLAVE_DATA_WIDTH-1 downto 0);
  signal int_slv_bus_rdat_last  : std_logic;
  signal int_slv_bus_rdat_valid : std_logic;
  signal int_slv_bus_rdat_ready : std_logic;
  signal int_m_axi_araddr       : std_logic_vector(ADDR_WIDTH-1 downto 0);
  signal int_m_axi_arlen        : std_logic_vector(MASTER_LEN_WIDTH-1 downto 0);
  signal int_m_axi_arvalid      : std_logic;
  signal int_m_axi_arready      : std_logic;
  signal int_m_axi_arsize       : std_logic_vector(2 downto 0);
  signal int_m_axi_rdata        : std_logic_vector(MASTER_DATA_WIDTH-1 downto 0);
  signal int_m_axi_rlast        : std_logic;
  signal int_m_axi_rvalid       : std_logic;
  signal int_m_axi_rready       : std_logic;

  signal int_slv_bus_rreq_all   : std_logic_vector(FRACI(2)-1 downto 0);
  signal int_slv_bus_rdat_all   : std_logic_vector(FRDCI(2)-1 downto 0);
  signal int_m_axi_arall        : std_logic_vector(ARACI(2)-1 downto 0);
  signal int_m_axi_rall         : std_logic_vector(ARDCI(2)-1 downto 0);
  signal slv_bus_rreq_all       : std_logic_vector(FRACI(2)-1 downto 0);
  signal slv_bus_rdat_all       : std_logic_vector(FRDCI(2)-1 downto 0);
  signal m_axi_arall            : std_logic_vector(ARACI(2)-1 downto 0);
  signal m_axi_rall             : std_logic_vector(ARDCI(2)-1 downto 0);

begin

  -- Active high reset
  reset                         <= '1' when reset_n = '0' else '0';

  -- Master ARSIZE is constant
  m_axi_arsize                  <= MASTER_SIZE;

  -- If the ratio is 1, simply pass through, but convert to AXI len
  pass_through_gen: if RATIO = 1 generate
    int_slv_bus_rreq_ready      <= int_m_axi_arready;
    int_m_axi_araddr            <= int_slv_bus_rreq_addr;
    int_m_axi_arlen             <= slv(resize(u(int_slv_bus_rreq_len) - 1, MASTER_LEN_WIDTH));
    int_m_axi_arvalid           <= int_slv_bus_rreq_valid;

    int_m_axi_rready            <= int_slv_bus_rdat_ready;
    int_slv_bus_rdat_data       <= int_m_axi_rdata;
    int_slv_bus_rdat_last       <= int_m_axi_rlast;
    int_slv_bus_rdat_valid      <= int_m_axi_rvalid;
  end generate;

  -- If the ratio is larger than 1, instantiate the serializer, etc..
  serialize_gen: if RATIO > 1 generate
    ---------------------------------------------------------------------------
    -- Read Request channels
    ---------------------------------------------------------------------------
    -- From slave port to BusBuffer
    int_slv_bus_rreq_ready      <= buf_mst_req_ready;
    buf_mst_req_valid           <= int_slv_bus_rreq_valid;
    buf_mst_req_addr            <= int_slv_bus_rreq_addr;
    -- Length conversion; get the number of full words on the master
    -- Thus we have to shift with the log2ceil of the ratio, but round up
    -- in case its not an integer multiple of the ratio.
    buf_mst_req_len             <= slv(resize(shift(u(int_slv_bus_rreq_len), -LEN_SHIFT, true), MASTER_LEN_WIDTH+1));

    -- From BusBuffer to AXI master port
    buf_slv_req_ready           <= int_m_axi_arready;
    int_m_axi_araddr            <= buf_slv_req_addr;
    int_m_axi_arvalid           <= buf_slv_req_valid;
    -- Convert to AXI spec:
    int_m_axi_arlen             <= slv(resize(u(buf_slv_req_len) - 1, MASTER_LEN_WIDTH));
    ---------------------------------------------------------------------------
    -- Read Response channels
    ---------------------------------------------------------------------------
    -- From AXI master port to BusBuffer
    int_m_axi_rready            <= buf_slv_resp_ready;
    buf_slv_resp_data           <= int_m_axi_rdata;
    buf_slv_resp_last           <= int_m_axi_rlast;
    buf_slv_resp_valid          <= int_m_axi_rvalid;

    -- From BusBuffer to StreamGearboxSerializer
    buf_mst_resp_ready          <= ser_in_ready;
    ser_in_valid                <= buf_mst_resp_valid;
    ser_in_data                 <= buf_mst_resp_data;
    ser_in_last                 <= buf_mst_resp_last;

    -- From StreamGearboxSerializer to slave port
    ser_out_ready               <= int_slv_bus_rdat_ready;
    int_slv_bus_rdat_valid      <= ser_out_valid;
    int_slv_bus_rdat_data       <= ser_out_data;
    int_slv_bus_rdat_last       <= ser_out_last;

    ---------------------------------------------------------------------------
    fifo_gen: if ENABLE_FIFO = true generate
    BusBuffer_inst : BusReadBuffer
    generic map (
      BUS_ADDR_WIDTH            => ADDR_WIDTH,
      BUS_LEN_WIDTH             => MASTER_LEN_WIDTH+1,
      BUS_DATA_WIDTH            => MASTER_DATA_WIDTH,
      FIFO_DEPTH                => MASTER_MAX_BURST+1,
      RAM_CONFIG                => "",
      SLV_REQ_SLICE             => true,
      MST_REQ_SLICE             => true,
      MST_DAT_SLICE             => true,
      SLV_DAT_SLICE             => true
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      slv_rreq_valid            => buf_mst_req_valid,
      slv_rreq_ready            => buf_mst_req_ready,
      slv_rreq_addr             => buf_mst_req_addr,
      slv_rreq_len              => buf_mst_req_len,
      slv_rdat_valid            => buf_mst_resp_valid,
      slv_rdat_ready            => buf_mst_resp_ready,
      slv_rdat_data             => buf_mst_resp_data,
      slv_rdat_last             => buf_mst_resp_last,
      mst_rreq_valid            => buf_slv_req_valid,
      mst_rreq_ready            => buf_slv_req_ready,
      mst_rreq_addr             => buf_slv_req_addr,
      mst_rreq_len              => buf_slv_req_len,
      mst_rdat_valid            => buf_slv_resp_valid,
      mst_rdat_ready            => buf_slv_resp_ready,
      mst_rdat_data             => buf_slv_resp_data,
      mst_rdat_last             => buf_slv_resp_last
    );
    end generate;

    no_fifo_gen: if ENABLE_FIFO = false generate
      buf_mst_req_ready         <= buf_slv_req_ready;
      buf_slv_req_valid         <= buf_mst_req_valid;
      buf_slv_req_addr          <= buf_mst_req_addr;
      buf_slv_req_len           <= buf_mst_req_len;

      buf_slv_resp_ready        <= buf_mst_resp_ready;
      buf_mst_resp_valid        <= buf_slv_resp_valid;
      buf_mst_resp_data         <= buf_slv_resp_data;
      buf_mst_resp_last         <= buf_slv_resp_last;
    end generate;
    ---------------------------------------------------------------------------
    serializer: StreamGearboxSerializer
      generic map (
        ELEMENT_WIDTH           => SLAVE_DATA_WIDTH,
        CTRL_WIDTH              => 0,
        IN_COUNT_MAX            => RATIO,
        IN_COUNT_WIDTH          => log2ceil(RATIO),
        OUT_COUNT_MAX           => 1,
        OUT_COUNT_WIDTH         => 1
      )
      port map (
        clk                     => clk,
        reset                   => reset,

        in_valid                => ser_in_valid,
        in_ready                => ser_in_ready,
        in_data                 => ser_in_data,
        in_last                 => ser_in_last,

        out_valid               => ser_out_valid,
        out_ready               => ser_out_ready,
        out_data                => ser_out_data,
        out_last                => ser_out_last
      );
  end generate;
  -----------------------------------------------------------------------------

  -- Fletcher read request slice ----------------------------------------------
  slv_bus_rreq_all              <= slv_bus_rreq_addr & slv_bus_rreq_len;

  frac_slice : StreamBuffer
    generic map (
      MIN_DEPTH                 => SLV_REQ_SLICE_DEPTH,
      DATA_WIDTH                => FRACI(2)
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_ready                  => slv_bus_rreq_ready,
      in_valid                  => slv_bus_rreq_valid,
      in_data                   => slv_bus_rreq_all,
      out_ready                 => int_slv_bus_rreq_ready,
      out_valid                 => int_slv_bus_rreq_valid,
      out_data                  => int_slv_bus_rreq_all
    );

  int_slv_bus_rreq_addr         <= int_slv_bus_rreq_all(FRACI(2)-1 downto FRACI(1));
  int_slv_bus_rreq_len          <= int_slv_bus_rreq_all(FRACI(1)-1 downto FRACI(0));

  -- Fletcher read data slice -------------------------------------------------
  int_slv_bus_rdat_all          <= int_slv_bus_rdat_data & int_slv_bus_rdat_last;

  frdc_slice : StreamBuffer
    generic map (
      MIN_DEPTH                 => SLV_DAT_SLICE_DEPTH,
      DATA_WIDTH                => FRDCI(2)
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_ready                  => int_slv_bus_rdat_ready,
      in_valid                  => int_slv_bus_rdat_valid,
      in_data                   => int_slv_bus_rdat_all,
      out_ready                 => slv_bus_rdat_ready,
      out_valid                 => slv_bus_rdat_valid,
      out_data                  => slv_bus_rdat_all
    );

  slv_bus_rdat_data             <= slv_bus_rdat_all(FRDCI(2)-1 downto FRDCI(1));
  slv_bus_rdat_last             <= slv_bus_rdat_all(                  FRDCI(0));

  -- AXI read address slice ---------------------------------------------------
  int_m_axi_arall               <= int_m_axi_araddr & int_m_axi_arlen;

  arac_slice : StreamBuffer
    generic map (
      MIN_DEPTH                 => MST_REQ_SLICE_DEPTH,
      DATA_WIDTH                => ARACI(2)
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_ready                  => int_m_axi_arready,
      in_valid                  => int_m_axi_arvalid,
      in_data                   => int_m_axi_arall,
      out_ready                 => m_axi_arready,
      out_valid                 => m_axi_arvalid,
      out_data                  => m_axi_arall
    );

  m_axi_araddr                  <= m_axi_arall(ARACI(2)-1 downto ARACI(1));
  m_axi_arlen                   <= m_axi_arall(ARACI(1)-1 downto ARACI(0));

  -- AXI read data slice ------------------------------------------------------
  m_axi_rall                    <= m_axi_rdata & m_axi_rlast;

  ardc_slice : StreamBuffer
    generic map (
      MIN_DEPTH                 => MST_DAT_SLICE_DEPTH,
      DATA_WIDTH                => ARDCI(2)
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_ready                  => m_axi_rready,
      in_valid                  => m_axi_rvalid,
      in_data                   => m_axi_rall,
      out_ready                 => int_m_axi_rready,
      out_valid                 => int_m_axi_rvalid,
      out_data                  => int_m_axi_rall
    );

  int_m_axi_rdata               <= int_m_axi_rall(ARDCI(2)-1 downto ARDCI(1));
  int_m_axi_rlast               <= int_m_axi_rall(                  ARDCI(0));

end architecture rtl;

