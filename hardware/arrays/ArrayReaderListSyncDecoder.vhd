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
use work.Stream_pkg.all;
use work.UtilMisc_pkg.all;

entity ArrayReaderListSyncDecoder is
  generic (

    -- Width of the list length vector.
    LENGTH_WIDTH                : natural;

    -- Maximum number of elements per clock.
    COUNT_MAX                   : natural;

    -- The number of bits in the count vectors. This must be at least
    -- ceil(log2(COUNT_MAX)) and must be at least 1. If COUNT_MAX is a power of
    -- two and this value equals log2(COUNT_MAX), a zero count implies that all
    -- entries are valid (i.e., there is an implicit '1' bit in front).
    COUNT_WIDTH                 : natural;

    -- Whether a register slice should be inserted in the length input stream.
    LEN_IN_SLICE                : boolean

  );
  port (

    -- Rising-edge sensitive clock.
    clk                         : in  std_logic;

    -- Active-high synchronous reset.
    reset                       : in  std_logic;

    -- List length input stream.
    inl_valid                   : in  std_logic;
    inl_ready                   : out std_logic;
    inl_length                  : in  std_logic_vector(LENGTH_WIDTH-1 downto 0);

    -- Control output stream. This stream indicates the control signals and
    -- how many list elements should be popped from the normalization FIFO for
    -- each transfer.
    ctrl_valid                  : out std_logic;
    ctrl_ready                  : in  std_logic;
    ctrl_last                   : out std_logic;
    ctrl_dvalid                 : out std_logic;
    ctrl_count                  : out std_logic_vector(COUNT_WIDTH-1 downto 0)

  );
end ArrayReaderListSyncDecoder;

architecture Behavioral of ArrayReaderListSyncDecoder is

  -- Length input stream after the optional register slice.
  signal len_valid              : std_logic;
  signal len_ready              : std_logic;
  signal len_length             : std_logic_vector(LENGTH_WIDTH-1 downto 0);

  -- Whether we're currently decoding a command or not.
  signal decoding               : std_logic;
  signal decoding_next          : std_logic;

  -- Remaining length for the current command.
  signal remain                 : std_logic_vector(LENGTH_WIDTH-1 downto 0);
  signal remain_next            : std_logic_vector(LENGTH_WIDTH-1 downto 0);

begin

  -- Instantiate optional register slice for the length input stream.
  len_in_buffer_inst: StreamBuffer
    generic map (
      MIN_DEPTH                 => sel(LEN_IN_SLICE, 2, 0),
      DATA_WIDTH                => LENGTH_WIDTH
    )
    port map (
      clk                       => clk,
      reset                     => reset,

      in_valid                  => inl_valid,
      in_ready                  => inl_ready,
      in_data                   => inl_length,

      out_valid                 => len_valid,
      out_ready                 => len_ready,
      out_data                  => len_length
    );

  -- Register part of the FSM.
  reg_proc: process (clk) is
  begin
    if rising_edge(clk) then

      -- Register the FSM state.
      decoding <= decoding_next;
      remain <= remain_next;

      -- Reset the FSM when reset is asserted. remain is don't care when
      -- decoding is low, so we reset it to undefined in simulation to verify
      -- that it isn't used.
      if reset = '1' then
        decoding <= '0';
        -- pragma translate_off
        remain <= (others => 'U');
        -- pragma translate_on
      end if;

    end if;
  end process;

  -- Combinatorial part of the FSM.
  comb_proc: process (decoding, remain, len_valid, len_length, ctrl_ready) is

    -- State variables.
    variable decoding_v         : std_logic;
    variable remain_v           : std_logic_vector(LENGTH_WIDTH-1 downto 0);

    -- Remaining length after sending out a MAX_COUNT beat.
    variable remain_sub_max     : std_logic_vector(LENGTH_WIDTH-1 downto 0);

    -- Signals that len_remain is less than or equal to MAX_COUNT.
    variable remain_le_max      : std_logic;

    -- Signals that len_remain is zero.
    variable remain_eq_zero     : std_logic;

  begin

    decoding_v := decoding;
    remain_v   := remain;

    -- Perform arithmetic on the remain vector.
    remain_sub_max := std_logic_vector(unsigned(remain_v) - COUNT_MAX);
    if to_01(unsigned(remain_v)) <= COUNT_MAX then
      remain_le_max := '1';
    else
      remain_le_max := '0';
    end if;
    remain_eq_zero := not or_reduce(remain_v);

    -- ctrl stream producer part of the state machine.
    ctrl_valid  <= decoding;
    ctrl_last   <= remain_le_max;
    ctrl_dvalid <= not remain_eq_zero;
    if remain_le_max = '1' then
      ctrl_count <= std_logic_vector(resize(unsigned(remain_v), COUNT_WIDTH));
    else
      ctrl_count <= std_logic_vector(to_unsigned(COUNT_MAX, COUNT_WIDTH));
    end if;

    if decoding_v = '1' and ctrl_ready = '1' then

      -- We're sending a transfer to the ctrl stream this cycle, so we need
      -- to work out what to do the next cycle. If remain_le_max is high,
      -- this was the last transfer for the current list, so we stop
      -- decoding. If not, decrement the remain counter.
      if remain_le_max = '1' then
        decoding_v := '0';
        -- pragma translate_off
        remain_v := (others => 'U');
        -- pragma translate_on
      else
        remain_v := remain_sub_max;
      end if;

    end if;

    -- Length stream consumer part of the state machine. Note that this uses
    -- decoding_v instead of the decoding signal. This allows the state machine
    -- to accept a new request in the same cycle that it finishes the previous
    -- request.
    len_ready <= '0';

    if decoding_v = '0' and len_valid = '1' then

      -- Pop a new list length from the length stream and start decoding it.
      decoding_v := '1';
      remain_v   := len_length;
      len_ready  <= '1';

    end if;

    decoding_next <= decoding_v;
    remain_next   <= remain_v;

  end process;

end Behavioral;

