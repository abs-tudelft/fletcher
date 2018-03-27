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
-- FIFO and only requests the write burst once the FIFO holds enough words,
-- such that the whole burst may be unloaded onto the bus at once. It also
-- provides last signaling for each burst, and provides a last_in_cmd signal
-- for the last word that accepted by the bus for the unlock stream to
-- synchronize to.
-------------------------------------------------------------------------------
entity BusWriteBuffer is
  generic (

    -- Bus address width.
    BUS_ADDR_WIDTH              : natural := 32;

    -- Bus burst length width.
    BUS_LEN_WIDTH               : natural := 8;

    -- Bus data width.
    BUS_DATA_WIDTH              : natural := 32;

    -- Minimum number of burst beats that can be stored in the FIFO. Rounded up
    -- to a power of two. This is also the maximum burst length supported.
    FIFO_DEPTH                  : natural := 16;

    -- The buffer will accept a request if the FIFO contents is bus_req_len /
    -- 2^LEN_SHIFT. Only use this if your input stream can deliver about as
    -- fast as the output stream.
    LEN_SHIFT                   : natural := 0;

    -- RAM configuration string for the response FIFO.
    RAM_CONFIG                  : string  := ""

  );
  port (

    -- Rising-edge sensitive clock and active-high synchronous reset for the
    -- bus and control logic side of the BufferWriter.
    clk                         : in  std_logic;
    reset                       : in  std_logic;

    -- Wether the buffer is full or empty
    full                        : out std_logic;
    empty                       : out std_logic;

    ---------------------------------------------------------------------------
    -- Master port.
    ---------------------------------------------------------------------------
    mst_req_valid               : out std_logic;
    mst_req_ready               : in  std_logic;
    mst_req_addr                : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    mst_req_len                 : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
    mst_wrd_valid               : out std_logic;
    mst_wrd_ready               : in  std_logic;
    mst_wrd_data                : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    mst_wrd_strobe              : out std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0);
    mst_wrd_last                : out std_logic;
    mst_wrd_last_in_cmd         : out std_logic;

    ---------------------------------------------------------------------------
    -- Slave port.
    ---------------------------------------------------------------------------
    slv_req_valid               : in  std_logic;
    slv_req_ready               : out std_logic;
    slv_req_addr                : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    slv_req_len                 : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
    slv_wrd_valid               : in  std_logic;
    slv_wrd_ready               : out std_logic;
    slv_wrd_data                : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    slv_wrd_strobe              : in  std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0);
    slv_wrd_last                : in  std_logic

  );
end BusWriteBuffer;

architecture Behavioral of BusWriteBuffer is

  -- Log2 of the FIFO depth.
  constant DEPTH_LOG2           : natural := log2ceil(FIFO_DEPTH);

  signal fifo_in_valid          : std_logic;
  signal fifo_in_ready          : std_logic;
  signal fifo_in_data           : std_logic_vector(BUS_DATA_WIDTH + BUS_DATA_WIDTH/8 downto 0);

  signal fifo_out_valid         : std_logic;
  signal fifo_out_ready         : std_logic;
  signal fifo_out_data          : std_logic_vector(BUS_DATA_WIDTH + BUS_DATA_WIDTH/8 downto 0);

  type fifo_record is record
    -- Number of words in FIFO
    count                       : unsigned(DEPTH_LOG2 downto 0);
    -- Number of words in current burst
    burst                       : unsigned(BUS_LEN_WIDTH-1 downto 0);
    -- Remember there had been a command accepted
    command                     : std_logic;
  end record;

  signal fifo : fifo_record;
  signal fifo_d : fifo_record;

  type output_record is record
    slv_req_ready               : std_logic;
    mst_req_valid               : std_logic;
    mst_wrd_last                : std_logic;
    full                        : std_logic;
    empty                       : std_logic;
  end record;

