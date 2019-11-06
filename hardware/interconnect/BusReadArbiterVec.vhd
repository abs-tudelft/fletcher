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
use work.Stream_pkg.all;
use work.Interconnect_pkg.all;
use work.UtilInt_pkg.all;
use work.UtilMisc_pkg.all;

-- This unit acts as an arbiter for the bus system utilized by the
-- BufferReaders.

entity BusReadArbiterVec is
  generic (

    -- Bus address width.
    BUS_ADDR_WIDTH              : natural := 32;

    -- Bus burst length width.
    BUS_LEN_WIDTH               : natural := 8;

    -- Bus data width.
    BUS_DATA_WIDTH              : natural := 32;

    -- Number of bus masters to arbitrate between.
    NUM_SLAVE_PORTS             : natural := 2;

    -- Arbitration method. Must be "ROUND-ROBIN" or "FIXED". If fixed,
    -- lower-indexed masters take precedence.
    ARB_METHOD                  : string := "ROUND-ROBIN";

    -- Maximum number of outstanding requests. This is rounded upward to
    -- whatever is convenient internally.
    MAX_OUTSTANDING             : natural := 2;

    -- RAM configuration string for the outstanding request FIFO.
    RAM_CONFIG                  : string := "";

    -- Whether a register slice should be inserted into the slave request ports
    SLV_REQ_SLICES              : boolean := false;

    -- Whether a register slice should be inserted into the master request port
    MST_REQ_SLICE               : boolean := true;

    -- Whether a register slice should be inserted into the master data port
    MST_DAT_SLICE               : boolean := false;

    -- Whether a register slice should be inserted into the slave data ports
    SLV_DAT_SLICES              : boolean := true

  );
  port (

    -- Rising-edge sensitive clock and active-high synchronous reset for the
    -- bus and control logic side of the BufferReader.
    bcd_clk                     : in  std_logic;
    bcd_reset                   : in  std_logic;

    -- Master port.
    mst_rreq_valid              : out std_logic;
    mst_rreq_ready              : in  std_logic;
    mst_rreq_addr               : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    mst_rreq_len                : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
    mst_rdat_valid              : in  std_logic;
    mst_rdat_ready              : out std_logic;
    mst_rdat_data               : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    mst_rdat_last               : in  std_logic;

    -- Concatenated slave ports.
    bsv_rreq_valid              : in  std_logic_vector(NUM_SLAVE_PORTS-1 downto 0);
    bsv_rreq_ready              : out std_logic_vector(NUM_SLAVE_PORTS-1 downto 0);
    bsv_rreq_addr               : in  std_logic_vector(NUM_SLAVE_PORTS*BUS_ADDR_WIDTH-1 downto 0);
    bsv_rreq_len                : in  std_logic_vector(NUM_SLAVE_PORTS*BUS_LEN_WIDTH-1 downto 0);
    bsv_rdat_valid              : out std_logic_vector(NUM_SLAVE_PORTS-1 downto 0);
    bsv_rdat_ready              : in  std_logic_vector(NUM_SLAVE_PORTS-1 downto 0);
    bsv_rdat_data               : out std_logic_vector(NUM_SLAVE_PORTS*BUS_DATA_WIDTH-1 downto 0);
    bsv_rdat_last               : out std_logic_vector(NUM_SLAVE_PORTS-1 downto 0)

  );
end BusReadArbiterVec;

