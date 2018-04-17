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
-- This unit doesn't support strobe bits for anything but bytes only

entity axi_write_converter is
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
    ENABLE_FIFO                 : boolean := true

  );

  port (
    clk                         :  in std_logic;
    reset_n                     :  in std_logic;

    -- Fletcher bus
    -- Write address channel
    s_bus_wreq_valid            :  in std_logic;
    s_bus_wreq_ready            : out std_logic;
    s_bus_wreq_addr             :  in std_logic_vector(ADDR_WIDTH-1 downto 0);
    s_bus_wreq_len              :  in std_logic_vector(SLAVE_LEN_WIDTH-1 downto 0);

    -- Write data channel
    s_bus_wdat_valid            : in  std_logic;
    s_bus_wdat_ready            : out std_logic;
    s_bus_wdat_data             : in  std_logic_vector(SLAVE_DATA_WIDTH-1 downto 0);
    s_bus_wdat_strobe           : in  std_logic_vector(SLAVE_DATA_WIDTH/8-1 downto 0);
    s_bus_wdat_last             : in  std_logic;

    -- AXI BUS
    -- Read address channel
    m_axi_awaddr                : out std_logic_vector(ADDR_WIDTH-1 downto 0);
    m_axi_awlen                 : out std_logic_vector(MASTER_LEN_WIDTH-1 downto 0);
    m_axi_awvalid               : out std_logic;
    m_axi_awready               : in  std_logic;
    m_axi_awsize                : out std_logic_vector(2 downto 0);

    -- Read data channel
    m_axi_wvalid                : out std_logic;
    m_axi_wready                : in  std_logic;
    m_axi_wdata                 : out std_logic_vector(MASTER_DATA_WIDTH-1 downto 0);
    m_axi_wstrb                 : out std_logic_vector(MASTER_DATA_WIDTH/8-1 downto 0);
    m_axi_wlast                 : out std_logic
  );
end entity axi_write_converter;

architecture rtl of axi_write_converter is
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

  -- BusWriteBuffer signals
  signal buf_mst_wreq_valid     : std_logic;
  signal buf_mst_wreq_ready     : std_logic;
  signal buf_mst_wreq_addr      : std_logic_vector(ADDR_WIDTH-1 downto 0);
  signal buf_mst_wreq_len       : std_logic_vector(MASTER_LEN_WIDTH downto 0);
  signal buf_mst_wdat_valid     : std_logic;
  signal buf_mst_wdat_ready     : std_logic;
  signal buf_mst_wdat_data      : std_logic_vector(MASTER_DATA_WIDTH-1 downto 0);
  signal buf_mst_wdat_strobe    : std_logic_vector(MASTER_DATA_WIDTH/8-1 downto 0);
  signal buf_mst_wdat_last      : std_logic;

  signal buf_slv_wreq_valid     : std_logic;
  signal buf_slv_wreq_ready     : std_logic;
  signal buf_slv_wreq_addr      : std_logic_vector(ADDR_WIDTH-1 downto 0);
  signal buf_slv_wreq_len       : std_logic_vector(MASTER_LEN_WIDTH downto 0);
  signal buf_slv_wdat_valid     : std_logic;
  signal buf_slv_wdat_ready     : std_logic;
  signal buf_slv_wdat_data      : std_logic_vector(MASTER_DATA_WIDTH-1 downto 0);
  signal buf_slv_wdat_strobe    : std_logic_vector(MASTER_DATA_WIDTH/8-1 downto 0);
  signal buf_slv_wdat_last      : std_logic;

  -- StreamSerializer input & output for data
  signal ser_dat_i_ready        : std_logic;
  signal ser_dat_i_valid        : std_logic;
  signal ser_dat_i_data         : std_logic_vector(MASTER_DATA_WIDTH-1 downto 0);
  signal ser_dat_i_last         : std_logic;

  signal ser_dat_o_ready        : std_logic;
  signal ser_dat_o_valid        : std_logic;
  signal ser_dat_o_data         : std_logic_vector(SLAVE_DATA_WIDTH/8-1 downto 0);
  signal ser_dat_o_last         : std_logic;

  -- StreamSerializer input & output for strobe
  signal ser_stb_i_ready        : std_logic;
  signal ser_stb_i_valid        : std_logic;
  signal ser_stb_i_data         : std_logic_vector(MASTER_DATA_WIDTH/8-1 downto 0);
  signal ser_stb_i_last         : std_logic;

  signal ser_stb_o_ready        : std_logic;
  signal ser_stb_o_valid        : std_logic;
  signal ser_stb_o_data         : std_logic_vector(SLAVE_DATA_WIDTH/8-1 downto 0);
  signal ser_stb_o_last         : std_logic;

  signal reset                  : std_logic;