begin

  reg_proc: process(clk)
  begin
    if rising_edge(clk) then
      -- Register
      fifo <= fifo_d;

      -- Reset
      if reset = '1' then
        fifo.count <= (others => '0');
        fifo.burst <= (others => '0');
        fifo.command <= '0';
      end if;
    end if;
  end process;

  comb_proc: process(
    fifo,
    fifo_in_valid, fifo_in_ready,
    fifo_out_valid, fifo_out_ready,
    slv_req_len, slv_req_addr, slv_req_valid,
    mst_req_ready, mst_req_len
  )
    variable vr : fifo_record;
    variable vo : output_record;
  begin
    vr                          := fifo;

    -- Default outputs
    vo.slv_req_ready            := '0';
    vo.mst_req_valid            := '0';
    vo.mst_wrd_last             := '0';

    -- Increase FIFO count when something got inserted
    if fifo_in_valid = '1' and fifo_in_ready = '1' then
      vr.count                  := vr.count + 1;
    end if;

    -- Decrease FIFO count and burst count if something got written on the bus
    if fifo_out_valid = '1' and fifo_out_ready = '1' then
      vr.count                  := vr.count - 1;
      vr.burst                  := vr.burst - 1;
    end if;

    -- Determine empty
    if vr.count = to_unsigned(0, DEPTH_LOG2+1) then
      vo.empty                  := '1';
    else
      vo.empty                  := '0';
    end if;

    -- Determine full
    if vr.count = to_unsigned(2**DEPTH_LOG2, DEPTH_LOG2+1) then
      vo.full                   := '1';
    else
      vo.full                   := '0';
    end if;

    -- If the burst count is now zero, signal last burst beat to the bus
    if vr.burst = 0 and vr.command = '1' then
      vo.mst_wrd_last           := '1';
      vr.command                := '0';
    end if;

    -- If any previous burst was handled, a new request may be handshaked
    if vr.burst = 0 then
      vo.slv_req_ready          := mst_req_ready;
      vo.mst_req_valid          := slv_req_valid;
    end if;

    -- Back-pressure the bus write request when the FIFO doesn't hold enough
    -- words. This means the FIFO must fill up first. In this way, we can
    -- prevent blocking the bus with a burst that is not yet fully made
    -- available on the input side.
    -- Note that this is implemented to not lose generality of this
    -- BusWriteBuffer. It is not required by the BufferWriter implementation
    -- as it will not generate requests unless the buffer is sufficiently
    -- filled. This is somewhat the inverse of the BusReadBuffer, because
    -- there, it is known beforehand how much is going to be read. For the
    -- BusWriteBuffer it is not known until the last signal has appeared.
    -- Thus we must buffer and then request, not request and then buffer.
    -- LEN_SHIFT can be set to higher than 0 to burst at length / 2^LEN_SHIFT
    if vr.count < shift_right(u(slv_req_len), LEN_SHIFT) then
      vo.slv_req_ready          := '0';
      vo.mst_req_valid          := '0';
    end if;

    -- When a request is handshaked, set the burst counter to len
    if mst_req_ready = '1' and vo.mst_req_valid = '1' then
      vr.burst                  := u(mst_req_len);
      vr.command                := '1';
    end if;

    fifo_d                      <= vr;

    mst_wrd_last                <= vo.mst_wrd_last;
    mst_req_valid               <= vo.mst_req_valid;
    slv_req_ready               <= vo.slv_req_ready;

    full                        <= vo.full;
    empty                       <= vo.empty;
  end process;

  mst_req_addr <= slv_req_addr;
  mst_req_len <= slv_req_len;

  -- Connect FIFO inputs
  fifo_in_valid                 <= slv_wrd_valid;
  slv_wrd_ready                 <= fifo_in_ready;
  fifo_in_data                  <= slv_wrd_last & slv_wrd_data & slv_wrd_strobe;

  slv_write_buffer: StreamBuffer
    generic map (
      MIN_DEPTH                 => 2**DEPTH_LOG2,
      DATA_WIDTH                => BUS_DATA_WIDTH + BUS_DATA_WIDTH/8 + 1
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

  fifo_out_ready                <= mst_wrd_ready;
  mst_wrd_last_in_cmd           <= fifo_out_data(BUS_DATA_WIDTH + BUS_DATA_WIDTH/8);
  mst_wrd_data                  <= fifo_out_data(BUS_DATA_WIDTH + BUS_DATA_WIDTH/8-1 downto BUS_DATA_WIDTH/8);
  mst_wrd_strobe                <= fifo_out_data(BUS_DATA_WIDTH/8-1 downto 0);
  -- Only validate the write stream when a command was accepted.
  mst_wrd_valid                 <= fifo_out_valid and fifo.command;

end Behavioral;
