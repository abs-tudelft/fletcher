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

-------------------------------------------------------------------------------
-- This unit prevents blocking the bus while waiting for input on the write
-- data stream. It buffers until whatever burst length has been requested in a
-- FIFO and only requests the write burst on the master port once the FIFO
-- holds the number of requested words or some fraction of that. In this way,
-- the whole burst may be unloaded onto the bus at once. It also provides last
-- signaling for each burst, and optionally provides a last_in_cmd signal for
-- the last word that was accepted by the bus for the unlock stream to
-- synchronize to, if set to streaming mode.
-------------------------------------------------------------------------------
entity BusWriteBuffer is
  generic (

    -- Bus address width.
    BUS_ADDR_WIDTH              : natural := 32;

    -- Bus burst length width.
    BUS_LEN_WIDTH               : natural := 8;

    -- Bus data width.
    BUS_DATA_WIDTH              : natural := 32;

    -- Bus strobe width.
    BUS_STROBE_WIDTH            : natural := 32/8;

    -- Minimum number of burst beats that can be stored in the FIFO. Rounded up
    -- to a power of two. This is also the maximum burst length supported.
    FIFO_DEPTH                  : natural := 16;

    -- The buffer will accept a request if the FIFO contents is bus_req_len /
    -- 2^LEN_SHIFT. Only use this if your input stream can deliver about as
    -- fast as the output stream.
    LEN_SHIFT                   : natural := 0;

    -- RAM configuration string for the response FIFO.
    RAM_CONFIG                  : string  := "";

    -- The last signal on the slave port is a "last in stream" signal and not
    -- a "last in burst" signal. The output last signal is always generated
    -- based on the requests. However, if this is set to "burst", an error
    -- is generated if the last signal is not asserted when expected from
    -- the requested burst length.
    SLV_LAST_MODE               : string := "burst";
    
    -- Instantiate a slice on the write data channel on the slave port
    SLV_DATA_SLICE              : boolean := true;
    
    -- Instantiate a slice on the write data channel on the master port
    MST_DATA_SLICE              : boolean := true

  );
  port (

    -- Rising-edge sensitive clock and active-high synchronous reset for the
    -- bus and control logic side of the BufferWriter.
    clk                         : in  std_logic;
    reset                       : in  std_logic;

    -- Wether the buffer is full or empty
    full                        : out std_logic;
    empty                       : out std_logic;
    error                       : out std_logic;

    ---------------------------------------------------------------------------
    -- Slave ports.
    ---------------------------------------------------------------------------
    slv_wreq_valid              : in  std_logic;
    slv_wreq_ready              : out std_logic;
    slv_wreq_addr               : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    slv_wreq_len                : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0);

    slv_wdat_valid              : in  std_logic;
    slv_wdat_ready              : out std_logic;
    slv_wdat_data               : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    slv_wdat_strobe             : in  std_logic_vector(BUS_STROBE_WIDTH-1 downto 0);
    slv_wdat_last               : in  std_logic;

    ---------------------------------------------------------------------------
    -- Master ports.
    ---------------------------------------------------------------------------
    mst_wreq_valid              : out std_logic;
    mst_wreq_ready              : in  std_logic;
    mst_wreq_addr               : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    mst_wreq_len                : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);

    mst_wdat_valid              : out std_logic;
    mst_wdat_ready              : in  std_logic;
    mst_wdat_data               : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    mst_wdat_strobe             : out std_logic_vector(BUS_STROBE_WIDTH-1 downto 0);
    mst_wdat_last               : out std_logic;
    mst_wdat_last_in_cmd        : out std_logic

  );
end BusWriteBuffer;

architecture Behavioral of BusWriteBuffer is

  -- Log2 of the FIFO depth.
  constant DEPTH_LOG2            : natural := log2ceil(FIFO_DEPTH);
  constant COUNT_FIFO_FULL       : unsigned(DEPTH_LOG2-1 downto 0) := (others => '1');
  
  signal s_slv_wdat_valid        : std_logic;
  signal s_slv_wdat_ready        : std_logic;
  signal s_slv_wdat_data         : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal s_slv_wdat_strobe       : std_logic_vector(BUS_STROBE_WIDTH-1 downto 0);
  signal s_slv_wdat_last         : std_logic;

  signal fifo_in_valid           : std_logic;
  signal fifo_in_ready           : std_logic;
  signal fifo_in_data            : std_logic_vector(BUS_DATA_WIDTH+BUS_STROBE_WIDTH downto 0);

  signal fifo_out_valid          : std_logic;
  signal fifo_out_ready          : std_logic;
  signal fifo_out_data           : std_logic_vector(BUS_DATA_WIDTH+BUS_STROBE_WIDTH downto 0);

  type state_type is (IDLE, REQ, BURST);

  type reg_record is record
    state                        : state_type;
    count                        : unsigned(DEPTH_LOG2 downto 0);
    error                        : std_logic;

    wreq_addr                    : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    wreq_len                     : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
  end record;

  signal r : reg_record;
  signal d : reg_record;

  type output_record is record
    slv_wreq_ready               : std_logic;

    mst_wreq_valid               : std_logic;
    mst_wreq_addr                : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    mst_wreq_len                 : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);

    fifo_out_ready               : std_logic;

    mst_wdat_valid               : std_logic;
    mst_wdat_last                : std_logic;
    mst_wdat_last_in_cmd         : std_logic;

    full                         : std_logic;
    empty                        : std_logic;
  end record;

