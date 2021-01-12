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

-------------------------------------------------------------------------------
-- This unit prevents blocking the bus while waiting for input on the write
-- data stream. It buffers until whatever burst length has been requested in a
-- FIFO and only requests the write burst on the master port once the FIFO
-- holds the number of requested words or some fraction of that. In this way,
-- the whole burst may be unloaded onto the bus at once. It can also provide
-- last signaling for each burst according to the requested length.
-------------------------------------------------------------------------------
entity BusWriteBuffer is
  generic (

    -- Bus address width.
    BUS_ADDR_WIDTH              : natural := 32;

    -- Bus burst length width.
    BUS_LEN_WIDTH               : natural := 8;

    -- Bus data width.
    BUS_DATA_WIDTH              : natural := 32;

    -- Width of any other data that can be passed through along with the data
    -- stream. Must be at least 1 to prevent null ranges
    CTRL_WIDTH                  : natural := 1;

    -- Minimum number of burst beats that can be stored in the FIFO. Rounded up
    -- to a power of two. This is also the maximum burst length supported.
    FIFO_DEPTH                  : natural := 16;

    -- The buffer will accept a request if the FIFO contents is bus_req_len /
    -- 2^LEN_SHIFT. Only use this if your input stream can deliver about as
    -- fast as the output stream.
    LEN_SHIFT                   : natural := 0;

    -- RAM configuration string for the response FIFO.
    RAM_CONFIG                  : string  := "";

    -- The output last signal is always generated based on the request length,
    -- except when this is set to "burst". Generates a simulation-only error if
    -- last signal is not correctly provided in "burst" mode
    SLV_LAST_MODE               : string := "burst";

    -- Instantiate a slice on the write request channel on the slave port
    SLV_REQ_SLICE               : boolean := true;

    -- Instantiate a slice on the write request channel on the master port
    MST_REQ_SLICE               : boolean := true;

    -- Instantiate a slice on the write data channel on the slave port
    SLV_DAT_SLICE               : boolean := true;

    -- Instantiate a slice on the write data channel on the master port
    MST_DAT_SLICE               : boolean := true;

    -- Instantiate a slice on the write response channel
    REP_SLICE                   : boolean := true

  );
  port (

    -- Rising-edge sensitive clock and active-high synchronous reset for the
    -- bus and control logic side of the BufferWriter.
    clk                         : in  std_logic;
    reset                       : in  std_logic;

    ---------------------------------------------------------------------------
    -- FIFO statistics
    ---------------------------------------------------------------------------
    full                        : out std_logic;
    empty                       : out std_logic;
    error                       : out std_logic;
    count                       : out std_logic_vector(log2ceil(FIFO_DEPTH) downto 0);

    ---------------------------------------------------------------------------
    -- Slave ports.
    ---------------------------------------------------------------------------
    slv_wreq_valid              : in  std_logic;
    slv_wreq_ready              : out std_logic;
    slv_wreq_addr               : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    slv_wreq_len                : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
    slv_wreq_last               : in  std_logic;

    slv_wdat_valid              : in  std_logic;
    slv_wdat_ready              : out std_logic;
    slv_wdat_data               : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    slv_wdat_strobe             : in  std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0);
    slv_wdat_last               : in  std_logic := '0';
    slv_wdat_ctrl               : in  std_logic_vector(CTRL_WIDTH-1 downto 0) := (others => 'U');

    slv_wrep_valid              : out std_logic;
    slv_wrep_ready              : in  std_logic;
    slv_wrep_ok                 : out std_logic;

    ---------------------------------------------------------------------------
    -- Master ports.
    ---------------------------------------------------------------------------
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
    mst_wdat_ctrl               : out std_logic_vector(CTRL_WIDTH-1 downto 0);

    mst_wrep_valid              : in  std_logic;
    mst_wrep_ready              : out std_logic;
    mst_wrep_ok                 : in  std_logic

  );
end BusWriteBuffer;