architecture Behavioral of BusReadArbiterVec is

  -- Width of the index stream.
  constant INDEX_WIDTH          : natural := imax(1, log2ceil(NUM_SLAVE_PORTS));

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

  -- Copy of the bus slave signals in the entity as an array.
  signal bs_rreq_valid          : std_logic_vector(0 to NUM_SLAVE_PORTS-1);
  signal bs_rreq_ready          : std_logic_vector(0 to NUM_SLAVE_PORTS-1);
  signal bs_rreq_addr           : bus_addr_array(0 to NUM_SLAVE_PORTS-1);
  signal bs_rreq_len            : bus_len_array(0 to NUM_SLAVE_PORTS-1);
  signal bm_resp_valid          : std_logic_vector(0 to NUM_SLAVE_PORTS-1);
  signal bm_resp_ready          : std_logic_vector(0 to NUM_SLAVE_PORTS-1);
  signal bm_resp_data           : bus_data_array(0 to NUM_SLAVE_PORTS-1);
  signal bm_resp_last           : std_logic_vector(0 to NUM_SLAVE_PORTS-1);

  -- Register-sliced bus slave signals.
  signal bss_rreq_valid         : std_logic_vector(0 to NUM_SLAVE_PORTS-1);
  signal bss_rreq_ready         : std_logic_vector(0 to NUM_SLAVE_PORTS-1);
  signal bss_rreq_addr          : bus_addr_array(0 to NUM_SLAVE_PORTS-1);
  signal bss_rreq_len           : bus_len_array(0 to NUM_SLAVE_PORTS-1);
  signal bss_rdat_valid         : std_logic_vector(0 to NUM_SLAVE_PORTS-1);
  signal bss_rdat_ready         : std_logic_vector(0 to NUM_SLAVE_PORTS-1);
  signal bss_rdat_data          : bus_data_array(0 to NUM_SLAVE_PORTS-1);
  signal bss_rdat_last          : std_logic_vector(0 to NUM_SLAVE_PORTS-1);

  -- Register-sliced bus master signals.
  signal bms_rreq_valid         : std_logic;
  signal bms_rreq_ready         : std_logic;
  signal bms_rreq_addr          : bus_addr_type;
  signal bms_rreq_len           : bus_len_type;
  signal bms_rdat_valid         : std_logic;
  signal bms_rdat_ready         : std_logic;
  signal bms_rdat_data          : bus_data_type;
  signal bms_rdat_last          : std_logic;

  -- Serialized arbiter input signals.
  signal arb_in_valid           : std_logic_vector(NUM_SLAVE_PORTS-1 downto 0);
  signal arb_in_ready           : std_logic_vector(NUM_SLAVE_PORTS-1 downto 0);
  signal arb_in_data            : std_logic_vector(BQI(BQI'high)*NUM_SLAVE_PORTS-1 downto 0);

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
  signal idxB_enable            : std_logic_vector(NUM_SLAVE_PORTS-1 downto 0);

  -- Demultiplexed serialized response stream handshake signals.
  signal demux_valid            : std_logic_vector(NUM_SLAVE_PORTS-1 downto 0);
  signal demux_ready            : std_logic_vector(NUM_SLAVE_PORTS-1 downto 0);

begin

  -- Connect the serialized master ports to the internal arrays for
  -- convenience.
  serdes_gen: for i in 0 to NUM_SLAVE_PORTS-1 generate
  begin
    bs_rreq_valid  (i) <= bsv_rreq_valid (i);
    bsv_rreq_ready (i) <= bs_rreq_ready  (i);
    bs_rreq_addr   (i) <= bsv_rreq_addr  ((i+1)*BUS_ADDR_WIDTH-1 downto i*BUS_ADDR_WIDTH);
    bs_rreq_len    (i) <= bsv_rreq_len   ((i+1)*BUS_LEN_WIDTH-1  downto i*BUS_LEN_WIDTH);
    bsv_rdat_valid(i) <= bm_resp_valid (i);
    bm_resp_ready (i) <= bsv_rdat_ready(i);
    bsv_rdat_data((i+1)*BUS_DATA_WIDTH-1 downto i*BUS_DATA_WIDTH)
                      <= bm_resp_data  (i);
    bsv_rdat_last (i) <= bm_resp_last  (i);
  end generate;

  -- Instantiate register slices for the master ports.
  master_slice_gen: for i in 0 to NUM_SLAVE_PORTS-1 generate
    signal reqi_sData           : std_logic_vector(BQI(BQI'high)-1 downto 0);
    signal reqo_sData           : std_logic_vector(BQI(BQI'high)-1 downto 0);
    signal respi_sData          : std_logic_vector(BPI(BPI'high)-1 downto 0);
    signal respo_sData          : std_logic_vector(BPI(BPI'high)-1 downto 0);
  begin

    -- Request register slice.
    req_buffer_inst: StreamBuffer
      generic map (
        MIN_DEPTH                       => sel(SLV_REQ_SLICES, 2, 0),
        DATA_WIDTH                      => BQI(BQI'high)
      )
      port map (
        clk                             => bcd_clk,
        reset                           => bcd_reset,

        in_valid                        => bs_rreq_valid(i),
        in_ready                        => bs_rreq_ready(i),
        in_data                         => reqi_sData,

        out_valid                       => bss_rreq_valid(i),
        out_ready                       => bss_rreq_ready(i),
        out_data                        => reqo_sData
      );

    reqi_sData(BQI(2)-1 downto BQI(1))  <= bs_rreq_addr(i);
    reqi_sData(BQI(1)-1 downto BQI(0))  <= bs_rreq_len(i);

    bss_rreq_addr(i)                    <= reqo_sData(BQI(2)-1 downto BQI(1));
    bss_rreq_len(i)                     <= reqo_sData(BQI(1)-1 downto BQI(0));

    -- Response register slice.
    resp_buffer_inst: StreamBuffer
      generic map (
        MIN_DEPTH                       => sel(SLV_DAT_SLICES, 2, 0),
        DATA_WIDTH                      => BPI(BPI'high)
      )
      port map (
        clk                             => bcd_clk,
        reset                           => bcd_reset,

        in_valid                        => bss_rdat_valid(i),
        in_ready                        => bss_rdat_ready(i),
        in_data                         => respi_sData,

        out_valid                       => bm_resp_valid(i),
        out_ready                       => bm_resp_ready(i),
        out_data                        => respo_sData
      );

    respi_sData(BPI(2)-1 downto BPI(1)) <= bss_rdat_data(i);
    respi_sData(BPI(0))                 <= bss_rdat_last(i);

    bm_resp_data(i)                     <= respo_sData(BPI(2)-1 downto BPI(1));
    bm_resp_last(i)                     <= respo_sData(BPI(0));

  end generate;

  -- Instantiate master request register slice.
  mst_rreq_buffer_inst: StreamBuffer
    generic map (
      MIN_DEPTH                         => sel(MST_REQ_SLICE, 2, 0),
      DATA_WIDTH                        => BQI(BQI'high)
    )
    port map (
      clk                               => bcd_clk,
      reset                             => bcd_reset,

      in_valid                          => bms_rreq_valid,
      in_ready                          => bms_rreq_ready,
      in_data                           => sreqi_sData,

      out_valid                         => mst_rreq_valid,
      out_ready                         => mst_rreq_ready,
      out_data                          => sreqo_sData
    );

  sreqi_sData(BQI(2)-1 downto BQI(1))   <= bms_rreq_addr;
  sreqi_sData(BQI(1)-1 downto BQI(0))   <= bms_rreq_len;

  mst_rreq_addr                         <= sreqo_sData(BQI(2)-1 downto BQI(1));
  mst_rreq_len                          <= sreqo_sData(BQI(1)-1 downto BQI(0));

  -- Instantiate slave response register slice.
  mst_rdat_buffer_inst: StreamBuffer
    generic map (
      MIN_DEPTH                         => sel(MST_DAT_SLICE, 2, 0),
      DATA_WIDTH                        => BPI(BPI'high)
    )
    port map (
      clk                               => bcd_clk,
      reset                             => bcd_reset,

      in_valid                          => mst_rdat_valid,
      in_ready                          => mst_rdat_ready,
      in_data                           => srespi_sData,

      out_valid                         => bms_rdat_valid,
      out_ready                         => bms_rdat_ready,
      out_data                          => srespo_sData
    );

  srespi_sData(BPI(2)-1 downto BPI(1))  <= mst_rdat_data;
  srespi_sData(BPI(0))                  <= mst_rdat_last;

  bms_rdat_data                         <= srespo_sData(BPI(2)-1 downto BPI(1));
  bms_rdat_last                         <= srespo_sData(BPI(0));

  -- Serialize/deserialize the arbiter input stream signals.
  bms2arb_proc: process (bss_rreq_valid, bss_rreq_addr, bss_rreq_len) is
  begin
    for i in 0 to NUM_SLAVE_PORTS-1 loop
      arb_in_valid(i) <= bss_rreq_valid(i);
      arb_in_data(i*BQI(BQI'high)+BQI(2)-1 downto i*BQI(BQI'high)+BQI(1)) <= bss_rreq_addr(i);
      arb_in_data(i*BQI(BQI'high)+BQI(1)-1 downto i*BQI(BQI'high)+BQI(0)) <= bss_rreq_len(i);
    end loop;
  end process;
  arb2bms_proc: process (arb_in_ready) is
  begin
    for i in 0 to NUM_SLAVE_PORTS-1 loop
      bss_rreq_ready(i) <= arb_in_ready(i);
    end loop;
  end process;

  -- Instantiate the stream arbiter.
  arb_inst: StreamArb
    generic map (
      NUM_INPUTS                        => NUM_SLAVE_PORTS,
      INDEX_WIDTH                       => INDEX_WIDTH,
      DATA_WIDTH                        => BQI(BQI'high),
      ARB_METHOD                        => ARB_METHOD
    )
    port map (
      clk                               => bcd_clk,
      reset                             => bcd_reset,

      in_valid                          => arb_in_valid,
      in_ready                          => arb_in_ready,
      in_data                           => arb_in_data,

      out_valid                         => arb_out_valid,
      out_ready                         => arb_out_ready,
      out_data                          => arbo_sData,
      out_index                         => idxA_index
    );

  bms_rreq_addr                         <= arbo_sData(BQI(2)-1 downto BQI(1));
  bms_rreq_len                          <= arbo_sData(BQI(1)-1 downto BQI(0));

  -- Instantiate a stream synchronizer to split the slave request and index
  -- streams.
  arb_sync_inst: StreamSync
    generic map (
      NUM_INPUTS                        => 1,
      NUM_OUTPUTS                       => 2
    )
    port map (
      clk                               => bcd_clk,
      reset                             => bcd_reset,
      in_valid(0)                       => arb_out_valid,
      in_ready(0)                       => arb_out_ready,
      out_valid(1)                      => bms_rreq_valid,
      out_valid(0)                      => idxA_valid,
      out_ready(1)                      => bms_rreq_ready,
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
      clk                               => bcd_clk,
      reset                             => bcd_reset,

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
    for i in 0 to NUM_SLAVE_PORTS-1 loop
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
      NUM_OUTPUTS                       => NUM_SLAVE_PORTS
    )
    port map (
      clk                               => bcd_clk,
      reset                             => bcd_reset,

      in_valid(1)                       => idxB_valid,
      in_valid(0)                       => bms_rdat_valid,
      in_ready(1)                       => idxB_ready,
      in_ready(0)                       => bms_rdat_ready,
      in_advance(1)                     => bms_rdat_last,
      in_advance(0)                     => '1',

      out_valid                         => demux_valid,
      out_ready                         => demux_ready,
      out_enable                        => idxB_enable
    );

  -- Serialize/deserialize the demultiplexer signals. Also connect the data and
  -- last signals from the slave response slice directly to all the master
  -- reponse slices. Only the handshake signals differ here.
  demux2bms_proc: process (demux_valid, bms_rdat_data, bms_rdat_last) is
  begin
    for i in 0 to NUM_SLAVE_PORTS-1 loop
      bss_rdat_valid(i) <= demux_valid(i);
      bss_rdat_data(i) <= bms_rdat_data;
      bss_rdat_last(i) <= bms_rdat_last;
    end loop;
  end process;
  bms2demux_proc: process (bss_rdat_ready) is
  begin
    for i in 0 to NUM_SLAVE_PORTS-1 loop
      demux_ready(i) <= bss_rdat_ready(i);
    end loop;
  end process;

end Behavioral;

