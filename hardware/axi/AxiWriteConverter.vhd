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
use work.Arrow_pkg.all;
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
-- This unit doesn't support strobe bits for anything but bytes only

entity AxiWriteConverter is
  generic (
    ADDR_WIDTH          : natural;

    MASTER_DATA_WIDTH   : natural;
    MASTER_LEN_WIDTH    : natural;

    SLAVE_DATA_WIDTH    : natural;
    SLAVE_LEN_WIDTH     : natural;
    SLAVE_MAX_BURST     : natural;
    -- If the master bus already contains an output FIFO, this
    -- should be set to false to prevent redundant buffering
    -- of the master bus response channel
    ENABLE_FIFO         : boolean := true;

    SLV_REQ_SLICE_DEPTH : natural := 2;
    SLV_DAT_SLICE_DEPTH : natural := 2;
    MST_REQ_SLICE_DEPTH : natural := 2;
    MST_DAT_SLICE_DEPTH : natural := 2;

    -- Whether a CCIP-style write request should be sent.
    SEND_WRITE_FENCE    : boolean := false

  );

  port (
    clk                 : in std_logic;
    reset_n             : in std_logic;

    -- Fletcher bus
    -- Write address channel
    slv_bus_wreq_valid  : in std_logic;
    slv_bus_wreq_ready  : out std_logic;
    slv_bus_wreq_addr   : in std_logic_vector(ADDR_WIDTH - 1 downto 0);
    slv_bus_wreq_len    : in std_logic_vector(SLAVE_LEN_WIDTH - 1 downto 0);

    -- Write data channel
    slv_bus_wdat_valid  : in std_logic;
    slv_bus_wdat_ready  : out std_logic;
    slv_bus_wdat_data   : in std_logic_vector(SLAVE_DATA_WIDTH - 1 downto 0);
    slv_bus_wdat_strobe : in std_logic_vector(SLAVE_DATA_WIDTH/8 - 1 downto 0);
    slv_bus_wdat_last   : in std_logic;

    -- Platform completion handshake
    -- Assert req to indicate that the kernel is done, then ack will be strobed
    -- to indicate that the platform has finished propagating and publishing
    -- the write data.
    plat_complete_req   : in std_logic := '0';
    plat_complete_ack   : out std_logic;

    -- AXI BUS
    -- Read address channel
    m_axi_awaddr        : out std_logic_vector(ADDR_WIDTH - 1 downto 0);
    m_axi_awlen         : out std_logic_vector(MASTER_LEN_WIDTH - 1 downto 0);
    m_axi_awvalid       : out std_logic;
    m_axi_awready       : in std_logic;
    m_axi_awsize        : out std_logic_vector(2 downto 0);
    m_axi_awuser        : out std_logic_vector(7 downto 0);

    -- Read data channel
    m_axi_wvalid        : out std_logic;
    m_axi_wready        : in std_logic;
    m_axi_wdata         : out std_logic_vector(MASTER_DATA_WIDTH - 1 downto 0);
    m_axi_wstrb         : out std_logic_vector(MASTER_DATA_WIDTH/8 - 1 downto 0);
    m_axi_wlast         : out std_logic;

    -- Write response channel
    m_axi_bvalid        : in std_logic;
    m_axi_bready        : out std_logic

  );
end entity AxiWriteConverter;

