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
use work.Utils.all;
use work.Arrow.all;
use work.Streams.all;

-- This entity converts read requests of a specific len and size on the slave port
-- to proper len and size on the master port. It assumed the addresses and lens are
-- already aligned to the master data width. So for example, if the slave width is
-- 32 bits and the master width is 512, the slave len should be integer multiples of
-- 16.
-- It also subtracts the Fletcher side len with 1 and decreases the number
-- of bits used to whatever is specified on the slave port.

entity axi_read_converter is
  generic (
    ADDR_WIDTH                  : natural;
    ID_WIDTH                    : natural;

    MASTER_DATA_WIDTH           : natural;
    MASTER_LEN_WIDTH            : natural;

    SLAVE_DATA_WIDTH            : natural;
    SLAVE_LEN_WIDTH             : natural;
    SLAVE_MAX_BURST             : natural;

    -- If the master bus already contains an output FIFO, this
    -- should be set to false to prevent redundant buffering
    -- of the master bus response channel
    ENABLE_FIFO                 : boolean := true

  );

  port (
    clk                         :  in std_logic;
    reset_n                     :  in std_logic;

    -- Fletcher bus
    -- Read address channel
    s_bus_req_addr              :  in std_logic_vector(ADDR_WIDTH-1 downto 0);
    s_bus_req_len               :  in std_logic_vector(SLAVE_LEN_WIDTH-1 downto 0);
    s_bus_req_valid             :  in std_logic;
    s_bus_req_ready             : out std_logic;

    -- Read data channel
    s_bus_rsp_data              : out std_logic_vector(SLAVE_DATA_WIDTH-1 downto 0);
    s_bus_rsp_last              : out std_logic;
    s_bus_rsp_valid             : out std_logic;
    s_bus_rsp_ready             :  in std_logic;

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
end entity axi_read_converter;

architecture rtl of axi_read_converter is
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

  -- StreamSerializer input & output
  signal ser_in_ready           : std_logic;
  signal ser_in_valid           : std_logic;
  signal ser_in_data            : std_logic_vector(MASTER_DATA_WIDTH-1 downto 0);
  signal ser_in_last            : std_logic;

  signal ser_out_ready          : std_logic;
  signal ser_out_valid          : std_logic;
  signal ser_out_data           : std_logic_vector(SLAVE_DATA_WIDTH-1 downto 0);
  signal ser_out_last           : std_logic;

  signal reset                  : std_logic;
begin
  -- If the ratio is 1, simply pass through, but convert to AXI len
  pass_through_gen: if RATIO = 1 generate
    s_bus_req_ready             <=  m_axi_arready;
    m_axi_araddr                <=  s_bus_req_addr;
    m_axi_arlen                 <=  slv(resize(u(s_bus_req_len) - 1, MASTER_LEN_WIDTH));
    m_axi_arvalid               <=  s_bus_req_valid;
    m_axi_arsize                <=  MASTER_SIZE;

    m_axi_rready                <=  s_bus_rsp_ready;
    s_bus_rsp_data              <=  m_axi_rdata;
    s_bus_rsp_last              <=  m_axi_rlast;
    s_bus_rsp_valid             <=  m_axi_rvalid;
  end generate;

  -- If the ratio is larger than 1, instantiate the serializer, etc..
  serialize_gen: if RATIO > 1 generate

    -- Reset
    reset                         <= '1' when reset_n = '0' else '0';

    -----------------------------------------------------------------------------
    -- Read Request channels
    -----------------------------------------------------------------------------
    -- From slave port to BusBuffer
    s_bus_req_ready               <= buf_mst_req_ready;
    buf_mst_req_valid             <= s_bus_req_valid;
    buf_mst_req_addr              <= s_bus_req_addr;
    -- Length conversion; get the number of full words on the master
    -- Thus we have to shift with the log2ceil of the ratio, but round up
    -- in case its not an integer multiple of the ratio.
    buf_mst_req_len               <= slv(resize(shift_right_round_up(u(s_bus_req_len), LEN_SHIFT), MASTER_LEN_WIDTH+1));

    -- From BusBuffer to AXI master port
    buf_slv_req_ready             <= m_axi_arready;
    m_axi_araddr                  <= buf_slv_req_addr;
    m_axi_arvalid                 <= buf_slv_req_valid;
    -- Convert to AXI spec:
    m_axi_arlen                   <= slv(resize(u(buf_slv_req_len) - 1, MASTER_LEN_WIDTH));
    m_axi_arsize                  <= MASTER_SIZE;
    -----------------------------------------------------------------------------
    -- Read Response channels
    -----------------------------------------------------------------------------
    -- From AXI master port to BusBuffer
    m_axi_rready                  <= buf_slv_resp_ready;
    buf_slv_resp_data             <= m_axi_rdata;
    buf_slv_resp_last             <= m_axi_rlast;
    buf_slv_resp_valid            <= m_axi_rvalid;

    -- From BusBuffer to StreamSerializer
    buf_mst_resp_ready            <= ser_in_ready;
    ser_in_valid                  <= buf_mst_resp_valid;
    ser_in_data                   <= buf_mst_resp_data;
    ser_in_last                   <= buf_mst_resp_last;

    -- From StreamSerializer to slave port
    ser_out_ready                 <= s_bus_rsp_ready;
    s_bus_rsp_valid               <= ser_out_valid;
    s_bus_rsp_data                <= ser_out_data;
    s_bus_rsp_last                <= ser_out_last;

    -----------------------------------------------------------------------------
    fifo_gen: if ENABLE_FIFO = true generate
    BusBuffer_inst : BusBuffer
    generic map (
      BUS_ADDR_WIDTH              => ADDR_WIDTH,
      BUS_LEN_WIDTH               => MASTER_LEN_WIDTH+1,
      BUS_DATA_WIDTH              => MASTER_DATA_WIDTH,
      FIFO_DEPTH                  => MASTER_MAX_BURST+1,
      RAM_CONFIG                  => "",
      REQ_IN_SLICE                => true,
      REQ_OUT_SLICE               => true,
      RESP_IN_SLICE               => true,
      RESP_OUT_SLICE              => true
    )
    port map (
      clk                         => clk,
      reset                       => reset,
      mst_req_valid               => buf_mst_req_valid,
      mst_req_ready               => buf_mst_req_ready,
      mst_req_addr                => buf_mst_req_addr,
      mst_req_len                 => buf_mst_req_len,
      mst_resp_valid              => buf_mst_resp_valid,
      mst_resp_ready              => buf_mst_resp_ready,
      mst_resp_data               => buf_mst_resp_data,
      mst_resp_last               => buf_mst_resp_last,
      slv_req_valid               => buf_slv_req_valid,
      slv_req_ready               => buf_slv_req_ready,
      slv_req_addr                => buf_slv_req_addr,
      slv_req_len                 => buf_slv_req_len,
      slv_resp_valid              => buf_slv_resp_valid,
      slv_resp_ready              => buf_slv_resp_ready,
      slv_resp_data               => buf_slv_resp_data,
      slv_resp_last               => buf_slv_resp_last
    );
    end generate;

    no_fifo_gen: if ENABLE_FIFO = false generate
      buf_mst_req_ready           <= buf_slv_req_ready;
      buf_slv_req_valid           <= buf_mst_req_valid;
      buf_slv_req_addr            <= buf_mst_req_addr;
      buf_slv_req_len             <= buf_mst_req_len;

      buf_mst_resp_ready          <= buf_slv_resp_ready;
      buf_slv_resp_valid          <= buf_mst_resp_valid;
      buf_slv_resp_data           <= buf_mst_resp_data;
      buf_slv_resp_last           <= buf_mst_resp_last;
    end generate;

    -----------------------------------------------------------------------------
    serializer: StreamSerializer
      generic map (
        DATA_WIDTH                => SLAVE_DATA_WIDTH,
        CTRL_WIDTH                => 0,
        IN_COUNT_MAX              => RATIO,
        IN_COUNT_WIDTH            => log2ceil(RATIO),
        OUT_COUNT_MAX             => 1,
        OUT_COUNT_WIDTH           => 1
      )
      port map (
        clk                       => clk,
        reset                     => not(reset_n),

        in_valid                  => ser_in_valid,
        in_ready                  => ser_in_ready,
        in_data                   => ser_in_data,
        in_last                   => ser_in_last,

        out_valid                 => ser_out_valid,
        out_ready                 => ser_out_ready,
        out_data                  => ser_out_data,
        out_last                  => ser_out_last
      );
  end generate;

end architecture rtl;