architecture Behavioral of BusWriteBuffer is

  -- Log2 of the FIFO depth.
  constant DEPTH_LOG2           : natural := log2ceil(FIFO_DEPTH);
  constant COUNT_FIFO_FULL      : unsigned(DEPTH_LOG2 downto 0) := to_unsigned(FIFO_DEPTH, DEPTH_LOG2+1);

  -- Request stream serialization indices.
  constant RSI : nat_array := cumulative((
    2 => 1,
    1 => BUS_LEN_WIDTH,
    0 => BUS_ADDR_WIDTH
  ));

  -- Fifo data stream serialization indices.
  constant FDI : nat_array := cumulative((
    3 => CTRL_WIDTH,
    2 => BUS_DATA_WIDTH/8,
    1 => BUS_DATA_WIDTH,
    0 => 1 -- last bit
  ));
  
  -- Sliced channels
  signal s_mst_wreq_valid       : std_logic;
  signal s_mst_wreq_ready       : std_logic;
  signal s_mst_wreq_addr        : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal s_mst_wreq_len         : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
  signal s_mst_wreq_last        : std_logic;
  signal s_mst_wreq_all         : std_logic_vector(RSI(3)-1 downto 0);
  signal mst_wreq_all           : std_logic_vector(RSI(3)-1 downto 0);

  signal s_slv_wreq_valid       : std_logic;
  signal s_slv_wreq_ready       : std_logic;
  signal s_slv_wreq_addr        : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal s_slv_wreq_len         : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
  signal s_slv_wreq_last        : std_logic;
  signal s_slv_wreq_all         : std_logic_vector(RSI(3)-1 downto 0);
  signal slv_wreq_all           : std_logic_vector(RSI(3)-1 downto 0);

  signal s_slv_wdat_valid       : std_logic;
  signal s_slv_wdat_ready       : std_logic;
  signal s_slv_wdat_data        : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal s_slv_wdat_strobe      : std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0);
  signal s_slv_wdat_last        : std_logic;
  signal s_slv_wdat_ctrl        : std_logic_vector(CTRL_WIDTH-1 downto 0);
  signal slv_wdat_all           : std_logic_vector(FDI(4)-1 downto 0);
  signal s_slv_wdat_all         : std_logic_vector(FDI(4)-1 downto 0);

  signal s_mst_wdat_valid       : std_logic;
  signal s_mst_wdat_ready       : std_logic;
  signal s_mst_wdat_data        : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal s_mst_wdat_strobe      : std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0);
  signal s_mst_wdat_last        : std_logic;
  signal s_mst_wdat_ctrl        : std_logic_vector(CTRL_WIDTH-1 downto 0);
  signal s_mst_wdat_all         : std_logic_vector(FDI(4)-1 downto 0);
  signal mst_wdat_all           : std_logic_vector(FDI(4)-1 downto 0);

  signal fifo_in_valid           : std_logic;
  signal fifo_in_ready           : std_logic;
  signal fifo_in_data            : std_logic_vector(FDI(4)-1 downto 0);

  signal fifo_out_valid          : std_logic;
  signal fifo_out_ready          : std_logic;
  signal fifo_out_data           : std_logic_vector(FDI(4)-1 downto 0);

  type state_type is (IDLE, REQ, BURST);

  type reg_record is record
    state                        : state_type;
    count                        : unsigned(DEPTH_LOG2 downto 0);
    error                        : std_logic;

    wreq_addr                    : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    wreq_len                     : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
    wreq_last                    : std_logic;
  end record;

  signal r : reg_record;
  signal d : reg_record;

  type output_record is record
    slv_wreq_ready               : std_logic;

    mst_wreq_valid               : std_logic;
    mst_wreq_addr                : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    mst_wreq_len                 : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
    mst_wreq_last                : std_logic;

    fifo_out_ready               : std_logic;

    mst_wdat_valid               : std_logic;
    mst_wdat_last                : std_logic;

    full                         : std_logic;
    empty                        : std_logic;
  end record;

