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
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

library work;
use work.Streams.all;
use work.Utils.all;

-- This is a highly flexible unit for transforming the "shape" of data packets
-- in streams supporting multiple elements per cycle. In terms of functionality
-- it is essentially a combination of a StreamGearbox and a StreamNormalizer,
-- but unlike both of those it is pipelined, allowing it to handle much wider
-- streams at a given frequency. It will also run without stalls in all cases
-- as long as all streams keep up (i.e. it won't ever stall due to inconvenient
-- data alignment in the streams). This does however come at a significant area
-- cost, so don't use this unit lightly.
--
-- By the "shape" of a data packet we mean the values of dvalid and count for
-- the transfers making up the stream. For instance:
--
--                   .--------.-------.------.
--                   | dvalid | count | last |
--   .---------------+--------+-------+------|    .------------.
--   | Transfer 1:   |      1 |     4 |    0 |    | A  B  C  D |
--   |               |        |       |      |    |      .-----'
--   | Transfer 2:   |      1 |     2 |    0 |    | E  F |
--   |               |        |       |      |    |      '--.
--   | Transfer 3:   |      1 |     3 |    0 |    | G  H  I |
--   |               |        |       |      |    |.--------'
--   | Transfer 4:   |      0 |     - |    0 |    ||
--   |               |        |       |      |    |'--------.
--   | Transfer 5:   |      1 |     3 |    0 |    | J  K  L |
--   |               |        |       |      |    |.--------'
--   | Transfer 6:   |      0 |     - |    1 |    ||
--   '---------------'--------'-------'------'    ''
--
-- The exact same packet can be represented much more efficiently as follows
-- when (for example) 5 elements can be transferred per cycle:
--
--                   .--------.-------.------.
--                   | dvalid | count | last |
--   .---------------+--------+-------+------|    .---------------.
--   | Transfer 1:   |      1 |     5 |    0 |    | A  B  C  D  E |
--   |               |        |       |      |    |               |
--   | Transfer 2:   |      1 |     5 |    0 |    | F  G  H  I  J |
--   |               |        |       |      |    |      .--------'
--   | Transfer 3:   |      1 |     2 |    1 |    | K  L |
--   '---------------'--------'-------'------'    '------'
--
-- This is the operation that this unit will perform when the control input
-- stream is unused: it ensures that all transfers that make up the packet
-- except for the last one use the maximum parallelism available. If the input
-- stream isn't fast enough for this, it just inserts stall cycles by releasing
-- valid. This is particularly useful to do in front of a clock domain crossing
-- to a lower speed domain, or in front of an arbiter that combines multiple
-- such streams together (in this case you'll want a FIFO in between that's
-- large enough for at least one maximum-sized packet). More generally, you can
-- use this unit to make an arbitrarily parallel, fully packed output steam
-- from any kind of input stream, which makes this unit a gearbox in addition
-- to a normalizer.
--
-- In some cases though, you don't want the maximum available parallelism. This
-- is for instance the case when you want to insert packet boundaries in
-- arbitrary places. StreamNormalizer lets you do this as well, but the shape
-- information is supplied synchronous to the output stream, which means that
-- all the requisite shifting must be done combinatorially. Instead, this unit
-- supports an additional input stream for this information. This stream
-- consists of only shape information, and applies it to the input data stream
-- (as long as the "last" flag of the data input stream is cleared). So, for
-- each control input stream transfer, there will be exactly one output stream
-- transfer.
--
-- This unit will assert the "last" flag in the output stream when either the
-- control input stream or the data input stream has this flag set. When the
-- data input "last" flag is set while the control input stream is not
-- requesting last, less data may be transferred than requested by the control
-- input stream. An error strobe output is available to signal this.

