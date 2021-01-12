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
-- BufferWriters.

entity BusWriteArbiterVec is
  generic (

    -- Bus address width.
    BUS_ADDR_WIDTH              : natural := 32;

    -- Bus burst length width.
    BUS_LEN_WIDTH               : natural := 8;

    -- Bus data width.
    BUS_DATA_WIDTH              : natural := 32;

    -- Number of slaves ports to arbitrate between.
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

    -- Whether a register slice should be inserted into the slave data ports
    SLV_DAT_SLICES              : boolean := false;

    -- Whether a register slice should be inserted into the master data port
    MST_DAT_SLICE               : boolean := true;

    -- Whether a register slice should be inserted into the master response port
    MST_REP_SLICE               : boolean := false;

    -- Whether a register slice should be inserted into the slave response ports
    SLV_REP_SLICES              : boolean := true

  );
  port (

    -- Rising-edge sensitive clock and active-high synchronous reset for the
    -- bus and control logic side of the BufferWriter.
    bcd_clk                     : in  std_logic;
    bcd_reset                   : in  std_logic;

    -- Concatenated master ports.
    bsv_wreq_valid              : in  std_logic_vector(NUM_SLAVE_PORTS-1 downto 0);
    bsv_wreq_ready              : out std_logic_vector(NUM_SLAVE_PORTS-1 downto 0);
    bsv_wreq_addr               : in  std_logic_vector(NUM_SLAVE_PORTS*BUS_ADDR_WIDTH-1 downto 0);
    bsv_wreq_len                : in  std_logic_vector(NUM_SLAVE_PORTS*BUS_LEN_WIDTH-1 downto 0);
    bsv_wreq_last               : in  std_logic_vector(NUM_SLAVE_PORTS-1 downto 0);
    bsv_wdat_valid              : in  std_logic_vector(NUM_SLAVE_PORTS-1 downto 0);
    bsv_wdat_ready              : out std_logic_vector(NUM_SLAVE_PORTS-1 downto 0);
    bsv_wdat_data               : in  std_logic_vector(NUM_SLAVE_PORTS*BUS_DATA_WIDTH-1 downto 0);
    bsv_wdat_strobe             : in  std_logic_vector(NUM_SLAVE_PORTS*BUS_DATA_WIDTH/8-1 downto 0);
    bsv_wdat_last               : in  std_logic_vector(NUM_SLAVE_PORTS-1 downto 0);
    bsv_wrep_valid              : out std_logic_vector(NUM_SLAVE_PORTS-1 downto 0);
    bsv_wrep_ready              : in  std_logic_vector(NUM_SLAVE_PORTS-1 downto 0);
    bsv_wrep_ok                 : out std_logic_vector(NUM_SLAVE_PORTS-1 downto 0);
    
    -- Master port.
    mst_wreq_valid              : out std_logic;
    mst_wreq_ready              : in  std_logic;
    mst_wreq_addr               : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    mst_wreq_len                : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
    mst_wreq_last               : out std_logic;
    mst_wdat_valid              : out std_logic;
    mst_wdat_ready              : in  std_logic;
    mst_wdat_data               : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    mst_wdat_strobe             : out std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0);
    mst_wdat_last               : out std_logic;
    mst_wrep_valid              : in  std_logic;
    mst_wrep_ready              : out std_logic;
    mst_wrep_ok                 : in  std_logic

  );
end BusWriteArbiterVec;