begin
  -----------------------------------------------------------------------------
  -- State machine
  -----------------------------------------------------------------------------
  seq_proc: process(clk) is
  begin
    if rising_edge(clk) then
      -- Register
      r                         <= d;

      -- Reset
      if reset = '1' then
        r.state                 <= IDLE;
        r.count                 <= (others => '0');
        r.error                 <= '0';
      end if;
    end if;
  end process;

  comb_proc: process(r,
    fifo_in_valid, fifo_in_ready,
    fifo_out_valid, fifo_out_data(FDI(0)),
    s_slv_wreq_last, s_slv_wreq_len, s_slv_wreq_addr, s_slv_wreq_valid,
    s_mst_wreq_ready,
    s_mst_wdat_ready
  ) is
    variable vr                 : reg_record;
    variable vo                 : output_record;
  begin
    vr                          := r;

    -- Increase FIFO count when something got inserted
    if fifo_in_valid = '1' and fifo_in_ready = '1' then
      vr.count                  := vr.count + 1;
    end if;

    -- Default outputs
    vo.slv_wreq_ready           := '0';
    vo.mst_wreq_valid           := '0';
    vo.mst_wdat_valid           := '0';
    vo.mst_wdat_last            := '0';
    vo.fifo_out_ready           := '0';

    vo.mst_wreq_addr            := vr.wreq_addr;
    vo.mst_wreq_len             := vr.wreq_len;
    vo.mst_wreq_last            := vr.wreq_last;

    case vr.state is
      when IDLE =>
        vo.slv_wreq_ready       := '1';

        -- A request is made, register it.
        if s_slv_wreq_valid = '1' then
          vr.wreq_last          := s_slv_wreq_last;
          vr.wreq_len           := s_slv_wreq_len;
          vr.wreq_addr          := s_slv_wreq_addr;
          vr.state              := REQ;
        end if;

      when REQ =>
        -- Make the request valid on the master port
        vo.mst_wreq_addr        := vr.wreq_addr;
        vo.mst_wreq_len         := vr.wreq_len;
        vo.mst_wreq_last        := vr.wreq_last;

        -- Validate only when enough words have been loaded into the FIFO
        if vr.count >= unsigned(vr.wreq_len) then
          vo.mst_wreq_valid       := '1';
        else
          vo.mst_wreq_valid       := '0';
        end if;

        -- Wait for handshake
        if s_mst_wreq_ready = '1' and vo.mst_wreq_valid = '1' then
          vr.state              := BURST;
        end if;

      when BURST =>
        -- Allow the FIFO to unload
        vo.mst_wdat_valid       := fifo_out_valid;
        vo.fifo_out_ready       := s_mst_wdat_ready;

        -- Wait for acceptance
        if vo.mst_wdat_valid = '1' and vo.fifo_out_ready = '1' then
          -- Decrease the burst amount
          vr.wreq_len           := std_logic_vector(unsigned(vr.wreq_len) - 1);
        end if;

        -- This is the last transfer
        if unsigned(vr.wreq_len) = 0 then
          -- Determine where last should come from
          if SLV_LAST_MODE = "burst" then
            -- Last signal comes from FIFO
            vo.mst_wdat_last        := fifo_out_data(FDI(0));

            -- Check if the last signal was properly asserted.
            if fifo_out_data(FDI(0)) /= '1' then
              -- pragma translate off
                report "Bus write buffer with SLV_LAST_MODE set to burst "
                     & "expected last signal to be high."
                severity failure;
              -- pragma translate on
              vr.error          := '1';
            end if;

          else
            -- The slave last signal is not used for the purpose of delimiting
            -- bursts. Assert the last signal based on the request length.
            vo.mst_wdat_last        := '1';
          end if;

          -- A request is made, register it.
          if s_slv_wreq_valid = '1' then
            vo.slv_wreq_ready   := '1';
            vr.wreq_last        := s_slv_wreq_last;
            vr.wreq_len         := s_slv_wreq_len;
            vr.wreq_addr        := s_slv_wreq_addr;
            vr.state            := REQ;
          else
            vr.state            := IDLE;
          end if;
        end if;

    end case;

    -- Decrease FIFO count when something got written on the bus
    if s_mst_wdat_ready = '1' and vo.mst_wdat_valid = '1' then
      vr.count                  := vr.count - 1;
    end if;

    -- Determine empty
    if vr.count = to_unsigned(0, DEPTH_LOG2+1) then
      vo.empty                  := '1';
    else
      vo.empty                  := '0';
    end if;

    -- Determine full
    if vr.count = COUNT_FIFO_FULL then
      vo.full                   := '1';
    else
      vo.full                   := '0';
    end if;


    d                           <= vr;

    s_slv_wreq_ready            <= vo.slv_wreq_ready;

    s_mst_wreq_valid            <= vo.mst_wreq_valid;
    s_mst_wreq_addr             <= vo.mst_wreq_addr;
    s_mst_wreq_len              <= vo.mst_wreq_len;
    s_mst_wreq_last             <= vo.mst_wreq_last;

    s_mst_wdat_valid            <= vo.mst_wdat_valid;
    s_mst_wdat_last             <= vo.mst_wdat_last;

    fifo_out_ready              <= vo.fifo_out_ready;

    full                        <= vo.full;
    empty                       <= vo.empty;
  end process;

  error                         <= r.error;
  count                         <= std_logic_vector(r.count);

  -----------------------------------------------------------------------------
  -- FIFO
  -----------------------------------------------------------------------------
  fifo_in_valid                 <= s_slv_wdat_valid;
  s_slv_wdat_ready              <= fifo_in_ready;

  fifo_in_data(FDI(4)-1 downto FDI(3)) <= s_slv_wdat_ctrl;
  fifo_in_data(FDI(3)-1 downto FDI(2)) <= s_slv_wdat_strobe;
  fifo_in_data(FDI(2)-1 downto FDI(1)) <= s_slv_wdat_data;
  fifo_in_data(                FDI(0)) <= s_slv_wdat_last;

  fifo_inst: StreamBuffer
    generic map (
      MIN_DEPTH                 => 2**DEPTH_LOG2,
      DATA_WIDTH                => FDI(4)
    )
    port map (
      clk                       => clk,
      reset                     => reset,

      in_valid                  => fifo_in_valid,
      in_ready                  => fifo_in_ready,
      in_data                   => fifo_in_data,

      out_valid                 => fifo_out_valid,
      out_ready                 => fifo_out_ready,
      out_data                  => fifo_out_data
    );

  s_mst_wdat_ctrl               <= fifo_out_data(FDI(4)-1 downto FDI(3));
  s_mst_wdat_strobe             <= fifo_out_data(FDI(3)-1 downto FDI(2));
  s_mst_wdat_data               <= fifo_out_data(FDI(2)-1 downto FDI(1));


  ------------------------------------------------------------------------------
  -- Slave write data channel slice
  ------------------------------------------------------------------------------
  slv_wdat_all(FDI(4)-1 downto FDI(3)) <= slv_wdat_ctrl;
  slv_wdat_all(FDI(3)-1 downto FDI(2)) <= slv_wdat_strobe;
  slv_wdat_all(FDI(2)-1 downto FDI(1)) <= slv_wdat_data;
  slv_wdat_all(                FDI(0)) <= slv_wdat_last;

  slave_wdat_slice : StreamBuffer
    generic map (
      MIN_DEPTH                 => sel(SLV_DAT_SLICE, 2, 0),
      DATA_WIDTH                => FDI(4)
    )
    port map (
      clk                       => clk,
      reset                     => reset,

      in_valid                  => slv_wdat_valid,
      in_ready                  => slv_wdat_ready,
      in_data                   => slv_wdat_all,

      out_valid                 => s_slv_wdat_valid,
      out_ready                 => s_slv_wdat_ready,
      out_data                  => s_slv_wdat_all
    );

  s_slv_wdat_ctrl   <= s_slv_wdat_all(FDI(4)-1 downto FDI(3));
  s_slv_wdat_strobe <= s_slv_wdat_all(FDI(3)-1 downto FDI(2));
  s_slv_wdat_data   <= s_slv_wdat_all(FDI(2)-1 downto FDI(1));
  s_slv_wdat_last   <= s_slv_wdat_all(                FDI(0));

  -----------------------------------------------------------------------------
  -- Master write data channel slice
  -----------------------------------------------------------------------------
  s_mst_wdat_all(FDI(4)-1 downto FDI(3)) <= s_mst_wdat_ctrl;
  s_mst_wdat_all(FDI(3)-1 downto FDI(2)) <= s_mst_wdat_strobe;
  s_mst_wdat_all(FDI(2)-1 downto FDI(1)) <= s_mst_wdat_data;
  s_mst_wdat_all(                FDI(0)) <= s_mst_wdat_last;

  master_wdat_slice : StreamBuffer
    generic map (
      MIN_DEPTH                 => sel(MST_DAT_SLICE, 2, 0),
      DATA_WIDTH                => FDI(4)
    )
    port map (
      clk                       => clk,
      reset                     => reset,

      in_valid                  => s_mst_wdat_valid,
      in_ready                  => s_mst_wdat_ready,
      in_data                   => s_mst_wdat_all,

      out_valid                 => mst_wdat_valid,
      out_ready                 => mst_wdat_ready,
      out_data                  => mst_wdat_all
    );

  mst_wdat_ctrl   <= mst_wdat_all(FDI(4)-1 downto FDI(3));
  mst_wdat_strobe <= mst_wdat_all(FDI(3)-1 downto FDI(2));
  mst_wdat_data   <= mst_wdat_all(FDI(2)-1 downto FDI(1));
  mst_wdat_last   <= mst_wdat_all(                FDI(0));

  -----------------------------------------------------------------------------
  -- Slave write request channel slice
  -----------------------------------------------------------------------------
  slv_wreq_all(RSI(2)) <= slv_wreq_last;
  slv_wreq_all(RSI(2)-1 downto RSI(1)) <= slv_wreq_len;
  slv_wreq_all(RSI(1)-1 downto RSI(0)) <= slv_wreq_addr;

  slave_wreq_slice : StreamBuffer
    generic map (
      MIN_DEPTH                 => sel(SLV_REQ_SLICE, 2, 0),
      DATA_WIDTH                => RSI(3)
    )
    port map (
      clk                       => clk,
      reset                     => reset,

      in_valid                  => slv_wreq_valid,
      in_ready                  => slv_wreq_ready,
      in_data                   => slv_wreq_all,

      out_valid                 => s_slv_wreq_valid,
      out_ready                 => s_slv_wreq_ready,
      out_data                  => s_slv_wreq_all
    );

  s_slv_wreq_last <= s_slv_wreq_all(RSI(2));
  s_slv_wreq_len  <= s_slv_wreq_all(RSI(2)-1 downto RSI(1));
  s_slv_wreq_addr <= s_slv_wreq_all(RSI(1)-1 downto RSI(0));

  -----------------------------------------------------------------------------
  -- Master write request channel slice
  -----------------------------------------------------------------------------
  s_mst_wreq_all(RSI(2)) <= s_mst_wreq_last;
  s_mst_wreq_all(RSI(2)-1 downto RSI(1)) <= s_mst_wreq_len;
  s_mst_wreq_all(RSI(1)-1 downto RSI(0)) <= s_mst_wreq_addr;

  master_wreq_slice : StreamBuffer
    generic map (
      MIN_DEPTH                 => sel(MST_REQ_SLICE, 2, 0),
      DATA_WIDTH                => RSI(3)
    )
    port map (
      clk                       => clk,
      reset                     => reset,

      in_valid                  => s_mst_wreq_valid,
      in_ready                  => s_mst_wreq_ready,
      in_data                   => s_mst_wreq_all,

      out_valid                 => mst_wreq_valid,
      out_ready                 => mst_wreq_ready,
      out_data                  => mst_wreq_all
    );

  mst_wreq_last <= mst_wreq_all(RSI(2));
  mst_wreq_len  <= mst_wreq_all(RSI(2)-1 downto RSI(1));
  mst_wreq_addr <= mst_wreq_all(RSI(1)-1 downto RSI(0));

  -----------------------------------------------------------------------------
  -- Write response channel slice
  -----------------------------------------------------------------------------
  wrep_slice : StreamBuffer
    generic map (
      MIN_DEPTH                 => sel(REP_SLICE, 2, 0),
      DATA_WIDTH                => 1
    )
    port map (
      clk                       => clk,
      reset                     => reset,

      in_valid                  => mst_wrep_valid,
      in_ready                  => mst_wrep_ready,
      in_data(0)                => mst_wrep_ok,

      out_valid                 => slv_wrep_valid,
      out_ready                 => slv_wrep_ready,
      out_data(0)               => slv_wrep_ok
    );

end Behavioral;