begin

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

  comb_proc: process(
    r,
    fifo_in_valid, fifo_in_ready,
    fifo_out_valid, fifo_out_ready, fifo_out_data(0),
    slv_wreq_len, slv_wreq_addr, slv_wreq_valid,
    mst_wreq_ready,
    mst_wdat_ready
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
    vo.mst_wdat_last_in_cmd     := '0';
    vo.fifo_out_ready           := '0';

    case vr.state is
      when IDLE =>
        vo.slv_wreq_ready       := '1';

        -- A request is made, register it.
        if slv_wreq_valid = '1' then
          vr.wreq_len           := slv_wreq_len;
          vr.wreq_addr          := slv_wreq_addr;
          vr.state              := REQ;
        end if;

      when REQ =>
        -- Make the request valid on the master port
        vo.mst_wreq_addr        := vr.wreq_addr;
        vo.mst_wreq_len         := vr.wreq_len;

        -- Validate only when enough words have been loaded into the FIFO
        if vr.count >= unsigned(vr.wreq_len) then
          vo.mst_wreq_valid       := '1';
        else
          vo.mst_wreq_valid       := '0';
        end if;

        -- Wait for handshake
        if mst_wreq_ready = '1' and vo.mst_wreq_valid = '1' then
          vr.state              := BURST;
        end if;

      when BURST =>
        -- Allow the FIFO to unload
        vo.mst_wdat_valid       := fifo_out_valid;
        vo.fifo_out_ready       := mst_wdat_ready;

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
            vo.mst_wdat_last        := fifo_out_data(0);

            -- Check if the last signal was properly asserted.
            if fifo_out_data(0) /= '1' then
              -- pragma translate off
                report "Bus write buffer with SLV_LAST_MODE set to burst "
                     & "expected last signal to be high."
                severity failure;
              -- pragma translate on
              vr.error          := '1';
            end if;

          else
            -- The BusWriteBuffer slave last signal signifies the end of a
            -- stream. Assert the last signal based on the request length and
            -- grab the last_in_cmd signal from the FIFO.
            vo.mst_wdat_last        := '1';
            vo.mst_wdat_last_in_cmd := fifo_out_data(0);
          end if;

          -- A request is made, register it.
          if slv_wreq_valid = '1' then
            vo.slv_wreq_ready   := '1';
            vr.wreq_len         := slv_wreq_len;
            vr.wreq_addr        := slv_wreq_addr;
            vr.state            := REQ;
          else
            vr.state            := IDLE;
          end if;
        end if;

    end case;

    -- Decrease FIFO count when something got written on the bus
    if mst_wdat_ready = '1' and vo.mst_wdat_valid = '1' then
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

    slv_wreq_ready              <= vo.slv_wreq_ready;

    mst_wreq_valid              <= vo.mst_wreq_valid;
    mst_wreq_addr               <= vo.mst_wreq_addr;
    mst_wreq_len                <= vo.mst_wreq_len;

    mst_wdat_valid              <= vo.mst_wdat_valid;
    mst_wdat_last               <= vo.mst_wdat_last;
    mst_wdat_last_in_cmd        <= vo.mst_wdat_last_in_cmd;
    mst_wdat_data               <= fifo_out_data(BUS_DATA_WIDTH downto 1);
    mst_wdat_strobe             <= fifo_out_data(BUS_DATA_WIDTH+BUS_STROBE_WIDTH downto BUS_DATA_WIDTH+1);

    fifo_out_ready              <= vo.fifo_out_ready;

    full                        <= vo.full;
    empty                       <= vo.empty;
    error                       <= vr.error;

  end process;

  -- Connect FIFO inputs
  fifo_in_valid                 <= s_slv_wdat_valid;
  s_slv_wdat_ready              <= fifo_in_ready;

  fifo_in_data                  <= s_slv_wdat_strobe & s_slv_wdat_data & s_slv_wdat_last;

  slv_write_buffer: StreamBuffer
    generic map (
      MIN_DEPTH                 => 2**DEPTH_LOG2,
      DATA_WIDTH                => BUS_DATA_WIDTH + BUS_STROBE_WIDTH + 1
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

  slave_slice_gen: if SLV_DATA_SLICE generate
    -- Write data stream serialization indices.
    constant WSI : nat_array := cumulative((
      2 => 1,
      1 => BUS_STROBE_WIDTH,
      0 => BUS_DATA_WIDTH
    ));
    
    signal slv_wdat_all   : std_logic_vector(WSI(3)-1 downto 0);
    signal s_slv_wdat_all : std_logic_vector(WSI(3)-1 downto 0);
  begin
    
    slv_wdat_all(                WSI(2)) <= slv_wdat_last;
    slv_wdat_all(WSI(2)-1 downto WSI(1)) <= slv_wdat_strobe;
    slv_wdat_all(WSI(1)-1 downto      0) <= slv_wdat_data;
    
    wdat_in_slice : StreamBuffer
    generic map (
      MIN_DEPTH                 => sel(SLV_DATA_SLICE, 2, 0),
      DATA_WIDTH                => BUS_DATA_WIDTH + BUS_STROBE_WIDTH + 1
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
    
  s_slv_wdat_last   <= s_slv_wdat_all(                WSI(2));
  s_slv_wdat_strobe <= s_slv_wdat_all(WSI(2)-1 downto WSI(1));
  s_slv_wdat_data   <= s_slv_wdat_all(WSI(1)-1 downto      0);
  end generate;
  no_slave_slice_gen: if not SLV_DATA_SLICE generate
    s_slv_wdat_valid   <= slv_wdat_valid;
    slv_wdat_ready     <= s_slv_wdat_ready;
    s_slv_wdat_data    <= slv_wdat_data;
    s_slv_wdat_strobe  <= slv_wdat_strobe;
    s_slv_wdat_last    <= slv_wdat_last;
  end generate;

end Behavioral;