architecture Behavioral of BusWriteArbiterVec is

  -- Width of the index stream.
  constant INDEX_WIDTH          : natural := imax(1, log2ceil(NUM_SLAVE_PORTS));

  -- Type declarations for busses.
  subtype bus_addr_type   is std_logic_vector(BUS_ADDR_WIDTH-1   downto 0);
  subtype bus_len_type    is std_logic_vector(BUS_LEN_WIDTH-1    downto 0);
  subtype bus_data_type   is std_logic_vector(BUS_DATA_WIDTH-1   downto 0);
  subtype bus_strobe_type is std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0);

  type bus_addr_array   is array (natural range <>) of bus_addr_type;
  type bus_len_array    is array (natural range <>) of bus_len_type;
  type bus_data_array   is array (natural range <>) of bus_data_type;
  type bus_strobe_array is array (natural range <>) of bus_strobe_type;

  -- Bus request channel serialization indices.
  constant BQI : nat_array := cumulative((
    2 => 1,
    1 => BUS_ADDR_WIDTH,
    0 => BUS_LEN_WIDTH
  ));

  signal mreqi_sData            : std_logic_vector(BQI(BQI'high)-1 downto 0);
  signal mreqo_sData            : std_logic_vector(BQI(BQI'high)-1 downto 0);

  signal arbi_sData             : std_logic_vector(BQI(BQI'high)-1 downto 0);
  signal arbo_sData             : std_logic_vector(BQI(BQI'high)-1 downto 0);

  -- Bus data channel serialization indices.
  constant BDI : nat_array := cumulative((
    2 => BUS_DATA_WIDTH/8,
    1 => BUS_DATA_WIDTH,
    0 => 1
  ));

  signal mwdati_sData           : std_logic_vector(BDI(BDI'high)-1 downto 0);
  signal mwdato_sData           : std_logic_vector(BDI(BDI'high)-1 downto 0);

  -- Bus response channel serialization indices.
  constant BPI : nat_array := cumulative((
    0 => 1
  ));

  signal mwrepi_sData           : std_logic_vector(BPI(BPI'high)-1 downto 0);
  signal mwrepo_sData           : std_logic_vector(BPI(BPI'high)-1 downto 0);

  -- Copy of the bus slave signals in the entity as an array.
  signal bs_wreq_valid          : std_logic_vector(0 to NUM_SLAVE_PORTS-1);
  signal bs_wreq_ready          : std_logic_vector(0 to NUM_SLAVE_PORTS-1);
  signal bs_wreq_addr           : bus_addr_array(0 to NUM_SLAVE_PORTS-1);
  signal bs_wreq_len            : bus_len_array(0 to NUM_SLAVE_PORTS-1);
  signal bs_wreq_last           : std_logic_vector(0 to NUM_SLAVE_PORTS-1);
  signal bs_wdat_valid          : std_logic_vector(0 to NUM_SLAVE_PORTS-1);
  signal bs_wdat_ready          : std_logic_vector(0 to NUM_SLAVE_PORTS-1);
  signal bs_wdat_data           : bus_data_array(0 to NUM_SLAVE_PORTS-1);
  signal bs_wdat_strobe         : bus_strobe_array(0 to NUM_SLAVE_PORTS-1);
  signal bs_wdat_last           : std_logic_vector(0 to NUM_SLAVE_PORTS-1);
  signal bs_wrep_valid          : std_logic_vector(0 to NUM_SLAVE_PORTS-1);
  signal bs_wrep_ready          : std_logic_vector(0 to NUM_SLAVE_PORTS-1);
  signal bs_wrep_ok             : std_logic_vector(0 to NUM_SLAVE_PORTS-1);

  -- Register-sliced bus slave signals.
  signal bss_wreq_valid         : std_logic_vector(0 to NUM_SLAVE_PORTS-1);
  signal bss_wreq_ready         : std_logic_vector(0 to NUM_SLAVE_PORTS-1);
  signal bss_wreq_addr          : bus_addr_array(0 to NUM_SLAVE_PORTS-1);
  signal bss_wreq_len           : bus_len_array(0 to NUM_SLAVE_PORTS-1);
  signal bss_wreq_last          : std_logic_vector(0 to NUM_SLAVE_PORTS-1);
  signal bss_wdat_valid         : std_logic_vector(0 to NUM_SLAVE_PORTS-1);
  signal bss_wdat_ready         : std_logic_vector(0 to NUM_SLAVE_PORTS-1);
  signal bss_wdat_data          : bus_data_array(0 to NUM_SLAVE_PORTS-1);
  signal bss_wdat_strobe        : bus_strobe_array(0 to NUM_SLAVE_PORTS-1);
  signal bss_wdat_last          : std_logic_vector(0 to NUM_SLAVE_PORTS-1);
  signal bss_wrep_valid         : std_logic_vector(0 to NUM_SLAVE_PORTS-1);
  signal bss_wrep_ready         : std_logic_vector(0 to NUM_SLAVE_PORTS-1);
  signal bss_wrep_ok            : std_logic_vector(0 to NUM_SLAVE_PORTS-1);

  -- Register-sliced bus master signals.
  signal bms_wreq_valid         : std_logic;
  signal bms_wreq_ready         : std_logic;
  signal bms_wreq_addr          : bus_addr_type;
  signal bms_wreq_len           : bus_len_type;
  signal bms_wreq_last          : std_logic;
  signal bms_wdat_valid         : std_logic;
  signal bms_wdat_ready         : std_logic;
  signal bms_wdat_data          : bus_data_type;
  signal bms_wdat_strobe        : bus_strobe_type;
  signal bms_wdat_last          : std_logic;
  signal bms_wrep_valid         : std_logic;
  signal bms_wrep_ready         : std_logic;
  signal bms_wrep_ok            : std_logic;

  -- Serialized arbiter input signals.
  signal arb_in_valid           : std_logic_vector(NUM_SLAVE_PORTS-1 downto 0);
  signal arb_in_ready           : std_logic_vector(NUM_SLAVE_PORTS-1 downto 0);
  signal arb_in_data            : std_logic_vector(BQI(BQI'high)*NUM_SLAVE_PORTS-1 downto 0);

  -- Arbiter output stream handshake.
  signal arb_out_valid          : std_logic;
  signal arb_out_ready          : std_logic;
  signal arb_out_index          : std_logic_vector(INDEX_WIDTH-1 downto 0);

  -- Index stream stage A (between sync and buffer for req-data timing).
  signal idxA_valid             : std_logic;
  signal idxA_ready             : std_logic;
  signal idxA_index             : std_logic_vector(INDEX_WIDTH-1 downto 0);

  -- Index stream stage A (between buffer for req-data timing and sync).
  signal idxB_valid             : std_logic;
  signal idxB_ready             : std_logic;
  signal idxB_index             : std_logic_vector(INDEX_WIDTH-1 downto 0);
  signal idxB_enable            : std_logic_vector(NUM_SLAVE_PORTS-1 downto 0);

  -- Index stream stage A (between sync and buffer for req-resp timing).
  signal idxC_valid             : std_logic;
  signal idxC_ready             : std_logic;
  signal idxC_index             : std_logic_vector(INDEX_WIDTH-1 downto 0);

  -- Index stream stage A (between buffer for req-resp timing and sync).
  signal idxD_valid             : std_logic;
  signal idxD_ready             : std_logic;
  signal idxD_index             : std_logic_vector(INDEX_WIDTH-1 downto 0);
  signal idxD_enable            : std_logic_vector(NUM_SLAVE_PORTS-1 downto 0);

  -- Multiplexed data stream signals.
  signal mux_wdat_valid         : std_logic;
  signal mux_wdat_ready         : std_logic;
  signal mux_wdat_data          : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal mux_wdat_strobe        : std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0);
  signal mux_wdat_last          : std_logic;

  -- Demultiplexed serialized response stream handshake signals.
  signal demux_valid            : std_logic_vector(NUM_SLAVE_PORTS-1 downto 0);
  signal demux_ready            : std_logic_vector(NUM_SLAVE_PORTS-1 downto 0);

begin

  -- Connect the serialized slave ports to the internal arrays for convenience.
  serdes_gen: for i in 0 to NUM_SLAVE_PORTS-1 generate
  begin
    bs_wreq_valid (i) <= bsv_wreq_valid(i);
    bsv_wreq_ready(i) <= bs_wreq_ready (i);
    bs_wreq_addr  (i) <= bsv_wreq_addr ((i+1)*BUS_ADDR_WIDTH-1 downto i*BUS_ADDR_WIDTH);
    bs_wreq_len   (i) <= bsv_wreq_len  ((i+1)*BUS_LEN_WIDTH-1  downto i*BUS_LEN_WIDTH);
    bs_wreq_last  (i) <= bsv_wreq_last (i);
    bs_wdat_valid (i) <= bsv_wdat_valid(i);
    bsv_wdat_ready(i) <= bs_wdat_ready (i);
    bs_wdat_data  (i) <= bsv_wdat_data((i+1)*BUS_DATA_WIDTH-1 downto i*BUS_DATA_WIDTH);
    bs_wdat_strobe(i) <= bsv_wdat_strobe((i+1)*BUS_DATA_WIDTH/8-1 downto i*BUS_DATA_WIDTH/8);
    bs_wdat_last  (i) <= bsv_wdat_last (i);
    bsv_wrep_valid(i) <= bs_wrep_valid (i);
    bs_wrep_ready (i) <= bsv_wrep_ready(i);
    bsv_wrep_ok   (i) <= bs_wrep_ok    (i);
  end generate;

  -- Instantiate register slices for the slave ports.
  slave_slice_gen: for i in 0 to NUM_SLAVE_PORTS-1 generate
    signal wreqi_sData                  : std_logic_vector(BQI(BQI'high)-1 downto 0);
    signal wreqo_sData                  : std_logic_vector(BQI(BQI'high)-1 downto 0);
    signal wdati_sData                  : std_logic_vector(BDI(BDI'high)-1 downto 0);
    signal wdato_sData                  : std_logic_vector(BDI(BDI'high)-1 downto 0);
    signal wrepi_sData                  : std_logic_vector(BPI(BPI'high)-1 downto 0);
    signal wrepo_sData                  : std_logic_vector(BPI(BPI'high)-1 downto 0);
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

        in_valid                        => bs_wreq_valid(i),
        in_ready                        => bs_wreq_ready(i),
        in_data                         => wreqi_sData,

        out_valid                       => bss_wreq_valid(i),
        out_ready                       => bss_wreq_ready(i),
        out_data                        => wreqo_sData
      );

    wreqi_sData(BQI(2))                 <= bs_wreq_last(i);
    wreqi_sData(BQI(2)-1 downto BQI(1)) <= bs_wreq_addr(i);
    wreqi_sData(BQI(1)-1 downto BQI(0)) <= bs_wreq_len(i);

    bss_wreq_last(i)                    <= wreqo_sData(BQI(2));
    bss_wreq_addr(i)                    <= wreqo_sData(BQI(2)-1 downto BQI(1));
    bss_wreq_len(i)                     <= wreqo_sData(BQI(1)-1 downto BQI(0));

    -- Write data register slice.
    dat_buffer_inst: StreamBuffer
      generic map (
        MIN_DEPTH                       => sel(SLV_DAT_SLICES, 2, 0),
        DATA_WIDTH                      => BDI(BDI'high)
      )
      port map (
        clk                             => bcd_clk,
        reset                           => bcd_reset,

        in_valid                        => bs_wdat_valid(i),
        in_ready                        => bs_wdat_ready(i),
        in_data                         => wdati_sData,

        out_valid                       => bss_wdat_valid(i),
        out_ready                       => bss_wdat_ready(i),
        out_data                        => wdato_sData
      );

    wdati_sData(BDI(3)-1 downto BDI(2)) <= bs_wdat_strobe(i);
    wdati_sData(BDI(2)-1 downto BDI(1)) <= bs_wdat_data(i);
    wdati_sData(BDI(0))                 <= bs_wdat_last(i);

    bss_wdat_strobe(i)                  <= wdato_sData(BDI(3)-1 downto BDI(2));
    bss_wdat_data(i)                    <= wdato_sData(BDI(2)-1 downto BDI(1));
    bss_wdat_last(i)                    <= wdato_sData(BDI(0));

    -- Write data register slice.
    rep_buffer_inst: StreamBuffer
      generic map (
        MIN_DEPTH                       => sel(SLV_REP_SLICES, 2, 0),
        DATA_WIDTH                      => BPI(BPI'high)
      )
      port map (
        clk                             => bcd_clk,
        reset                           => bcd_reset,

        in_valid                        => bss_wrep_valid(i),
        in_ready                        => bss_wrep_ready(i),
        in_data                         => wrepi_sData,

        out_valid                       => bs_wrep_valid(i),
        out_ready                       => bs_wrep_ready(i),
        out_data                        => wrepo_sData
      );

    wrepi_sData(BPI(0))                 <= bss_wrep_ok(i);

    bs_wrep_ok(i)                       <= wrepo_sData(BPI(0));

  end generate;

  -- Instantiate master request register slice.
  mst_wreq_buffer_inst: StreamBuffer
    generic map (
      MIN_DEPTH                         => sel(MST_REQ_SLICE, 2, 0),
      DATA_WIDTH                        => BQI(BQI'high)
    )
    port map (
      clk                               => bcd_clk,
      reset                             => bcd_reset,

      in_valid                          => bms_wreq_valid,
      in_ready                          => bms_wreq_ready,
      in_data                           => mreqi_sData,

      out_valid                         => mst_wreq_valid,
      out_ready                         => mst_wreq_ready,
      out_data                          => mreqo_sData
    );

  mreqi_sData(BQI(2))                   <= bms_wreq_last;
  mreqi_sData(BQI(2)-1 downto BQI(1))   <= bms_wreq_addr;
  mreqi_sData(BQI(1)-1 downto BQI(0))   <= bms_wreq_len;

  mst_wreq_last                         <= mreqo_sData(BQI(2));
  mst_wreq_addr                         <= mreqo_sData(BQI(2)-1 downto BQI(1));
  mst_wreq_len                          <= mreqo_sData(BQI(1)-1 downto BQI(0));

  -- Instantiate master write data register slice.
  mst_wdat_buffer_inst: StreamBuffer
    generic map (
      MIN_DEPTH                         => sel(MST_DAT_SLICE, 2, 0),
      DATA_WIDTH                        => BDI(BDI'high)
    )
    port map (
      clk                               => bcd_clk,
      reset                             => bcd_reset,

      in_valid                          => bms_wdat_valid,
      in_ready                          => bms_wdat_ready,
      in_data                           => mwdati_sData,

      out_valid                         => mst_wdat_valid,
      out_ready                         => mst_wdat_ready,
      out_data                          => mwdato_sData
    );

  mwdati_sData(BDI(3)-1 downto BDI(2))  <= bms_wdat_strobe;
  mwdati_sData(BDI(2)-1 downto BDI(1))  <= bms_wdat_data;
  mwdati_sData(BDI(0))                  <= bms_wdat_last;

  mst_wdat_strobe                       <= mwdato_sData(BDI(3)-1 downto BDI(2));
  mst_wdat_data                         <= mwdato_sData(BDI(2)-1 downto BDI(1));
  mst_wdat_last                         <= mwdato_sData(BDI(0));

  -- Instantiate master write response register slice.
  mst_wrep_buffer_inst: StreamBuffer
    generic map (
      MIN_DEPTH                         => sel(MST_REP_SLICE, 2, 0),
      DATA_WIDTH                        => BPI(BPI'high)
    )
    port map (
      clk                               => bcd_clk,
      reset                             => bcd_reset,

      in_valid                          => mst_wrep_valid,
      in_ready                          => mst_wrep_ready,
      in_data                           => mwrepi_sData,

      out_valid                         => bms_wrep_valid,
      out_ready                         => bms_wrep_ready,
      out_data                          => mwrepo_sData
    );

  mwrepi_sData(BPI(0))                  <= mst_wrep_ok;

  bms_wrep_ok                           <= mwrepo_sData(BPI(0));

  -- Concatenate the arbiter input stream signals.
  bss2arb_proc: process (bss_wreq_valid, bss_wreq_addr, bss_wreq_len, bss_wreq_last) is
  begin
    for i in 0 to NUM_SLAVE_PORTS-1 loop
      arb_in_valid(i) <= bss_wreq_valid(i);
      arb_in_data(i*BQI(BQI'high)+BQI(2)) <= bss_wreq_last(i);
      arb_in_data(i*BQI(BQI'high)+BQI(2)-1 downto i*BQI(BQI'high)+BQI(1)) <= bss_wreq_addr(i);
      arb_in_data(i*BQI(BQI'high)+BQI(1)-1 downto i*BQI(BQI'high)+BQI(0)) <= bss_wreq_len(i);
    end loop;
  end process;
  arb2bss_proc: process (arb_in_ready) is
  begin
    for i in 0 to NUM_SLAVE_PORTS-1 loop
      bss_wreq_ready(i) <= arb_in_ready(i);
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
      out_index                         => arb_out_index
    );

  idxA_index <= arb_out_index;
  idxC_index <= arb_out_index;

  bms_wreq_last                          <= arbo_sData(BQI(2));
  bms_wreq_addr                          <= arbo_sData(BQI(2)-1 downto BQI(1));
  bms_wreq_len                           <= arbo_sData(BQI(1)-1 downto BQI(0));

  -- Instantiate a stream synchronizer to split the slave request and index
  -- streams.
  arb_sync_inst: StreamSync
    generic map (
      NUM_INPUTS                        => 1,
      NUM_OUTPUTS                       => 3
    )
    port map (
      clk                               => bcd_clk,
      reset                             => bcd_reset,
      in_valid(0)                       => arb_out_valid,
      in_ready(0)                       => arb_out_ready,
      out_valid(2)                      => bms_wreq_valid,
      out_valid(1)                      => idxA_valid,
      out_valid(0)                      => idxC_valid,
      out_ready(2)                      => bms_wreq_ready,
      out_ready(1)                      => idxA_ready,
      out_ready(0)                      => idxC_ready
    );

  -- Instantiate write command to write data buffer.
  index_data_buffer_inst: StreamBuffer
    generic map (
      MIN_DEPTH                         => 2,
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

  -- Decode the index signal to one-hot for the write data synchronizer.
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

  -- Multiplex the write data streams onto the output, selected by the output
  -- of the stream arbiter (idxB_enable).
  wdat_mux: process(idxB_enable,
    mux_wdat_ready,
    bss_wdat_data, bss_wdat_last, bss_wdat_valid, bss_wdat_strobe
  ) is
  begin
    
    -- Invalidate all paths
    mux_wdat_valid    <= '0';
    bss_wdat_ready    <= (others => '0');
    
    mux_wdat_data     <= (others => '0');
    mux_wdat_strobe   <= (others => '0');
    mux_wdat_last     <= '0';
    
    -- In simulation, make everything unknown if not enabled
    --pragma translate off
    mux_wdat_data     <= (others => 'U');
    mux_wdat_strobe   <= (others => 'U');
    mux_wdat_last     <= 'U';
    --pragma translate on
    
    -- Except the slave that should be enabled
    for i in 0 to NUM_SLAVE_PORTS-1 loop
      if idxB_enable(i) = '1' then
        mux_wdat_valid    <= bss_wdat_valid(i);
        bss_wdat_ready(i) <= mux_wdat_ready;
        mux_wdat_data     <= bss_wdat_data(i);
        mux_wdat_strobe   <= bss_wdat_strobe(i);
        mux_wdat_last     <= bss_wdat_last(i);        
      end if;
    end loop;
  end process;

  -- Instantiate the write data stream synchronizer. This synchronizes the 
  -- index stream with the selected write data stream (only popping from the
  -- index stream when the "last" flag is set in the write data stream).
  wdat_sync_inst: StreamSync
    generic map (
      NUM_INPUTS                        => 2,
      NUM_OUTPUTS                       => 1
    )
    port map (
      clk                               => bcd_clk,
      reset                             => bcd_reset,

      in_valid(1)                       => idxB_valid,
      in_valid(0)                       => mux_wdat_valid,
      in_ready(1)                       => idxB_ready,
      in_ready(0)                       => mux_wdat_ready,
      in_advance(1)                     => mux_wdat_last,
      in_advance(0)                     => '1',

      out_valid(0)                      => bms_wdat_valid,
      out_ready(0)                      => bms_wdat_ready
    );
  
  bms_wdat_strobe                       <= mux_wdat_strobe;  
  bms_wdat_data                         <= mux_wdat_data;
  bms_wdat_last                         <= mux_wdat_last;

  -- Instantiate the outstanding request buffer.
  index_resp_buffer_inst: StreamBuffer
    generic map (
      MIN_DEPTH                         => MAX_OUTSTANDING,
      DATA_WIDTH                        => INDEX_WIDTH,
      RAM_CONFIG                        => RAM_CONFIG
    )
    port map (
      clk                               => bcd_clk,
      reset                             => bcd_reset,

      in_valid                          => idxC_valid,
      in_ready                          => idxC_ready,
      in_data                           => idxC_index,

      out_valid                         => idxD_valid,
      out_ready                         => idxD_ready,
      out_data                          => idxD_index
    );

  -- Decode the index signal to one-hot for the response synchronizer.
  resp_index_to_oh_proc: process (idxD_index) is
  begin
    for i in 0 to NUM_SLAVE_PORTS-1 loop
      if to_integer(unsigned(idxD_index)) = i then
        idxD_enable(i) <= '1';
      else
        idxD_enable(i) <= '0';
      end if;
    end loop;
  end process;

  -- Synchronize response channels.
  resp_sync_inst: StreamSync
    generic map (
      NUM_INPUTS                        => 2,
      NUM_OUTPUTS                       => NUM_SLAVE_PORTS
    )
    port map (
      clk                               => bcd_clk,
      reset                             => bcd_reset,

      in_valid(1)                       => idxD_valid,
      in_valid(0)                       => bms_wrep_valid,
      in_ready(1)                       => idxD_ready,
      in_ready(0)                       => bms_wrep_ready,

      out_valid                         => demux_valid,
      out_ready                         => demux_ready,
      out_enable                        => idxD_enable
    );

  -- Serialize/deserialize the demultiplexer signals. Also connect the ok
  -- signal from the slave response slice directly to all the master
  -- reponse slices. Only the handshake signals differ here.
  demux2bms_proc: process (demux_valid, bms_wrep_ok) is
  begin
    for i in 0 to NUM_SLAVE_PORTS-1 loop
      bss_wrep_valid(i) <= demux_valid(i);
      bss_wrep_ok(i) <= bms_wrep_ok;
    end loop;
  end process;
  bms2demux_proc: process (bss_wrep_ready) is
  begin
    for i in 0 to NUM_SLAVE_PORTS-1 loop
      demux_ready(i) <= bss_wrep_ready(i);
    end loop;
  end process;



end Behavioral;