entity StreamReshaper is
  generic (

    -- Width of a data element.
    ELEMENT_WIDTH               : natural;

    -- Maximum number of elements per clock in the data input stream.
    IN_COUNT_MAX                : natural := 1;

    -- The number of bits in the count vectors. This must be at least
    -- ceil(log2(COUNT_MAX)) and must be at least 1. If COUNT_MAX is a power of
    -- two and this value equals log2(COUNT_MAX), a zero count implies that all
    -- entries are valid (i.e., there is an implicit '1' bit in front).
    IN_COUNT_WIDTH              : natural := 1;

    -- Same as above, but for the output stream and the control input stream.
    OUT_COUNT_MAX               : natural := 1;
    OUT_COUNT_WIDTH             : natural := 1;

    -- The amount of buffering that should be applied to the data and control
    -- input streams. It is strongly discouraged to set this to 0 (no
    -- buffering) due to the complexity of the control logic. You shouldn't be
    -- using this block if latency is a concern anyway.
    DIN_BUFFER_DEPTH            : natural := 2;
    CIN_BUFFER_DEPTH            : natural := 2;

    -- Width of the unused control data vector, passed from the control input
    -- stream to the output stream. Should be 1 or more to prevent null
    -- vectors.
    CTRL_WIDTH                  : natural := 1;

    -- RAM configuration. This is passed directly to the Ram1R1W instances used
    -- for the FIFOs, if FIFOs are inserted.
    RAM_CONFIG                  : string := "";

    -- Number of shifts per pipeline stage. The muxes will get
    -- 2**SHIFTS_PER_STAGE inputs, not counting control.
    SHIFTS_PER_STAGE            : natural := 3

  );
  port (

    -- Rising-edge sensitive clock.
    clk                         : in  std_logic;

    -- Active-high synchronous reset.
    reset                       : in  std_logic;

    -- Data input stream. dvalid specifies whether the data vector and count
    -- are valid; if not, a zero-length transfer is assumed. This may be used
    -- to insert a "last" flag after the last data transfer has already been
    -- sent, or to signal a zero-length packet. When dvalid and last are both
    -- low the transfer is ignored. When dvalid is set, count specifies the
    -- number of valid elements in data (which must be LSB-aligned, LSB first),
    -- with 0 signaling COUNT_MAX instead of 0. The last flag can be used to
    -- break up the output stream.
    din_valid                   : in  std_logic;
    din_ready                   : out std_logic;
    din_dvalid                  : in  std_logic := '1';
    din_data                    : in  std_logic_vector(IN_COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
    din_count                   : in  std_logic_vector(IN_COUNT_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(IN_COUNT_MAX, IN_COUNT_WIDTH));
    din_last                    : in  std_logic := '0';

    -- Control input stream. The contents of this stream work the same way as
    -- the input stream, but instead they specify the requested layout of the
    -- output. This stream is entirely optional; if left unconnected, the
    -- output will be as parallel as possible, unless interrupted by a "last"
    -- flag on the data input stream. The ctrl field is passed to the output
    -- stream without modification.
    cin_valid                   : in  std_logic := '1';
    cin_ready                   : out std_logic;
    cin_dvalid                  : in  std_logic := '1';
    cin_count                   : in  std_logic_vector(OUT_COUNT_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(OUT_COUNT_MAX, OUT_COUNT_WIDTH));
    cin_last                    : in  std_logic := '0';
    cin_ctrl                    : in  std_logic_vector(CTRL_WIDTH-1 downto 0) := (others => '0');

    -- Error flag. This is strobed when din_last was asserted while the control
    -- input stream wasn't expecting it. In general you should use *either*
    -- din_last *or* the control input stream, in which case this flag is
    -- meaningless; if you must use both however then you may want to monitor
    -- this.
    error_strobe                : out std_logic;

    -- Output stream. dvalid is low only when zero elements are requested by
    -- req_count. last is high when the last element returned was received with
    -- the last flag set.
    out_valid                   : out std_logic;
    out_ready                   : in  std_logic;
    out_dvalid                  : out std_logic;
    out_data                    : out std_logic_vector(OUT_COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
    out_count                   : out std_logic_vector(OUT_COUNT_WIDTH-1 downto 0);
    out_last                    : out std_logic;
    out_ctrl                    : out std_logic_vector(CTRL_WIDTH-1 downto 0)

  );
end StreamReshaper;

architecture Behavioral of StreamReshaper is

  --pragma translate_off
  constant DEBUG                : boolean := false;
  --pragma translate_on

  -- Calculate the maximum elements transferred per cycle by this unit.
  constant MAX_EPC              : natural := work.utils.max(IN_COUNT_MAX, OUT_COUNT_MAX);

  -- Calculate the width of the internal count fields. Unlike the ones used in
  -- the streams, 0 is valid for these.
  constant COUNT_WIDTH          : natural := log2ceil(MAX_EPC + 1);

  -- Determine the number of stages we need. This is one stage more than what
  -- we use for the shifter.
  constant NUM_SHIFT_STAGES     : natural := (COUNT_WIDTH + SHIFTS_PER_STAGE - 1) / SHIFTS_PER_STAGE;
  constant NUM_STAGES           : natural := NUM_SHIFT_STAGES + 1;

  -- Converts dvalid + count to a DVC.
  function to_internal_count(
    dvalid                      : std_logic;
    count                       : std_logic_vector
  ) return std_logic_vector is
    variable int_count          : std_logic_vector(COUNT_WIDTH-1 downto 0);
  begin
    if dvalid = '0' then
      int_count := (others => '0');
    else
      int_count := resize_count(count, COUNT_WIDTH);
    end if;
    return int_count;
  end function;

  -- Data input stream DVC and buffering.
  signal din_concat             : std_logic_vector(IN_COUNT_MAX*ELEMENT_WIDTH + COUNT_WIDTH downto 0);
  signal dib_valid              : std_logic;
  signal dib_ready              : std_logic;
  signal dib_concat             : std_logic_vector(IN_COUNT_MAX*ELEMENT_WIDTH + COUNT_WIDTH downto 0);
  signal dib_data               : std_logic_vector(IN_COUNT_MAX*ELEMENT_WIDTH - 1 downto 0);
  signal dib_count              : unsigned(COUNT_WIDTH - 1 downto 0);
  signal dib_last               : std_logic;

  -- Control input stream DVC and buffering.
  signal cin_concat             : std_logic_vector(CTRL_WIDTH + COUNT_WIDTH downto 0);
  signal cib_valid              : std_logic;
  signal cib_ready              : std_logic;
  signal cib_concat             : std_logic_vector(CTRL_WIDTH + COUNT_WIDTH downto 0);
  signal cib_ctrl               : std_logic_vector(CTRL_WIDTH - 1 downto 0);
  signal cib_count              : unsigned(COUNT_WIDTH - 1 downto 0);
  signal cib_last               : std_logic;

  -- Main control unit state.
  type ctrl_state is record
    cout_queued                 : unsigned(COUNT_WIDTH - 1 downto 0);
    hld_data                    : std_logic_vector(IN_COUNT_MAX*ELEMENT_WIDTH - 1 downto 0);
    hld_last                    : std_logic;
    hld_count                   : unsigned(COUNT_WIDTH - 1 downto 0);
    hld_remain                  : unsigned(COUNT_WIDTH - 1 downto 0);
  end record;
  signal ctrl_d                 : ctrl_state;
  signal ctrl_r                 : ctrl_state;

  -- Control unit flag outputs.
  signal next_input             : std_logic;
  signal next_output            : std_logic;
  signal error_strobe_d         : std_logic;

  -- Control unit outputs to pipeline.
  signal cout_valid             : std_logic;
  signal cout_ready             : std_logic;
  signal cout_din_lshift        : unsigned(COUNT_WIDTH - 1 downto 0);
  signal cout_din_data          : std_logic_vector(IN_COUNT_MAX*ELEMENT_WIDTH - 1 downto 0);
  signal cout_hld_count         : unsigned(COUNT_WIDTH - 1 downto 0);
  signal cout_hld_rshift        : unsigned(COUNT_WIDTH - 1 downto 0);
  signal cout_hld_data          : std_logic_vector(IN_COUNT_MAX*ELEMENT_WIDTH - 1 downto 0);
  signal cout_push              : std_logic;
  signal cout_last              : std_logic;
  signal cout_count             : unsigned(COUNT_WIDTH - 1 downto 0);
  signal cout_ctrl              : std_logic_vector(CTRL_WIDTH - 1 downto 0);
  signal cout_concat            : std_logic_vector(2*IN_COUNT_MAX*ELEMENT_WIDTH + 4*COUNT_WIDTH + CTRL_WIDTH + 1 downto 0);

  -- Pipeline input data.
  signal pin_concat             : std_logic_vector(2*IN_COUNT_MAX*ELEMENT_WIDTH + 4*COUNT_WIDTH + CTRL_WIDTH + 1 downto 0);
  signal pin_din_lshift         : std_logic_vector(COUNT_WIDTH - 1 downto 0);
  signal pin_din_data           : std_logic_vector(IN_COUNT_MAX*ELEMENT_WIDTH - 1 downto 0);
  signal pin_hld_count          : std_logic_vector(COUNT_WIDTH - 1 downto 0);
  signal pin_hld_rshift         : std_logic_vector(COUNT_WIDTH - 1 downto 0);
  signal pin_hld_data           : std_logic_vector(IN_COUNT_MAX*ELEMENT_WIDTH - 1 downto 0);
  signal pin_push               : std_logic;
  signal pin_last               : std_logic;
  signal pin_count              : std_logic_vector(COUNT_WIDTH - 1 downto 0);
  signal pin_ctrl               : std_logic_vector(CTRL_WIDTH - 1 downto 0);
  signal pin_din_data_wide      : std_logic_vector(MAX_EPC*ELEMENT_WIDTH - 1 downto 0);
  signal pin_hld_data_wide      : std_logic_vector(MAX_EPC*ELEMENT_WIDTH - 1 downto 0);
  signal pin_ctrl_concat        : std_logic_vector(3*COUNT_WIDTH + CTRL_WIDTH + 1 downto 0);

  -- Shifter output data.
  signal sh_din_data_wide       : std_logic_vector(MAX_EPC*ELEMENT_WIDTH - 1 downto 0);
  signal sh_hld_data_wide       : std_logic_vector(MAX_EPC*ELEMENT_WIDTH - 1 downto 0);
  signal sh_ctrl_concat         : std_logic_vector(3*COUNT_WIDTH + CTRL_WIDTH + 1 downto 0);
  signal sh_din_data            : std_logic_vector(OUT_COUNT_MAX*ELEMENT_WIDTH - 1 downto 0);
  signal sh_din_lshift          : std_logic_vector(COUNT_WIDTH - 1 downto 0);
  signal sh_hld_data            : std_logic_vector(OUT_COUNT_MAX*ELEMENT_WIDTH - 1 downto 0);
  signal sh_hld_count           : std_logic_vector(COUNT_WIDTH - 1 downto 0);
  signal sh_push                : std_logic;
  signal sh_last                : std_logic;
  signal sh_count               : std_logic_vector(COUNT_WIDTH - 1 downto 0);
  signal sh_ctrl                : std_logic_vector(CTRL_WIDTH - 1 downto 0);

  -- Misc. pipeline signals.
  signal pipe_valid             : std_logic_vector(0 to NUM_STAGES);

  -- Pipeline output data.
  signal pout_data              : std_logic_vector(OUT_COUNT_MAX*ELEMENT_WIDTH - 1 downto 0);
  signal pout_ctrl              : std_logic_vector(CTRL_WIDTH - 1 downto 0);
  signal pout_count             : std_logic_vector(OUT_COUNT_WIDTH - 1 downto 0);
  signal pout_dvalid            : std_logic;
  signal pout_last              : std_logic;
  signal pout_delete            : std_logic;
  signal pout_concat            : std_logic_vector(OUT_COUNT_MAX*ELEMENT_WIDTH + OUT_COUNT_WIDTH + CTRL_WIDTH + 1 downto 0);

  -- Concatenated output stream payload.
  signal out_concat             : std_logic_vector(OUT_COUNT_MAX*ELEMENT_WIDTH + OUT_COUNT_WIDTH + CTRL_WIDTH + 1 downto 0);

begin

  -----------------------------------------------------------------------------
  -- Data input stream preprocessing
  -----------------------------------------------------------------------------
  din_concat(IN_COUNT_MAX*ELEMENT_WIDTH-1 downto 0) <= din_data;
  din_concat(IN_COUNT_MAX*ELEMENT_WIDTH+COUNT_WIDTH-1 downto IN_COUNT_MAX*ELEMENT_WIDTH)
    <= to_internal_count(din_dvalid, din_count);
  din_concat(IN_COUNT_MAX*ELEMENT_WIDTH+COUNT_WIDTH) <= din_last;

  din_buffer_inst: StreamBuffer
    generic map (
      MIN_DEPTH                 => DIN_BUFFER_DEPTH,
      DATA_WIDTH                => IN_COUNT_MAX*ELEMENT_WIDTH + COUNT_WIDTH + 1,
      RAM_CONFIG                => RAM_CONFIG
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_valid                  => din_valid,
      in_ready                  => din_ready,
      in_data                   => din_concat,
      out_valid                 => dib_valid,
      out_ready                 => dib_ready,
      out_data                  => dib_concat
    );

  dib_data  <= dib_concat(IN_COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
  dib_count <= unsigned(dib_concat(IN_COUNT_MAX*ELEMENT_WIDTH+COUNT_WIDTH-1 downto IN_COUNT_MAX*ELEMENT_WIDTH));
  dib_last  <= dib_concat(IN_COUNT_MAX*ELEMENT_WIDTH+COUNT_WIDTH);

  -----------------------------------------------------------------------------
  -- Control input stream preprocessing
  -----------------------------------------------------------------------------
  cin_concat(CTRL_WIDTH-1 downto 0) <= cin_ctrl;
  cin_concat(CTRL_WIDTH+COUNT_WIDTH-1 downto CTRL_WIDTH) <= to_internal_count(cin_dvalid, cin_count);
  cin_concat(CTRL_WIDTH+COUNT_WIDTH) <= cin_last;

  cin_buffer_inst: StreamBuffer
    generic map (
      MIN_DEPTH                 => DIN_BUFFER_DEPTH,
      DATA_WIDTH                => CTRL_WIDTH + COUNT_WIDTH + 1,
      RAM_CONFIG                => RAM_CONFIG
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_valid                  => cin_valid,
      in_ready                  => cin_ready,
      in_data                   => cin_concat,
      out_valid                 => cib_valid,
      out_ready                 => cib_ready,
      out_data                  => cib_concat
    );

  cib_ctrl  <= cib_concat(CTRL_WIDTH-1 downto 0);
  cib_count <= unsigned(cib_concat(CTRL_WIDTH+COUNT_WIDTH-1 downto CTRL_WIDTH));
  cib_last  <= cib_concat(CTRL_WIDTH+COUNT_WIDTH);

  -----------------------------------------------------------------------------
  -- Main control unit
  -----------------------------------------------------------------------------
  -- The algorithm is roughly as follows:
  --  1) Wait for cin, din, and the FIFO to be ready.
  --  2) Send data from din to an output register, limited by cin_count. If
  --     there was already data waiting in the output register, make sure not
  --     to override it by left-shifting the incoming data by the number of
  --     elements that were already used. If the cin_count limit is reached or
  --     din_last is set, pop from cin and send the contents of the output
  --     register. If data is left after that, send it to a holding register.
  --     If the cin_count limit was not reached, go to 1).
  --  3) If there is data in the holding register, send it to the output
  --     register, right-shifting such that the first remaining element in the
  --     holding register ends up in the first entry of the output register.
  --     If the cin_count limit is reached or the last flag of the holding
  --     register is set, pop from cin and send the contents of the output
  --     register. If not all data from the holding register has been consumed,
  --     go to 3). Otherwise return to 1).
  -- Note that this is simplified somewhat, but this is the general idea.
  -- Sending data from din to the output register (through a left-shift) and
  -- from the holding register to the output register (through a right-shift)
  -- can be done in parallel. The (barrel) shifts are pipelined.
  ctrl_comb_proc: process (
    ctrl_r,
    dib_valid, dib_data, dib_count, dib_last,
    cib_valid, cib_ctrl, cib_count, cib_last,
    cout_ready,
    clk -- we're only sensitive to clk for debugging!
  ) is
    variable v                      : ctrl_state;
    variable cout_remain_v          : unsigned(COUNT_WIDTH - 1 downto 0);
  begin
    v := ctrl_r;

    -- Output signal defaults.
    next_input      <= '0';
    next_output     <= '0';
    error_strobe_d  <= '0';
    cout_valid      <= '0';
    cout_last       <= cib_last;                      -- don't care by default
    cout_count      <= cib_count;                     -- don't care by default
    cout_ctrl       <= cib_ctrl;                      -- don't care by default
    cout_din_lshift <= v.cout_queued + v.hld_remain;
    cout_din_data   <= dib_data;                      -- don't care by default
    cout_hld_count  <= (others => '0');
    cout_hld_rshift <= v.hld_count - v.hld_remain;    -- don't care by default
    cout_hld_data   <= v.hld_data;                    -- don't care by default

    -- Only advance state when the control input and FIFO are ready. We don't
    -- have to wait for the data input yet, because the holding register may
    -- be sufficient for further output transfers. NOTE: it is ONLY okay to
    -- wait for cout_ready because cout is connected to a slice. More
    -- complicated logic is necessary to comply with AXI stream in general.
    if cib_valid = '1' and cout_ready = '1' then

      -- Always send a command into the pipeline when everything is ready.
      -- This may not actually result in an output transfer though; this only
      -- happens when next_output is also asserted.
      cout_valid    <= '1';

      -- Compute how many elements we still need to push into the output
      -- register according to the current command.
      cout_remain_v := cib_count - v.cout_queued;

      -- Always send the valid part of the holding register to the output
      -- register, right-shifted to LSB-align it as it will always be the first
      -- few elements of the output transfer. Note that this is no-op if there
      -- are no valid elements remaining in the holding register. Note also
      -- that it doesn't matter if we send more to the output register than we
      -- actually have to, because those entries will end up being invalidated
      -- by out_count.
      cout_hld_count  <= v.hld_remain;
      cout_hld_rshift <= v.hld_count - v.hld_remain;
      cout_hld_data   <= v.hld_data;

      if v.hld_remain > cout_remain_v then

        -- The holding register is enough to complete the output transfer, and
        -- after that we're still left with some unused data. This remains in
        -- the holding register for the next cycle.
        v.hld_remain  := v.hld_remain - cout_remain_v;
        v.cout_queued := cib_count;
        cout_remain_v := (others => '0');

        -- Complete the transfer normally.
        cout_last     <= cib_last;
        cout_count    <= v.cout_queued;
        next_output   <= '1';
        v.cout_queued := (others => '0');

        --pragma translate_off
        if rising_edge(clk) and DEBUG then
          report integer'image(to_integer(unsigned(cib_ctrl))) & ": hld > cin" severity note;
        end if;
        --pragma translate_on

      elsif v.hld_last = '1' then

        -- The holding register is fully absorbed into the output, and the
        -- "last" flag was set. That means we need to complete the output
        -- transfer, whether the control input stream wants us to or not. If it
        -- doesn't, assert the error flag.
        if cib_last = '0' or cout_remain_v > v.hld_remain then
          error_strobe_d <= '1';
        end if;

        v.cout_queued := v.cout_queued + v.hld_remain;
        cout_remain_v := cout_remain_v - v.hld_remain;
        v.hld_remain  := (others => '0');
        v.hld_last    := '0';

        -- Complete the transfer, forcing the "last" flag to be set.
        cout_last     <= '1';
        cout_count    <= v.cout_queued;
        next_output   <= '1';
        v.cout_queued := (others => '0');

        --pragma translate_off
        if rising_edge(clk) and DEBUG then
          report integer'image(to_integer(unsigned(cib_ctrl))) & ": hld last" severity note;
        end if;
        --pragma translate_on

      elsif dib_valid = '0' then

        -- We need further input from the data stream before we can advance,
        -- either because we don't have enough data or because the data stream
        -- may still change the requisite output by sending a zero-length last
        -- transfer, but we don't have input yet. So we can't do anything right
        -- now.

      else -- v.hld_remain <= v.cout_remain and v.hld_last = '0' and dib_valid = '1'

        -- The holding register is JUST enough or NOT enough to complete the
        -- output transfer.
        v.cout_queued   := v.cout_queued + v.hld_remain;
        cout_remain_v   := cout_remain_v - v.hld_remain;
        v.hld_remain    := (others => '0');
        v.hld_last      := '0';

        -- Append incoming data to the output transfer, left-shifting past any
        -- data that was already written or that we're writing from the holding
        -- register in this cycle.
        cout_din_lshift <= v.cout_queued;
        cout_din_data   <= dib_data;

        -- Regardless of what happens next, what'll be left of the incoming
        -- data (which may be nothing) is pushed into the holding register and
        -- the data input is popped.
        v.hld_data      := dib_data;
        v.hld_last      := dib_last;
        v.hld_count     := dib_count;
        v.hld_remain    := dib_count;
        next_input      <= '1';

        if dib_count > cout_remain_v then

          -- The previous holding register plus the incoming data is enough to
          -- complete the output transfer, and after that we're still left with
          -- some unused data. This is placed in the holding register for the
          -- next cycle.
          v.hld_remain  := v.hld_remain - cout_remain_v;
          v.cout_queued := cib_count;
          cout_remain_v := (others => '0');

          -- Complete the transfer normally.
          cout_last     <= cib_last;
          cout_count    <= v.cout_queued;
          next_output   <= '1';
          v.cout_queued := (others => '0');

          --pragma translate_off
          if rising_edge(clk) and DEBUG then
            report integer'image(to_integer(unsigned(cib_ctrl))) & ": hld + din > cin" severity note;
          end if;
          --pragma translate_on

        elsif dib_last = '1' then

          -- The holding register and input data are fully absorbed into the
          -- output, and the input last flag was set. That means we need to
          -- complete the output transfer, whether the control input stream
          -- wants us to or not. If it doesn't, assert the error flag.
          if cib_last = '0' or cout_remain_v > dib_count then
            error_strobe_d <= '1';
          end if;

          v.hld_remain  := (others => '0');
          v.hld_last    := '0';
          v.cout_queued := v.cout_queued + dib_count;
          cout_remain_v := cout_remain_v - dib_count;

          -- Complete the transfer, forcing the "last" flag to be set.
          cout_last     <= '1';
          cout_count    <= v.cout_queued;
          next_output   <= '1';
          v.cout_queued := (others => '0');

          --pragma translate_off
          if rising_edge(clk) and DEBUG then
            report integer'image(to_integer(unsigned(cib_ctrl))) & ": din last" severity note;
          end if;
          --pragma translate_on

        elsif dib_count = cout_remain_v then

          -- The holding register and input data are exactly enough to
          -- complete the output transfer.
          v.hld_remain  := (others => '0');
          v.hld_last    := '0';
          v.cout_queued := cib_count;
          cout_remain_v := (others => '0');

          -- Complete the transfer normally.
          cout_last     <= cib_last;
          cout_count    <= v.cout_queued;
          next_output   <= '1';
          v.cout_queued := (others => '0');

          --pragma translate_off
          if rising_edge(clk) and DEBUG then
            report integer'image(to_integer(unsigned(cib_ctrl))) & ": hld + din = cin" severity note;
          end if;
          --pragma translate_on

        else -- dib_count < cout_remain_v and dib_last = '0'

          -- The holding register and input data are fully absorbed into the
          -- output, leaving the holding register empty and the output
          -- incomplete.
          v.hld_remain  := (others => '0');
          v.hld_last    := '0';
          v.cout_queued := v.cout_queued + dib_count;
          cout_remain_v := cout_remain_v - dib_count;

          --pragma translate_off
          if rising_edge(clk) and DEBUG then
            report integer'image(to_integer(unsigned(cib_ctrl))) & ": need more" severity note;
          end if;
          --pragma translate_on

        end if;
      end if;
    end if;

    ctrl_d <= v;
  end process;

  dib_ready <= next_input;
  cib_ready <= next_output;
  cout_push <= next_output;

  ctrl_reg_proc: process (clk) is
  begin
    if rising_edge(clk) then
      if reset = '1' then
        ctrl_r.cout_queued <= (others => '0');
        ctrl_r.hld_count   <= (others => '0');
        ctrl_r.hld_remain  <= (others => '0');
        --pragma translate_off
        ctrl_r.hld_data    <= (others => 'U');
        ctrl_r.hld_last    <= 'U';
        --pragma translate_on
        error_strobe       <= '0';
      else
        ctrl_r             <= ctrl_d;
        error_strobe       <= error_strobe_d;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Pipeline control logic
  -----------------------------------------------------------------------------
  pipe_ctrl_inst: StreamPipelineControl
    generic map (
      IN_DATA_WIDTH             => 2*IN_COUNT_MAX*ELEMENT_WIDTH + 4*COUNT_WIDTH + 1*CTRL_WIDTH + 2,
      OUT_DATA_WIDTH            => 1*OUT_COUNT_MAX*ELEMENT_WIDTH + 1*OUT_COUNT_WIDTH + 1*CTRL_WIDTH + 2,
      NUM_PIPE_REGS             => NUM_STAGES,
      INPUT_SLICE               => true, -- NECESSARY, otherwise deadlock can occur
      RAM_CONFIG                => RAM_CONFIG
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_valid                  => cout_valid,
      in_ready                  => cout_ready,
      in_data                   => cout_concat,
      out_valid                 => out_valid,
      out_ready                 => out_ready,
      out_data                  => out_concat,
      pipe_delete               => pout_delete,
      pipe_valid                => pipe_valid,
      pipe_input                => pin_concat,
      pipe_output               => pout_concat
    );

  -----------------------------------------------------------------------------
  -- Barrel shifter instances
  -----------------------------------------------------------------------------
  pin_din_data_wide <= std_logic_vector(resize(unsigned(pin_din_data), MAX_EPC*ELEMENT_WIDTH));
  pin_hld_data_wide <= std_logic_vector(resize(unsigned(pin_hld_data), MAX_EPC*ELEMENT_WIDTH));

  pipe_lshift_inst: StreamPipelineBarrel
    generic map (
      ELEMENT_WIDTH             => ELEMENT_WIDTH,
      ELEMENT_COUNT             => MAX_EPC,
      AMOUNT_WIDTH              => COUNT_WIDTH,
      DIRECTION                 => "left",
      OPERATION                 => "shift",
      NUM_STAGES                => NUM_SHIFT_STAGES
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_data                   => pin_din_data_wide,
      in_amount                 => pin_din_lshift,
      out_data                  => sh_din_data_wide
    );

  pipe_rshift_inst: StreamPipelineBarrel
    generic map (
      ELEMENT_WIDTH             => ELEMENT_WIDTH,
      ELEMENT_COUNT             => MAX_EPC,
      AMOUNT_WIDTH              => COUNT_WIDTH,
      DIRECTION                 => "right",
      OPERATION                 => "shift",
      NUM_STAGES                => NUM_SHIFT_STAGES,
      CTRL_WIDTH                => 3*COUNT_WIDTH + CTRL_WIDTH + 2
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_data                   => pin_hld_data_wide,
      in_ctrl                   => pin_ctrl_concat,
      in_amount                 => pin_hld_rshift,
      out_data                  => sh_hld_data_wide,
      out_ctrl                  => sh_ctrl_concat
    );

  sh_din_data <= std_logic_vector(resize(unsigned(sh_din_data_wide), OUT_COUNT_MAX*ELEMENT_WIDTH));
  sh_hld_data <= std_logic_vector(resize(unsigned(sh_hld_data_wide), OUT_COUNT_MAX*ELEMENT_WIDTH));

  -----------------------------------------------------------------------------
  -- Combining pipeline stage
  -----------------------------------------------------------------------------
  last_stage_proc: process (clk) is
  begin
    if rising_edge(clk) then

      -- Update the output register.
      if pipe_valid(NUM_SHIFT_STAGES) = '1' then
        for i in 0 to OUT_COUNT_MAX - 1 loop
          if i < unsigned(sh_hld_count) then
            pout_data(i*ELEMENT_WIDTH+ELEMENT_WIDTH-1 downto i*ELEMENT_WIDTH) <=
              sh_hld_data(i*ELEMENT_WIDTH+ELEMENT_WIDTH-1 downto i*ELEMENT_WIDTH);
          end if;
          if i >= unsigned(sh_din_lshift) then
            pout_data(i*ELEMENT_WIDTH+ELEMENT_WIDTH-1 downto i*ELEMENT_WIDTH) <=
              sh_din_data(i*ELEMENT_WIDTH+ELEMENT_WIDTH-1 downto i*ELEMENT_WIDTH);
          end if;
        end loop;
      end if;

      -- Pass the control information through.
      pout_last <= sh_last;
      pout_ctrl <= sh_ctrl;

      -- Convert from a regular count to the stream count and dvalid pair.
      if unsigned(sh_count) = 0 then
        pout_dvalid <= '0';
      else
        pout_dvalid <= '1';
      end if;
      pout_count <= std_logic_vector(resize(unsigned(sh_count), OUT_COUNT_WIDTH));

      -- "Delete" this pipeline stage if we shouldn't push to the output
      -- stream.
      pout_delete <= not sh_push;

      -- Check the output count.
      if sh_push = '1' and pipe_valid(NUM_SHIFT_STAGES) = '1' then
        assert unsigned(sh_count) <= OUT_COUNT_MAX
          report "StreamReshaper is trying to output a count larger than the " &
          "maximum supported by the output stream!" severity failure;
      end if;

      -- Handle reset.
      if reset = '1' then
        --pragma translate_off
        pout_data   <= (others => 'U');
        pout_ctrl   <= (others => 'U');
        pout_count  <= (others => 'U');
        pout_dvalid <= 'U';
        pout_last   <= 'U';
        pout_delete <= 'U';
        --pragma translate_on
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Concathulhu
  -----------------------------------------------------------------------------
  -- Concatenate the control unit output.
  cout_concat(0*IN_COUNT_MAX*ELEMENT_WIDTH + 1*COUNT_WIDTH + 0*CTRL_WIDTH + 0 - 1
       downto 0*IN_COUNT_MAX*ELEMENT_WIDTH + 0*COUNT_WIDTH + 0*CTRL_WIDTH + 0) <= std_logic_vector(cout_din_lshift);

  cout_concat(1*IN_COUNT_MAX*ELEMENT_WIDTH + 1*COUNT_WIDTH + 0*CTRL_WIDTH + 0 - 1
       downto 0*IN_COUNT_MAX*ELEMENT_WIDTH + 1*COUNT_WIDTH + 0*CTRL_WIDTH + 0) <= cout_din_data;

  cout_concat(1*IN_COUNT_MAX*ELEMENT_WIDTH + 2*COUNT_WIDTH + 0*CTRL_WIDTH + 0 - 1
       downto 1*IN_COUNT_MAX*ELEMENT_WIDTH + 1*COUNT_WIDTH + 0*CTRL_WIDTH + 0) <= std_logic_vector(cout_hld_count);

  cout_concat(1*IN_COUNT_MAX*ELEMENT_WIDTH + 3*COUNT_WIDTH + 0*CTRL_WIDTH + 0 - 1
       downto 1*IN_COUNT_MAX*ELEMENT_WIDTH + 2*COUNT_WIDTH + 0*CTRL_WIDTH + 0) <= std_logic_vector(cout_hld_rshift);

  cout_concat(2*IN_COUNT_MAX*ELEMENT_WIDTH + 3*COUNT_WIDTH + 0*CTRL_WIDTH + 0 - 1
       downto 1*IN_COUNT_MAX*ELEMENT_WIDTH + 3*COUNT_WIDTH + 0*CTRL_WIDTH + 0) <= cout_hld_data;

  cout_concat(2*IN_COUNT_MAX*ELEMENT_WIDTH + 3*COUNT_WIDTH + 0*CTRL_WIDTH + 0) <= cout_push;

  cout_concat(2*IN_COUNT_MAX*ELEMENT_WIDTH + 3*COUNT_WIDTH + 0*CTRL_WIDTH + 1) <= cout_last;

  cout_concat(2*IN_COUNT_MAX*ELEMENT_WIDTH + 4*COUNT_WIDTH + 0*CTRL_WIDTH + 2 - 1
       downto 2*IN_COUNT_MAX*ELEMENT_WIDTH + 3*COUNT_WIDTH + 0*CTRL_WIDTH + 2) <= std_logic_vector(cout_count);

  cout_concat(2*IN_COUNT_MAX*ELEMENT_WIDTH + 4*COUNT_WIDTH + 1*CTRL_WIDTH + 2 - 1
       downto 2*IN_COUNT_MAX*ELEMENT_WIDTH + 4*COUNT_WIDTH + 0*CTRL_WIDTH + 2) <= cout_ctrl;

  -- Split the pipeline input.
  pin_din_lshift <= pin_concat(0*IN_COUNT_MAX*ELEMENT_WIDTH + 1*COUNT_WIDTH + 0*CTRL_WIDTH + 0 - 1
                        downto 0*IN_COUNT_MAX*ELEMENT_WIDTH + 0*COUNT_WIDTH + 0*CTRL_WIDTH + 0);

  pin_din_data   <= pin_concat(1*IN_COUNT_MAX*ELEMENT_WIDTH + 1*COUNT_WIDTH + 0*CTRL_WIDTH + 0 - 1
                        downto 0*IN_COUNT_MAX*ELEMENT_WIDTH + 1*COUNT_WIDTH + 0*CTRL_WIDTH + 0);

  pin_hld_count  <= pin_concat(1*IN_COUNT_MAX*ELEMENT_WIDTH + 2*COUNT_WIDTH + 0*CTRL_WIDTH + 0 - 1
                        downto 1*IN_COUNT_MAX*ELEMENT_WIDTH + 1*COUNT_WIDTH + 0*CTRL_WIDTH + 0);

  pin_hld_rshift <= pin_concat(1*IN_COUNT_MAX*ELEMENT_WIDTH + 3*COUNT_WIDTH + 0*CTRL_WIDTH + 0 - 1
                        downto 1*IN_COUNT_MAX*ELEMENT_WIDTH + 2*COUNT_WIDTH + 0*CTRL_WIDTH + 0);

  pin_hld_data   <= pin_concat(2*IN_COUNT_MAX*ELEMENT_WIDTH + 3*COUNT_WIDTH + 0*CTRL_WIDTH + 0 - 1
                        downto 1*IN_COUNT_MAX*ELEMENT_WIDTH + 3*COUNT_WIDTH + 0*CTRL_WIDTH + 0);

  pin_push       <= pin_concat(2*IN_COUNT_MAX*ELEMENT_WIDTH + 3*COUNT_WIDTH + 0*CTRL_WIDTH + 0);

  pin_last       <= pin_concat(2*IN_COUNT_MAX*ELEMENT_WIDTH + 3*COUNT_WIDTH + 0*CTRL_WIDTH + 1);

  pin_count      <= pin_concat(2*IN_COUNT_MAX*ELEMENT_WIDTH + 4*COUNT_WIDTH + 0*CTRL_WIDTH + 2 - 1
                        downto 2*IN_COUNT_MAX*ELEMENT_WIDTH + 3*COUNT_WIDTH + 0*CTRL_WIDTH + 2);

  pin_ctrl       <= pin_concat(2*IN_COUNT_MAX*ELEMENT_WIDTH + 4*COUNT_WIDTH + 1*CTRL_WIDTH + 2 - 1
                        downto 2*IN_COUNT_MAX*ELEMENT_WIDTH + 4*COUNT_WIDTH + 0*CTRL_WIDTH + 2);

  -- Concatenate output control data.
  pin_ctrl_concat(1*COUNT_WIDTH + 0*CTRL_WIDTH + 0 - 1
           downto 0*COUNT_WIDTH + 0*CTRL_WIDTH + 0) <= pin_din_lshift;

  pin_ctrl_concat(2*COUNT_WIDTH + 0*CTRL_WIDTH + 0 - 1
           downto 1*COUNT_WIDTH + 0*CTRL_WIDTH + 0) <= pin_hld_count;

  pin_ctrl_concat(2*COUNT_WIDTH + 0*CTRL_WIDTH + 0) <= pin_push;

  pin_ctrl_concat(2*COUNT_WIDTH + 0*CTRL_WIDTH + 1) <= pin_last;

  pin_ctrl_concat(3*COUNT_WIDTH + 0*CTRL_WIDTH + 2 - 1
           downto 2*COUNT_WIDTH + 0*CTRL_WIDTH + 2) <= pin_count;

  pin_ctrl_concat(3*COUNT_WIDTH + 1*CTRL_WIDTH + 2 - 1
           downto 3*COUNT_WIDTH + 0*CTRL_WIDTH + 2) <= pin_ctrl;

  -- Split output control data.
  sh_din_lshift <= sh_ctrl_concat(1*COUNT_WIDTH + 0*CTRL_WIDTH + 0 - 1
                           downto 0*COUNT_WIDTH + 0*CTRL_WIDTH + 0);

  sh_hld_count  <= sh_ctrl_concat(2*COUNT_WIDTH + 0*CTRL_WIDTH + 0 - 1
                           downto 1*COUNT_WIDTH + 0*CTRL_WIDTH + 0);

  sh_push       <= sh_ctrl_concat(2*COUNT_WIDTH + 0*CTRL_WIDTH + 0);

  sh_last       <= sh_ctrl_concat(2*COUNT_WIDTH + 0*CTRL_WIDTH + 1);

  sh_count      <= sh_ctrl_concat(3*COUNT_WIDTH + 0*CTRL_WIDTH + 2 - 1
                           downto 2*COUNT_WIDTH + 0*CTRL_WIDTH + 2);

  sh_ctrl       <= sh_ctrl_concat(3*COUNT_WIDTH + 1*CTRL_WIDTH + 2 - 1
                           downto 3*COUNT_WIDTH + 0*CTRL_WIDTH + 2);

  -- Concatenate the pipeline output.
  pout_concat(1*OUT_COUNT_MAX*ELEMENT_WIDTH + 0*OUT_COUNT_WIDTH + 0*CTRL_WIDTH + 0 - 1
       downto 0*OUT_COUNT_MAX*ELEMENT_WIDTH + 0*OUT_COUNT_WIDTH + 0*CTRL_WIDTH + 0) <= pout_data;

  pout_concat(1*OUT_COUNT_MAX*ELEMENT_WIDTH + 0*OUT_COUNT_WIDTH + 1*CTRL_WIDTH + 0 - 1
       downto 1*OUT_COUNT_MAX*ELEMENT_WIDTH + 0*OUT_COUNT_WIDTH + 0*CTRL_WIDTH + 0) <= pout_ctrl;

  pout_concat(1*OUT_COUNT_MAX*ELEMENT_WIDTH + 1*OUT_COUNT_WIDTH + 1*CTRL_WIDTH + 0 - 1
       downto 1*OUT_COUNT_MAX*ELEMENT_WIDTH + 0*OUT_COUNT_WIDTH + 1*CTRL_WIDTH + 0) <= pout_count;

  pout_concat(1*OUT_COUNT_MAX*ELEMENT_WIDTH + 1*OUT_COUNT_WIDTH + 1*CTRL_WIDTH + 0) <= pout_dvalid;

  pout_concat(1*OUT_COUNT_MAX*ELEMENT_WIDTH + 1*OUT_COUNT_WIDTH + 1*CTRL_WIDTH + 1) <= pout_last;

  -- Split the output stream.
  out_data   <= out_concat(1*OUT_COUNT_MAX*ELEMENT_WIDTH + 0*OUT_COUNT_WIDTH + 0*CTRL_WIDTH + 0 - 1
                    downto 0*OUT_COUNT_MAX*ELEMENT_WIDTH + 0*OUT_COUNT_WIDTH + 0*CTRL_WIDTH + 0);

  out_ctrl   <= out_concat(1*OUT_COUNT_MAX*ELEMENT_WIDTH + 0*OUT_COUNT_WIDTH + 1*CTRL_WIDTH + 0 - 1
                    downto 1*OUT_COUNT_MAX*ELEMENT_WIDTH + 0*OUT_COUNT_WIDTH + 0*CTRL_WIDTH + 0);

  out_count  <= out_concat(1*OUT_COUNT_MAX*ELEMENT_WIDTH + 1*OUT_COUNT_WIDTH + 1*CTRL_WIDTH + 0 - 1
                    downto 1*OUT_COUNT_MAX*ELEMENT_WIDTH + 0*OUT_COUNT_WIDTH + 1*CTRL_WIDTH + 0);

  out_dvalid <= out_concat(1*OUT_COUNT_MAX*ELEMENT_WIDTH + 1*OUT_COUNT_WIDTH + 1*CTRL_WIDTH + 0);

  out_last   <= out_concat(1*OUT_COUNT_MAX*ELEMENT_WIDTH + 1*OUT_COUNT_WIDTH + 1*CTRL_WIDTH + 1);

end Behavioral;