begin
  -- If the ratio is 1, simply pass through, but convert to AXI len
  pass_through_gen: if RATIO = 1 generate
    s_bus_wreq_ready            <= m_axi_awready;
    m_axi_awaddr                <= s_bus_wreq_addr;
    m_axi_awlen                 <= slv(resize(u(s_bus_wreq_len) - 1, MASTER_LEN_WIDTH));
    m_axi_awvalid               <= s_bus_wreq_valid;
    m_axi_awsize                <= MASTER_SIZE;

    s_bus_wdat_ready            <= m_axi_wready;
    m_axi_wdata                 <= s_bus_wdat_data;
    m_axi_wstrb                 <= s_bus_wdat_strobe;
    m_axi_wlast                 <= s_bus_wdat_last;
    m_axi_wvalid                <= s_bus_wdat_valid;
  end generate;

  -- If the ratio is larger than 1, instantiate the serializer, etc..
  serialize_gen: if RATIO > 1 generate

    -- Reset
    reset                         <= '1' when reset_n = '0' else '0';

    -----------------------------------------------------------------------------
    -- Write Request channels
    -----------------------------------------------------------------------------
    -- From slave port to BusBuffer
    s_bus_wreq_ready              <= buf_mst_wreq_ready;
    buf_mst_wreq_valid            <= s_bus_wreq_valid;
    buf_mst_wreq_addr             <= s_bus_wreq_addr;
    -- Length conversion; get the number of full words on the master
    -- Thus we have to shift with the log2ceil of the ratio, but round up
    -- in case its not an integer multiple of the ratio.
    buf_mst_wreq_len              <= slv(resize(shift_right_round_up(u(s_bus_wreq_len), LEN_SHIFT), MASTER_LEN_WIDTH+1));

    -- From BusBuffer to AXI master port
    buf_slv_wreq_ready            <= m_axi_awready;
    m_axi_awaddr                  <= buf_slv_wreq_addr;
    m_axi_awvalid                 <= buf_slv_wreq_valid;
    -- Convert to AXI spec:
    m_axi_awlen                   <= slv(resize(u(buf_slv_wreq_len) - 1, MASTER_LEN_WIDTH));
    m_axi_awsize                  <= MASTER_SIZE;
    -----------------------------------------------------------------------------
    -- Write Data channel
    -----------------------------------------------------------------------------
    -- From slave port to StreamSerializer
    ser_dat_i_data                <= s_bus_wdat_data;
    ser_dat_i_last                <= s_bus_wdat_last;
    
    ser_stb_i_data                <= s_bus_wdat_strobe;
    ser_stb_i_last                <= s_bus_wdat_last;
    
    -- Split the write data stream into data and strobe for serialization
    wdat_split: StreamSync
      generic map (
        NUM_INPUTS              => 1,
        NUM_OUTPUTS             => 2
      )
      port map (
        clk                     => clk,
        reset                   => reset,
        in_valid(0)             => s_bus_wdat_valid,
        in_ready(0)             => s_bus_wdat_ready,
        out_valid(0)            => ser_dat_i_valid,
        out_valid(1)            => ser_stb_i_valid,
        out_ready(0)            => ser_dat_i_ready,
        out_ready(1)            => ser_stb_i_ready
      );
    
    -- Serialize the data
    data_serializer: StreamSerializer
      generic map (
        DATA_WIDTH              => SLAVE_DATA_WIDTH,
        CTRL_WIDTH              => 0,
        IN_COUNT_MAX            => RATIO,
        IN_COUNT_WIDTH          => log2ceil(RATIO),
        OUT_COUNT_MAX           => 1,
        OUT_COUNT_WIDTH         => 1
      )
      port map (
        clk                     => clk,
        reset                   => reset,

        in_valid                => ser_dat_i_valid,
        in_ready                => ser_dat_i_ready,
        in_data                 => ser_dat_i_data,
        in_last                 => ser_dat_i_last,

        out_valid               => ser_dat_o_valid,
        out_ready               => ser_dat_o_ready,
        out_data                => ser_dat_o_data,
        out_last                => ser_dat_o_last
      );
      
    -- Serialize the strobe
    strobe_serializer: StreamSerializer
      generic map (
        DATA_WIDTH              => SLAVE_DATA_WIDTH/8,
        CTRL_WIDTH              => 0,
        IN_COUNT_MAX            => RATIO,
        IN_COUNT_WIDTH          => log2ceil(RATIO),
        OUT_COUNT_MAX           => 1,
        OUT_COUNT_WIDTH         => 1
      )
      port map (
        clk                     => clk,
        reset                   => reset,

        in_valid                => ser_stb_i_valid,
        in_ready                => ser_stb_i_ready,
        in_data                 => ser_stb_i_data,
        in_last                 => ser_stb_i_last,

        out_valid               => ser_stb_o_valid,
        out_ready               => ser_stb_o_ready,
        out_data                => ser_stb_o_data,
        out_last                => ser_stb_o_last
      );
      
    -- Join the strobe and data streams
    wdat_join: StreamSync
      generic map (
        NUM_INPUTS              => 2,
        NUM_OUTPUTS             => 1
      )
      port map (
        clk                     => clk,
        reset                   => reset,
        in_valid(0)             => ser_dat_o_valid,
        in_valid(1)             => ser_stb_o_valid,
        in_ready(0)             => ser_dat_o_ready,
        in_ready(1)             => ser_stb_o_ready,
        out_valid(0)            => buf_mst_wdat_valid,
        out_ready(0)            => buf_mst_wdat_ready
      );
      
        
    -- From StreamSerializer to BusBuffer
    buf_mst_wdat_data           <= ser_dat_o_data;
    buf_mst_wdat_strobe         <= ser_stb_o_data;
    buf_mst_wdat_last           <= ser_dat_o_last and ser_stb_o_last;
        
    ---------------------------------------------------------------------------
    fifo_gen: if ENABLE_FIFO = true generate
      -- Instantiate a FIFO
      BusWriteBuffer_inst : BusWriteBuffer
        generic map (
          BUS_ADDR_WIDTH        => ADDR_WIDTH,
          BUS_LEN_WIDTH         => MASTER_LEN_WIDTH+1,
          BUS_DATA_WIDTH        => MASTER_DATA_WIDTH,
          BUS_STROBE_WIDTH      => MASTER_DATA_WIDTH/8,
          FIFO_DEPTH            => MASTER_MAX_BURST+1
        )                           
        port map (                  
          clk                   => clk,
          reset                 => reset,
          mst_wreq_valid        => buf_mst_wreq_valid,
          mst_wreq_ready        => buf_mst_wreq_ready,
          mst_wreq_addr         => buf_mst_wreq_addr,
          mst_wreq_len          => buf_mst_wreq_len,
          mst_wdat_valid        => buf_mst_wdat_valid,
          mst_wdat_ready        => buf_mst_wdat_ready,
          mst_wdat_data         => buf_mst_wdat_data,
          mst_wdat_strobe       => buf_mst_wdat_strobe,
          mst_wdat_last         => buf_mst_wdat_last,
          slv_wreq_valid        => buf_slv_wreq_valid,
          slv_wreq_ready        => buf_slv_wreq_ready,
          slv_wreq_addr         => buf_slv_wreq_addr,
          slv_wreq_len          => buf_slv_wreq_len,
          slv_wdat_valid        => buf_slv_wdat_valid,
          slv_wdat_ready        => buf_slv_wdat_ready,
          slv_wdat_data         => buf_slv_wdat_data,
          slv_wdat_strobe       => buf_slv_wdat_strobe,
          slv_wdat_last         => buf_slv_wdat_last
        );
    end generate;
    
    no_fifo_gen: if ENABLE_FIFO = false generate
      -- No FIFO, just pass through the channels
      buf_slv_wreq_valid        <= buf_mst_wreq_valid;
      buf_mst_wreq_ready        <= buf_slv_wreq_ready;
      buf_slv_wreq_addr         <= buf_mst_wreq_addr;
      buf_slv_wreq_len          <= buf_mst_wreq_len;

      buf_mst_wdat_valid        <= buf_slv_wdat_valid;
      buf_slv_wdat_ready        <= buf_mst_wdat_ready;
      buf_mst_wdat_data         <= buf_slv_wdat_data;
      buf_mst_wdat_strobe       <= buf_slv_wdat_strobe;
      buf_mst_wdat_last         <= buf_slv_wdat_last;
    end generate;
    
      -- Write data channel BusWriteBuffer to AXI Master Port
    m_axi_wvalid                <= buf_slv_wdat_valid;
    buf_slv_wdat_ready          <= m_axi_wready;
    m_axi_wdata                 <= buf_slv_wdat_data;
    m_axi_wstrb                 <= buf_slv_wdat_strobe;
    m_axi_wlast                 <= buf_slv_wdat_last;
    
  end generate;
  
end architecture rtl;

