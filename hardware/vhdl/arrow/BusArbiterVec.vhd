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

library work;
use work.Streams.all;
use work.Utils.all;
use work.Arrow.all;

-- This unit acts as an arbiter for the bus system utilized by the
-- BufferReaders.

entity BusArbiterVec is
  generic (

    -- Bus address width.
    BUS_ADDR_WIDTH              : natural := 32;

    -- Bus burst length width.
    BUS_LEN_WIDTH               : natural := 8;

    -- Bus data width.
    BUS_DATA_WIDTH              : natural := 32;

    -- Number of bus masters to arbitrate between.
    NUM_MASTERS                 : natural := 2;

    -- Arbitration method. Must be "ROUND-ROBIN" or "FIXED". If fixed,
    -- lower-indexed masters take precedence.
    ARB_METHOD                  : string := "ROUND-ROBIN";

    -- Maximum number of outstanding requests. This is rounded upward to
    -- whatever is convenient internally.
    MAX_OUTSTANDING             : natural := 2;

    -- RAM configuration string for the outstanding request FIFO.
    RAM_CONFIG                  : string := "";

    -- Whether a register slice should be inserted into the bus request input
    -- streams.
    REQ_IN_SLICES               : boolean := false;

    -- Whether a register slice should be inserted into the bus request output
    -- stream.
    REQ_OUT_SLICE               : boolean := true;

    -- Whether a register slice should be inserted into the bus response input
    -- stream.
    RESP_IN_SLICE               : boolean := false;

    -- Whether a register slice should be inserted into the bus response output
    -- streams.
    RESP_OUT_SLICES             : boolean := true

  );
  port (

    -- Rising-edge sensitive clock and active-high synchronous reset for the
    -- bus and control logic side of the BufferReader.
    clk                         : in  std_logic;
    reset                       : in  std_logic;

    -- Slave port.
    slv_req_valid               : out std_logic;
    slv_req_ready               : in  std_logic;
    slv_req_addr                : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    slv_req_len                 : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
    slv_resp_valid              : in  std_logic;
    slv_resp_ready              : out std_logic;
    slv_resp_data               : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    slv_resp_last               : in  std_logic;

    -- Concatenated master ports.
    bmv_req_valid               : in  std_logic_vector(NUM_MASTERS-1 downto 0);
    bmv_req_ready               : out std_logic_vector(NUM_MASTERS-1 downto 0);
    bmv_req_addr                : in  std_logic_vector(NUM_MASTERS*BUS_ADDR_WIDTH-1 downto 0);
    bmv_req_len                 : in  std_logic_vector(NUM_MASTERS*BUS_LEN_WIDTH-1 downto 0);
    bmv_resp_valid              : out std_logic_vector(NUM_MASTERS-1 downto 0);
    bmv_resp_ready              : in  std_logic_vector(NUM_MASTERS-1 downto 0);
    bmv_resp_data               : out std_logic_vector(NUM_MASTERS*BUS_DATA_WIDTH-1 downto 0);
    bmv_resp_last               : out std_logic_vector(NUM_MASTERS-1 downto 0)

  );
end BusArbiterVec;