architecture rtl of AxiWriteConverter is

  -- The ratio between the master and slave
  constant RATIO             : natural                      := MASTER_DATA_WIDTH / SLAVE_DATA_WIDTH;

  -- The amount of shifting required on the len signal
  constant LEN_SHIFT         : natural                      := log2ceil(RATIO);

  -- AXI arsize is fixed corresponding to beat size = 1 bus data word
  constant MASTER_SIZE       : std_logic_vector(2 downto 0) := slv(u(log2ceil(MASTER_DATA_WIDTH/8), 3));

  -- Maximum burst the FIFO should be able to handle
  constant MASTER_MAX_BURST  : natural                      := SLAVE_MAX_BURST / RATIO;

  -- Signal for length conversion
  signal new_len             : unsigned(SLAVE_LEN_WIDTH - 1 downto 0);

  -- BusWriteBuffer signals
  signal buf_mst_wreq_valid  : std_logic;
  signal buf_mst_wreq_ready  : std_logic;
  signal buf_mst_wreq_addr   : std_logic_vector(ADDR_WIDTH - 1 downto 0);
  signal buf_mst_wreq_len    : std_logic_vector(MASTER_LEN_WIDTH downto 0);
  signal buf_mst_wdat_valid  : std_logic;
  signal buf_mst_wdat_ready  : std_logic;
  signal buf_mst_wdat_data   : std_logic_vector(MASTER_DATA_WIDTH - 1 downto 0);
  signal buf_mst_wdat_strobe : std_logic_vector(MASTER_DATA_WIDTH/8 - 1 downto 0);
  signal buf_mst_wdat_last   : std_logic;

  signal buf_slv_wreq_valid  : std_logic;
  signal buf_slv_wreq_ready  : std_logic;
  signal buf_slv_wreq_addr   : std_logic_vector(ADDR_WIDTH - 1 downto 0);
  signal buf_slv_wreq_len    : std_logic_vector(MASTER_LEN_WIDTH downto 0);
  signal buf_slv_wdat_valid  : std_logic;
  signal buf_slv_wdat_ready  : std_logic;
  signal buf_slv_wdat_data   : std_logic_vector(MASTER_DATA_WIDTH - 1 downto 0);
  signal buf_slv_wdat_strobe : std_logic_vector(MASTER_DATA_WIDTH/8 - 1 downto 0);
  signal buf_slv_wdat_last   : std_logic;

  -- StreamGearboxParallelizer input & output for data
  signal ser_dat_i_ready     : std_logic;
  signal ser_dat_i_valid     : std_logic;
  signal ser_dat_i_data      : std_logic_vector(SLAVE_DATA_WIDTH - 1 downto 0);
  signal ser_dat_i_last      : std_logic;

  signal ser_dat_o_ready     : std_logic;
  signal ser_dat_o_valid     : std_logic;
  signal ser_dat_o_data      : std_logic_vector(MASTER_DATA_WIDTH - 1 downto 0);
  signal ser_dat_o_last      : std_logic;

  -- StreamGearboxParallelizer input & output for strobe
  signal ser_stb_i_ready     : std_logic;
  signal ser_stb_i_valid     : std_logic;
  signal ser_stb_i_data      : std_logic_vector(SLAVE_DATA_WIDTH/8 - 1 downto 0);
  signal ser_stb_i_last      : std_logic;

  signal ser_stb_o_ready     : std_logic;
  signal ser_stb_o_valid     : std_logic;
  signal ser_stb_o_data      : std_logic_vector(MASTER_DATA_WIDTH/8 - 1 downto 0);
  signal ser_stb_o_last      : std_logic;

  signal reset               : std_logic;

  -- Internal signals for slicing/buffering:

  -- Fletcher Write Address Channel Indices
  constant FWACI             : nat_array := cumulative((
  1 => slv_bus_wreq_addr'length,
  0 => slv_bus_wreq_len'length
  ));

  -- Fletcher Write Data Channel Indices
  constant FWDCI : nat_array := cumulative((
  2 => slv_bus_wdat_data'length,
  1 => slv_bus_wdat_strobe'length,
  0 => 1
  ));

  signal int_slv_bus_wreq_addr   : std_logic_vector(ADDR_WIDTH - 1 downto 0);
  signal int_slv_bus_wreq_len    : std_logic_vector(SLAVE_LEN_WIDTH - 1 downto 0);
  signal int_slv_bus_wreq_valid  : std_logic;
  signal int_slv_bus_wreq_ready  : std_logic;
  signal int_slv_bus_wdat_data   : std_logic_vector(SLAVE_DATA_WIDTH - 1 downto 0);
  signal int_slv_bus_wdat_strobe : std_logic_vector(SLAVE_DATA_WIDTH/8 - 1 downto 0);
  signal int_slv_bus_wdat_last   : std_logic;
  signal int_slv_bus_wdat_valid  : std_logic;
  signal int_slv_bus_wdat_ready  : std_logic;
  signal int_m_axi_awaddr        : std_logic_vector(ADDR_WIDTH - 1 downto 0);
  signal int_m_axi_awlen         : std_logic_vector(MASTER_LEN_WIDTH - 1 downto 0);
  signal int_m_axi_awvalid       : std_logic;
  signal int_m_axi_awready       : std_logic;
  signal int_m_axi_awsize        : std_logic_vector(2 downto 0);
  signal int_m_axi_wdata         : std_logic_vector(MASTER_DATA_WIDTH - 1 downto 0);
  signal int_m_axi_wstrb         : std_logic_vector(MASTER_DATA_WIDTH/8 - 1 downto 0);
  signal int_m_axi_wlast         : std_logic;
  signal int_m_axi_wvalid        : std_logic;
  signal int_m_axi_wready        : std_logic;

  signal int_slv_bus_wreq_all    : std_logic_vector(FWACI(2) - 1 downto 0);
  signal int_slv_bus_wdat_all    : std_logic_vector(FWDCI(3) - 1 downto 0);
  signal slv_bus_wreq_all        : std_logic_vector(FWACI(2) - 1 downto 0);
  signal slv_bus_wdat_all        : std_logic_vector(FWDCI(3) - 1 downto 0);