architecture Behavioral of BusArbiterVec is

  -- Width of the index stream.
  constant INDEX_WIDTH          : natural := max(1, log2ceil(NUM_MASTERS));

  -- Type declarations for busses.
  subtype bus_addr_type is std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  subtype bus_len_type  is std_logic_vector(BUS_LEN_WIDTH-1  downto 0);
  subtype bus_data_type is std_logic_vector(BUS_DATA_WIDTH-1 downto 0);

  type bus_addr_array is array (natural range <>) of bus_addr_type;
  type bus_len_array  is array (natural range <>) of bus_len_type;
  type bus_data_array is array (natural range <>) of bus_data_type;

  -- Bus request serialization indices.
  constant BQI : nat_array := cumulative((
    1 => BUS_ADDR_WIDTH,
    0 => BUS_LEN_WIDTH
  ));

  signal sreqi_sData            : std_logic_vector(BQI(BQI'high)-1 downto 0);
  signal sreqo_sData            : std_logic_vector(BQI(BQI'high)-1 downto 0);

  signal arbi_sData             : std_logic_vector(BQI(BQI'high)-1 downto 0);
  signal arbo_sData             : std_logic_vector(BQI(BQI'high)-1 downto 0);

  -- Bus response serialization indices.
  constant BPI : nat_array := cumulative((
    1 => BUS_DATA_WIDTH,
    0 => 1
  ));

  signal srespi_sData           : std_logic_vector(BPI(BPI'high)-1 downto 0);
  signal srespo_sData           : std_logic_vector(BPI(BPI'high)-1 downto 0);

  -- Copy of the bus master signals in the entity as an array.
  signal bm_req_valid           : std_logic_vector(0 to NUM_MASTERS-1);
  signal bm_req_ready           : std_logic_vector(0 to NUM_MASTERS-1);
  signal bm_req_addr            : bus_addr_array(0 to NUM_MASTERS-1);
  signal bm_req_len             : bus_len_array(0 to NUM_MASTERS-1);
  signal bm_resp_valid          : std_logic_vector(0 to NUM_MASTERS-1);
  signal bm_resp_ready          : std_logic_vector(0 to NUM_MASTERS-1);
  signal bm_resp_data           : bus_data_array(0 to NUM_MASTERS-1);
  signal bm_resp_last           : std_logic_vector(0 to NUM_MASTERS-1);

  -- Register-sliced bus master signals.
  signal bms_req_valid          : std_logic_vector(0 to NUM_MASTERS-1);
  signal bms_req_ready          : std_logic_vector(0 to NUM_MASTERS-1);
  signal bms_req_addr           : bus_addr_array(0 to NUM_MASTERS-1);
  signal bms_req_len            : bus_len_array(0 to NUM_MASTERS-1);
  signal bms_resp_valid         : std_logic_vector(0 to NUM_MASTERS-1);
  signal bms_resp_ready         : std_logic_vector(0 to NUM_MASTERS-1);
  signal bms_resp_data          : bus_data_array(0 to NUM_MASTERS-1);
  signal bms_resp_last          : std_logic_vector(0 to NUM_MASTERS-1);

  -- Register-sliced bus slave signals.
  signal bss_req_valid          : std_logic;
  signal bss_req_ready          : std_logic;
  signal bss_req_addr           : bus_addr_type;
  signal bss_req_len            : bus_len_type;
  signal bss_resp_valid         : std_logic;
  signal bss_resp_ready         : std_logic;
  signal bss_resp_data          : bus_data_type;
  signal bss_resp_last          : std_logic;

  -- Serialized arbiter input signals.
  signal arb_in_valid           : std_logic_vector(NUM_MASTERS-1 downto 0);
  signal arb_in_ready           : std_logic_vector(NUM_MASTERS-1 downto 0);
  signal arb_in_data            : std_logic_vector(BQI(BQI'high)*NUM_MASTERS-1 downto 0);

  -- Arbiter output stream handshake.
  signal arb_out_valid          : std_logic;
  signal arb_out_ready          : std_logic;

  -- Index stream stage A (between sync and buffer).
  signal idxA_valid             : std_logic;
  signal idxA_ready             : std_logic;
  signal idxA_index             : std_logic_vector(INDEX_WIDTH-1 downto 0);

  -- Index stream stage A (between buffer and sync).
  signal idxB_valid             : std_logic;
  signal idxB_ready             : std_logic;
  signal idxB_index             : std_logic_vector(INDEX_WIDTH-1 downto 0);
  signal idxB_enable            : std_logic_vector(NUM_MASTERS-1 downto 0);

  -- Demultiplexed serialized response stream handshake signals.
  signal demux_valid            : std_logic_vector(NUM_MASTERS-1 downto 0);
  signal demux_ready            : std_logic_vector(NUM_MASTERS-1 downto 0);

begin

  -- Connect the serialized master ports to the internal arrays for
  -- convenience.
  serdes_gen: for i in 0 to NUM_MASTERS-1 generate
  begin
    bm_req_valid  (i) <= bmv_req_valid (i);
    bmv_req_ready (i) <= bm_req_ready  (i);
    bm_req_addr   (i) <= bmv_req_addr  ((i+1)*BUS_ADDR_WIDTH-1 downto i*BUS_ADDR_WIDTH);
    bm_req_len    (i) <= bmv_req_len   ((i+1)*BUS_LEN_WIDTH-1  downto i*BUS_LEN_WIDTH);
    bmv_resp_valid(i) <= bm_resp_valid (i);
    bm_resp_ready (i) <= bmv_resp_ready(i);
    bmv_resp_data((i+1)*BUS_DATA_WIDTH-1 downto i*BUS_DATA_WIDTH)
                      <= bm_resp_data  (i);
    bmv_resp_last (i) <= bm_resp_last  (i);
  end generate;

  -- Instantiate register slices for the master ports.
  master_slice_gen: for i in 0 to NUM_MASTERS-1 generate
    signal reqi_sData           : std_logic_vector(BQI(BQI'high)-1 downto 0);
    signal reqo_sData           : std_logic_vector(BQI(BQI'high)-1 downto 0);
    signal respi_sData          : std_logic_vector(BPI(BPI'high)-1 downto 0);
    signal respo_sData          : std_logic_vector(BPI(BPI'high)-1 downto 0);
  begin

    -- Request register slice.
    req_buffer_inst: StreamBuffer
      generic map (
        MIN_DEPTH                       => sel(REQ_IN_SLICES, 2, 0),
        DATA_WIDTH                      => BQI(BQI'high)
      )
      port map (
        clk                             => clk,
        reset                           => reset,

        in_valid                        => bm_req_valid(i),
        in_ready                        => bm_req_ready(i),
        in_data                         => reqi_sData,

        out_valid                       => bms_req_valid(i),
        out_ready                       => bms_req_ready(i),
        out_data                        => reqo_sData
      );

    reqi_sData(BQI(2)-1 downto BQI(1))  <= bm_req_addr(i);
    reqi_sData(BQI(1)-1 downto BQI(0))  <= bm_req_len(i);

    bms_req_addr(i)                     <= reqo_sData(BQI(2)-1 downto BQI(1));
    bms_req_len(i)                      <= reqo_sData(BQI(1)-1 downto BQI(0));

    -- Response register slice.
    resp_buffer_inst: StreamBuffer
      generic map (
        MIN_DEPTH                       => sel(RESP_OUT_SLICES, 2, 0),
        DATA_WIDTH                      => BPI(BPI'high)
      )
      port map (
        clk                             => clk,
        reset                           => reset,

        in_valid                        => bms_resp_valid(i),
        in_ready                        => bms_resp_ready(i),
        in_data                         => respi_sData,

        out_valid                       => bm_resp_valid(i),
        out_ready                       => bm_resp_ready(i),
        out_data                        => respo_sData
      );

    respi_sData(BPI(2)-1 downto BPI(1)) <= bms_resp_data(i);
    respi_sData(BPI(0))                 <= bms_resp_last(i);

    bm_resp_data(i)                     <= respo_sData(BPI(2)-1 downto BPI(1));
    bm_resp_last(i)                     <= respo_sData(BPI(0));

  end generate;

  -- Instantiate slave request register slice.
  slv_req_buffer_inst: StreamBuffer
    generic map (
      MIN_DEPTH                         => sel(REQ_OUT_SLICE, 2, 0),
      DATA_WIDTH                        => BQI(BQI'high)
    )
    port map (
      clk                               => clk,
      reset                             => reset,

      in_valid                          => bss_req_valid,
      in_ready                          => bss_req_ready,
      in_data                           => sreqi_sData,

      out_valid                         => slv_req_valid,
      out_ready                         => slv_req_ready,
      out_data                          => sreqo_sData
    );

  sreqi_sData(BQI(2)-1 downto BQI(1))   <= bss_req_addr;
  sreqi_sData(BQI(1)-1 downto BQI(0))   <= bss_req_len;

  slv_req_addr                          <= sreqo_sData(BQI(2)-1 downto BQI(1));
  slv_req_len                           <= sreqo_sData(BQI(1)-1 downto BQI(0));

  -- Instantiate slave response register slice.
  slv_resp_buffer_inst: StreamBuffer
    generic map (
      MIN_DEPTH                         => sel(RESP_IN_SLICE, 2, 0),
      DATA_WIDTH                        => BPI(BPI'high)
    )
    port map (
      clk                               => clk,
      reset                             => reset,

      in_valid                          => slv_resp_valid,
      in_ready                          => slv_resp_ready,
      in_data                           => srespi_sData,

      out_valid                         => bss_resp_valid,
      out_ready                         => bss_resp_ready,
      out_data                          => srespo_sData
    );

  srespi_sData(BPI(2)-1 downto BPI(1))  <= slv_resp_data;
  srespi_sData(BPI(0))                  <= slv_resp_last;

  bss_resp_data                         <= srespo_sData(BPI(2)-1 downto BPI(1));
  bss_resp_last                         <= srespo_sData(BPI(0));

  -- Serialize/deserialize the arbiter input stream signals.
  bms2arb_proc: process (bms_req_valid, bms_req_addr, bms_req_len) is
  begin
    for i in 0 to NUM_MASTERS-1 loop
      arb_in_valid(i) <= bms_req_valid(i);
      arb_in_data(i*BQI(BQI'high)+BQI(2)-1 downto i*BQI(BQI'high)+BQI(1)) <= bms_req_addr(i);
      arb_in_data(i*BQI(BQI'high)+BQI(1)-1 downto i*BQI(BQI'high)+BQI(0)) <= bms_req_len(i);
    end loop;
  end process;
  arb2bms_proc: process (arb_in_ready) is
  begin
    for i in 0 to NUM_MASTERS-1 loop
      bms_req_ready(i) <= arb_in_ready(i);
    end loop;
  end process;

  -- Instantiate the stream arbiter.
  arb_inst: StreamArb
    generic map (
      NUM_INPUTS                        => NUM_MASTERS,
      INDEX_WIDTH                       => INDEX_WIDTH,
      DATA_WIDTH                        => BQI(BQI'high),
      ARB_METHOD                        => ARB_METHOD
    )
    port map (
      clk                               => clk,
      reset                             => reset,

      in_valid                          => arb_in_valid,
      in_ready                          => arb_in_ready,
      in_data                           => arb_in_data,

      out_valid                         => arb_out_valid,
      out_ready                         => arb_out_ready,
      out_data                          => arbo_sData,
      out_index                         => idxA_index
    );

  bss_req_addr                          <= arbo_sData(BQI(2)-1 downto BQI(1));
  bss_req_len                           <= arbo_sData(BQI(1)-1 downto BQI(0));

  -- Instantiate a stream synchronizer to split the slave request and index
  -- streams.
  arb_sync_inst: StreamSync
    generic map (
      NUM_INPUTS                        => 1,
      NUM_OUTPUTS                       => 2
    )
    port map (
      clk                               => clk,
      reset                             => reset,
      in_valid(0)                       => arb_out_valid,
      in_ready(0)                       => arb_out_ready,
      out_valid(1)                      => bss_req_valid,
      out_valid(0)                      => idxA_valid,
      out_ready(1)                      => bss_req_ready,
      out_ready(0)                      => idxA_ready
    );

  -- Instantiate the outstanding request buffer.
  index_buffer_inst: StreamBuffer
    generic map (
      MIN_DEPTH                         => MAX_OUTSTANDING,
      DATA_WIDTH                        => INDEX_WIDTH,
      RAM_CONFIG                        => RAM_CONFIG
    )
    port map (
      clk                               => clk,
      reset                             => reset,

      in_valid                          => idxA_valid,
      in_ready                          => idxA_ready,
      in_data                           => idxA_index,

      out_valid                         => idxB_valid,
      out_ready                         => idxB_ready,
      out_data                          => idxB_index
    );

  -- Decode the index signal to one-hot for the response synchronizer.
  index_to_oh_proc: process (idxB_index) is
  begin
    for i in 0 to NUM_MASTERS-1 loop
      if to_integer(unsigned(idxB_index)) = i then
        idxB_enable(i) <= '1';
      else
        idxB_enable(i) <= '0';
      end if;
    end loop;
  end process;

  -- Instantiate the response stream synchronizer. This synchronizer fullfills
  -- two functions: it synchronizes the index stream with the response stream
  -- (only popping from the index stream when the "last" flag is set in the
  -- response stream), and it demultiplexes the response data to the
  -- appropriate master ports.
  resp_sync_inst: StreamSync
    generic map (
      NUM_INPUTS                        => 2,
      NUM_OUTPUTS                       => NUM_MASTERS
    )
    port map (
      clk                               => clk,
      reset                             => reset,

      in_valid(1)                       => idxB_valid,
      in_valid(0)                       => bss_resp_valid,
      in_ready(1)                       => idxB_ready,
      in_ready(0)                       => bss_resp_ready,
      in_advance(1)                     => bss_resp_last,
      in_advance(0)                     => '1',

      out_valid                         => demux_valid,
      out_ready                         => demux_ready,
      out_enable                        => idxB_enable
    );

  -- Serialize/deserialize the demultiplexer signals. Also connect the data and
  -- last signals from the slave response slice directly to all the master
  -- reponse slices. Only the handshake signals differ here.
  demux2bms_proc: process (demux_valid, bss_resp_data, bss_resp_last) is
  begin
    for i in 0 to NUM_MASTERS-1 loop
      bms_resp_valid(i) <= demux_valid(i);
      bms_resp_data(i) <= bss_resp_data;
      bms_resp_last(i) <= bss_resp_last;
    end loop;
  end process;
  bms2demux_proc: process (bms_resp_ready) is
  begin
    for i in 0 to NUM_MASTERS-1 loop
      demux_ready(i) <= bms_resp_ready(i);
    end loop;
  end process;

end Behavioral;