begin

  -- Reset
  reset <= '1' when reset_n = '0' else
    '0';

  -- AWSIZE is constant  
  int_m_axi_awsize <= MASTER_SIZE;

  -- If the ratio is 1, simply pass through, but convert to AXI len
  pass_through_gen : if RATIO = 1 generate
    int_slv_bus_wreq_ready <= int_m_axi_awready;
    int_m_axi_awaddr       <= int_slv_bus_wreq_addr;
    int_m_axi_awlen        <= slv(resize(u(int_slv_bus_wreq_len) - 1, MASTER_LEN_WIDTH));
    int_m_axi_awvalid      <= int_slv_bus_wreq_valid;

    int_slv_bus_wdat_ready <= int_m_axi_wready;
    int_m_axi_wdata        <= int_slv_bus_wdat_data;
    int_m_axi_wstrb        <= int_slv_bus_wdat_strobe;
    int_m_axi_wlast        <= int_slv_bus_wdat_last;
    int_m_axi_wvalid       <= int_slv_bus_wdat_valid;
  end generate;

  -- If the ratio is larger than 1, instantiate the parallelizer, etc..
  parallelize_gen : if RATIO > 1 generate
    -----------------------------------------------------------------------------
    -- Write Request channels
    -----------------------------------------------------------------------------
    -- From slave port to BusBuffer
    int_slv_bus_wreq_ready <= buf_mst_wreq_ready;
    buf_mst_wreq_valid     <= int_slv_bus_wreq_valid;
    buf_mst_wreq_addr      <= int_slv_bus_wreq_addr;
    -- Length conversion; get the number of full words on the master
    -- Thus we have to shift with the log2ceil of the ratio, but round up
    -- in case its not an integer multiple of the ratio.
    buf_mst_wreq_len       <= slv(resize(shift(u(int_slv_bus_wreq_len), -LEN_SHIFT, true), MASTER_LEN_WIDTH + 1));

    -- From BusBuffer to AXI master port
    buf_slv_wreq_ready     <= m_axi_awready;
    int_m_axi_awaddr       <= buf_slv_wreq_addr;
    int_m_axi_awvalid      <= buf_slv_wreq_valid;
    -- Convert to AXI spec:
    int_m_axi_awlen        <= slv(resize(u(buf_slv_wreq_len) - 1, MASTER_LEN_WIDTH));
    -----------------------------------------------------------------------------
    -- Write Data channel
    -----------------------------------------------------------------------------
    -- From slave port to StreamGearboxParallelizer
    ser_dat_i_data         <= int_slv_bus_wdat_data;
    ser_dat_i_last         <= int_slv_bus_wdat_last;

    ser_stb_i_data         <= int_slv_bus_wdat_strobe;
    ser_stb_i_last         <= int_slv_bus_wdat_last;

    -- Split the write data stream into data and strobe for parallelization
    wdat_split : StreamSync
    generic map(
      NUM_INPUTS  => 1,
      NUM_OUTPUTS => 2
    )
    port map(
      clk          => clk,
      reset        => reset,
      in_valid(0)  => int_slv_bus_wdat_valid,
      in_ready(0)  => int_slv_bus_wdat_ready,
      out_valid(0) => ser_dat_i_valid,
      out_valid(1) => ser_stb_i_valid,
      out_ready(0) => ser_dat_i_ready,
      out_ready(1) => ser_stb_i_ready
    );

    -- Parallelize the data
    data_parallelizer : StreamGearboxParallelizer
    generic map(
      ELEMENT_WIDTH   => SLAVE_DATA_WIDTH,
      CTRL_WIDTH      => 0,
      IN_COUNT_MAX    => 1,
      IN_COUNT_WIDTH  => 1,
      OUT_COUNT_MAX   => RATIO,
      OUT_COUNT_WIDTH => log2ceil(RATIO)
    )
    port map(
      clk       => clk,
      reset     => reset,

      in_valid  => ser_dat_i_valid,
      in_ready  => ser_dat_i_ready,
      in_data   => ser_dat_i_data,
      in_last   => ser_dat_i_last,

      out_valid => ser_dat_o_valid,
      out_ready => ser_dat_o_ready,
      out_data  => ser_dat_o_data,
      out_last  => ser_dat_o_last
    );

    -- Parallelize the strobe
    strobe_parallelizer : StreamGearboxParallelizer
    generic map(
      ELEMENT_WIDTH   => SLAVE_DATA_WIDTH/8,
      CTRL_WIDTH      => 0,
      IN_COUNT_MAX    => 1,
      IN_COUNT_WIDTH  => 1,
      OUT_COUNT_MAX   => RATIO,
      OUT_COUNT_WIDTH => log2ceil(RATIO)
    )
    port map(
      clk       => clk,
      reset     => reset,

      in_valid  => ser_stb_i_valid,
      in_ready  => ser_stb_i_ready,
      in_data   => ser_stb_i_data,
      in_last   => ser_stb_i_last,

      out_valid => ser_stb_o_valid,
      out_ready => ser_stb_o_ready,
      out_data  => ser_stb_o_data,
      out_last  => ser_stb_o_last
    );

    -- Join the strobe and data streams
    wdat_join : StreamSync
    generic map(
      NUM_INPUTS  => 2,
      NUM_OUTPUTS => 1
    )
    port map(
      clk          => clk,
      reset        => reset,
      in_valid(0)  => ser_dat_o_valid,
      in_valid(1)  => ser_stb_o_valid,
      in_ready(0)  => ser_dat_o_ready,
      in_ready(1)  => ser_stb_o_ready,
      out_valid(0) => buf_mst_wdat_valid,
      out_ready(0) => buf_mst_wdat_ready
    );
    -- From StreamGearboxParallelizer to BusBuffer
    buf_mst_wdat_data   <= ser_dat_o_data;
    buf_mst_wdat_strobe <= ser_stb_o_data;
    buf_mst_wdat_last   <= ser_dat_o_last and ser_stb_o_last;

    ---------------------------------------------------------------------------
    fifo_gen : if ENABLE_FIFO = true generate
      -- Instantiate a FIFO
      BusWriteBuffer_inst : BusWriteBuffer
      generic map(
        BUS_ADDR_WIDTH => ADDR_WIDTH,
        BUS_LEN_WIDTH  => MASTER_LEN_WIDTH + 1,
        BUS_DATA_WIDTH => MASTER_DATA_WIDTH,
        FIFO_DEPTH     => MASTER_MAX_BURST + 1
      )
      port map(
        clk             => clk,
        reset           => reset,
        mst_wreq_valid  => buf_mst_wreq_valid,
        mst_wreq_ready  => buf_mst_wreq_ready,
        mst_wreq_addr   => buf_mst_wreq_addr,
        mst_wreq_len    => buf_mst_wreq_len,
        mst_wdat_valid  => buf_mst_wdat_valid,
        mst_wdat_ready  => buf_mst_wdat_ready,
        mst_wdat_data   => buf_mst_wdat_data,
        mst_wdat_strobe => buf_mst_wdat_strobe,
        mst_wdat_last   => buf_mst_wdat_last,
        slv_wreq_valid  => buf_slv_wreq_valid,
        slv_wreq_ready  => buf_slv_wreq_ready,
        slv_wreq_addr   => buf_slv_wreq_addr,
        slv_wreq_len    => buf_slv_wreq_len,
        slv_wdat_valid  => buf_slv_wdat_valid,
        slv_wdat_ready  => buf_slv_wdat_ready,
        slv_wdat_data   => buf_slv_wdat_data,
        slv_wdat_strobe => buf_slv_wdat_strobe,
        slv_wdat_last   => buf_slv_wdat_last
      );
    end generate;

    no_fifo_gen : if ENABLE_FIFO = false generate
      -- No FIFO, just pass through the channels
      buf_slv_wreq_valid  <= buf_mst_wreq_valid;
      buf_mst_wreq_ready  <= buf_slv_wreq_ready;
      buf_slv_wreq_addr   <= buf_mst_wreq_addr;
      buf_slv_wreq_len    <= buf_mst_wreq_len;

      buf_slv_wdat_valid  <= buf_mst_wdat_valid;
      buf_mst_wdat_ready  <= buf_slv_wdat_ready;
      buf_slv_wdat_data   <= buf_mst_wdat_data;
      buf_slv_wdat_strobe <= buf_mst_wdat_strobe;
      buf_slv_wdat_last   <= buf_mst_wdat_last;
    end generate;

    -- Write data channel BusWriteBuffer to AXI Master Port
    int_m_axi_wvalid   <= buf_slv_wdat_valid;
    buf_slv_wdat_ready <= int_m_axi_wready;
    int_m_axi_wdata    <= buf_slv_wdat_data;
    int_m_axi_wstrb    <= buf_slv_wdat_strobe;
    int_m_axi_wlast    <= buf_slv_wdat_last;

  end generate;

  -- Fletcher write request slice ----------------------------------------------
  slv_bus_wreq_all <= slv_bus_wreq_addr
    & slv_bus_wreq_len;

  fwac_slice : StreamBuffer
  generic map(
    MIN_DEPTH  => SLV_REQ_SLICE_DEPTH,
    DATA_WIDTH => FWACI(2)
  )
  port map(
    clk       => clk,
    reset     => reset,
    in_ready  => slv_bus_wreq_ready,
    in_valid  => slv_bus_wreq_valid,
    in_data   => slv_bus_wreq_all,
    out_ready => int_slv_bus_wreq_ready,
    out_valid => int_slv_bus_wreq_valid,
    out_data  => int_slv_bus_wreq_all
  );

  int_slv_bus_wreq_addr <= int_slv_bus_wreq_all(FWACI(2) - 1 downto FWACI(1));
  int_slv_bus_wreq_len  <= int_slv_bus_wreq_all(FWACI(1) - 1 downto FWACI(0));

  -- Fletcher write data slice -------------------------------------------------
  slv_bus_wdat_all      <= slv_bus_wdat_data
    & slv_bus_wdat_strobe
    & slv_bus_wdat_last;

  frdc_slice : StreamBuffer
  generic map(
    MIN_DEPTH  => SLV_DAT_SLICE_DEPTH,
    DATA_WIDTH => FWDCI(3)
  )
  port map(
    clk       => clk,
    reset     => reset,
    in_ready  => slv_bus_wdat_ready,
    in_valid  => slv_bus_wdat_valid,
    in_data   => slv_bus_wdat_all,
    out_ready => int_slv_bus_wdat_ready,
    out_valid => int_slv_bus_wdat_valid,
    out_data  => int_slv_bus_wdat_all
  );

  int_slv_bus_wdat_data   <= int_slv_bus_wdat_all(FWDCI(3) - 1 downto FWDCI(2));
  int_slv_bus_wdat_strobe <= int_slv_bus_wdat_all(FWDCI(2) - 1 downto FWDCI(1));
  int_slv_bus_wdat_last   <= int_slv_bus_wdat_all(FWDCI(0));

  -- output slices and completion logic ---------------------------------------

  output_proc : process (clk) is

    type aw_type is record
      valid : std_logic;
      addr  : std_logic_vector(ADDR_WIDTH - 1 downto 0);
      len   : std_logic_vector(MASTER_LEN_WIDTH - 1 downto 0);
      size  : std_logic_vector(2 downto 0);
      user  : std_logic_vector(7 downto 0);
    end record;

    type w_type is record
      valid : std_logic;
      data  : std_logic_vector(MASTER_DATA_WIDTH - 1 downto 0);
      strb  : std_logic_vector(MASTER_DATA_WIDTH/8 - 1 downto 0);
      last  : std_logic;
    end record;

    type b_type is record
      valid : std_logic;
    end record;

    -- There can be 2^(OUTST_BITS-1) outstanding requests.
    constant OUTST_BITS : natural := 10;

    -- System must be idle for 2^(IDLE_BITS-1) cycles.
    constant IDLE_BITS  : natural := 6;

    -- Address input holding register.
    variable ai         : aw_type;

    -- Address output holding register.
    variable ao         : aw_type;

    -- Data input holding register;
    variable di         : w_type;

    -- Data output holding register;
    variable do         : w_type;

    -- Response input holding register;
    variable ri         : b_type;

    -- Number of outstanding requests, diminished-one. MSB set means there are
    -- no requests, otherwise MSB-1 set means that the counter is full and
    -- input should be blocked.
    variable outst_req  : unsigned(OUTST_BITS - 1 downto 0);

    -- Number of requests that have been sent but don't have data yet. MSB set
    -- means there are no requests, otherwise MSB-1 set means that the counter
    -- is full and input should be blocked.
    variable outst_dat  : unsigned(OUTST_BITS - 1 downto 0);

    -- Write idle countdown. Set to 2^(IDLE_BITS-1)-1 when the system is not
    -- idle (outstanding requests or plat_complete_req is low), counts down to
    -- -1 otherwise. When the MSB is set, the system considered to be idle.
    variable idle_count : unsigned(IDLE_BITS - 1 downto 0);

    -- Registered version of the MSB of the idle_count counter.
    variable idle       : std_logic;

    -- State machine for completion.
    type state_type is (
      ST_RUNNING,
      ST_FENCE_REQ,
      ST_FENCE_DREQ,
      ST_FENCE_WAIT,
      ST_ACK_WAIT
    );
    variable state : state_type;

  begin
    if rising_edge(clk) then

      if ai.valid = '0' then
        ai.valid := int_m_axi_awvalid;
        ai.addr  := int_m_axi_awaddr;
        ai.len   := int_m_axi_awlen;
        ai.size  := int_m_axi_awsize;
        ai.user  := (others => '0');
      end if;

      if di.valid = '0' then
        di.valid := int_m_axi_wvalid;
        di.data  := int_m_axi_wdata;
        di.strb  := int_m_axi_wstrb;
        di.last  := int_m_axi_wlast;
      end if;

      if m_axi_awready = '1' then
        ao.valid := '0';
      end if;

      if m_axi_wready = '1' then
        do.valid := '0';
      end if;

      if ri.valid = '0' then
        ri.valid := m_axi_bvalid;
      end if;

      -- Handle idle countdown.
      idle := idle_count(IDLE_BITS - 1);
      if idle_count(IDLE_BITS - 1) = '0' then
        idle_count := idle_count - 1;
      end if;
      if (
        outst_req(OUTST_BITS - 1) = '0'
        or outst_dat(OUTST_BITS - 1) = '0'
        or plat_complete_req = '0'
        ) then
        idle_count := (IDLE_BITS - 1 => '0', others => '1');
        idle       := '0';
      end if;

      -- Forward incoming requests, tracking number of outstanding.
      if (
        state = ST_RUNNING
        and ai.valid = '1'
        and ao.valid = '0'
        and outst_req(OUTST_BITS - 1 downto OUTST_BITS - 2) /= "01"
        and outst_dat(OUTST_BITS - 1 downto OUTST_BITS - 2) /= "01"
        ) then
        ao        := ai;
        ai.valid  := '0';
        outst_req := outst_req + 1;
        outst_dat := outst_dat + 1;
        idle      := '0';
      end if;

      -- Forward incoming data, tracking number of outstanding.
      if (
        di.valid = '1'
        and do.valid = '0'
        and outst_dat(OUTST_BITS - 1) = '0'
        ) then
        do       := di;
        di.valid := '0';
        if do.last = '1' then
          outst_dat := outst_dat - 1;
        end if;
      end if;

      -- Read response stream to track number of outstanding.
      if (
        ri.valid = '1'
        and outst_req(OUTST_BITS - 1) = '0'
        ) then
        ri.valid  := '0';
        outst_req := outst_req - 1;
      end if;

      -- Handle state machine.
      plat_complete_ack <= '0';
      case state is
        when ST_RUNNING =>
          if plat_complete_req = '1' and idle = '1' then
            if SEND_WRITE_FENCE then
              state := ST_FENCE_REQ;
            else
              plat_complete_ack <= '1';
              state := ST_ACK_WAIT;
            end if;
          end if;

        when ST_FENCE_REQ =>
          if ao.valid = '0' then
            ao.addr  := (others => '0');
            ao.len   := (others => '0');
            ao.size  := MASTER_SIZE;
            ao.user  := (1 => '1', others => '0');
            ao.valid := '1';
            state    := ST_FENCE_DREQ;
          end if;

        when ST_FENCE_DREQ =>
          if do.valid = '0' then
            do.data  := (others => '0');
            do.strb  := (others => '0');
            do.last  := '1';
            do.valid := '1';
            state    := ST_FENCE_WAIT;
          end if;

        when ST_FENCE_WAIT =>
          if ri.valid = '1' then
            ri.valid := '0';
            plat_complete_ack <= '1';
            state := ST_ACK_WAIT;
          end if;

        when ST_ACK_WAIT =>
          state := ST_RUNNING;

      end case;

      if reset = '1' then
        ai.valid  := '0';
        ao.valid  := '0';
        di.valid  := '0';
        do.valid  := '0';
        ri.valid  := '0';
        outst_req := (others => '1');
        outst_dat := (others => '1');
        plat_complete_ack <= '0';
      end if;

      int_m_axi_awready <= not ai.valid;
      int_m_axi_wready  <= not di.valid;

      m_axi_awvalid     <= ao.valid;
      m_axi_awaddr      <= ao.addr;
      m_axi_awlen       <= ao.len;
      m_axi_awsize      <= ao.size;
      m_axi_awuser      <= ao.user;

      m_axi_wvalid      <= do.valid;
      m_axi_wdata       <= do.data;
      m_axi_wstrb       <= do.strb;
      m_axi_wlast       <= do.last;

      m_axi_bready      <= not ri.valid;

    end if;
  end process;

end architecture rtl;