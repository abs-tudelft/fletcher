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
use work.Array_pkg.all;

-- Synchronizes a (multi-element-per-cycle, or MEPC) length stream with a values
-- stream in such a way that the values stream last signal is replaced by the
-- last length stream last signal.
--
-- This is necessary because an MEPC length stream handshake last signal
-- implicitly applies only to the last length in that handshake. Therefore,
-- synchronizing on the last signal of the values stream might cause the
-- underlying BufferWriters to terminate a command for every list, while it
-- might as well terminate the command for the values in all lists together.
--
-- In other words, this unit makes sure that when the length stream last signal
-- is asserted, the amount of lists transfered by both length and values stream
-- is exactly the same. Only when the values stream has "caught up", is the
-- length stream allowed to continue.
--
-- This furthermore implies that the values stream cannot run ahead of the
-- length stream, and is backpressured accordingly.

entity ArrayWriterListSync is
  generic (
    ---------------------------------------------------------------------------
    -- Lengths stream
    ---------------------------------------------------------------------------
    -- Width of the list length vector.
    LENGTH_WIDTH                : positive := 32;

    -- Maximum number of elements per clock.
    LCOUNT_MAX                  : positive := 1;

    -- The number of bits in the count vectors. This must be at least
    -- ceil(log2(COUNT_MAX)) and must be at least 1. If COUNT_MAX is a power of
    -- two and this value equals log2(COUNT_MAX), a zero count implies that all
    -- entries are valid (i.e., there is an implicit '1' bit in front).
    LCOUNT_WIDTH                : positive := 1
  );
  port (

    -- Rising-edge sensitive clock.
    clk                         : in  std_logic;

    -- Active-high synchronous reset.
    reset                       : in  std_logic;

    -- List length input stream.
    in_len_valid                : in  std_logic;
    in_len_ready                : out std_logic;
    in_len_count                : in  std_logic_vector(LCOUNT_WIDTH-1 downto 0);
    in_len_last                 : in  std_logic;

    -- List length output stream.
    out_len_valid               : out std_logic;
    out_len_ready               : in  std_logic;

    -- List values input stream control signals.
    in_val_valid                : in  std_logic;
    in_val_ready                : out std_logic;
    in_val_last                 : in  std_logic;

    -- Values output stream control signals
    out_val_valid               : out std_logic;
    out_val_ready               : in  std_logic;
    out_val_last                : out std_logic
  );
end ArrayWriterListSync;

architecture Behavioral of ArrayWriterListSync is

  -- Length stream split
  signal llc_valid              : std_logic;
  signal llc_ready              : std_logic;

  -- Length stream list count
  signal len_list_count_valid   : std_logic;
  signal len_list_count_ready   : std_logic;
  signal len_list_count         : std_logic_vector(LCOUNT_WIDTH-1 downto 0);
  signal len_list_count_last    : std_logic;

  type reg_type is record
    val_list_count : unsigned(LCOUNT_WIDTH-1 downto 0);
  end record;

  type comb_type is record
    -- Length stream control
    len_counter_ready : std_logic;

    -- Values stream control
    in_val_ready      : std_logic;
    out_val_valid     : std_logic;
    out_val_last      : std_logic;
  end record;

  signal r : reg_type;
  signal d : reg_type;

begin

  -- Split the length stream to the output and the counter
  pre_split_inst: StreamSync
    generic map (
      NUM_INPUTS => 1,
      NUM_OUTPUTS => 2
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_valid(0)               => in_len_valid,
      in_ready(0)               => in_len_ready,
      out_valid(0)              => llc_valid,
      out_valid(1)              => out_len_valid,
      out_ready(0)              => llc_ready,
      out_ready(1)              => out_len_ready
    );

  -- Count the number of lists handshaked on the length stream
  len_cnt_inst : StreamElementCounter
    generic map (
      IN_COUNT_MAX              => LCOUNT_MAX,
      IN_COUNT_WIDTH            => LCOUNT_WIDTH,
      OUT_COUNT_WIDTH           => LCOUNT_WIDTH,
      OUT_COUNT_MAX             => LCOUNT_MAX
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_valid                  => llc_valid,
      in_ready                  => llc_ready,
      in_count                  => in_len_count,
      in_last                   => in_len_last,
      out_valid                 => len_list_count_valid,
      out_ready                 => len_list_count_ready,
      out_count                 => len_list_count,
      out_last                  => len_list_count_last
    );

  reg_proc: process (clk) is
  begin
    if rising_edge(clk) then
      r <= d;
      if reset = '1' then
        r.val_list_count <= (others => '0');
      end if;
    end if;
  end process;

  comb_proc: process(r,
    -- Length list count
    len_list_count_valid, len_list_count_last, len_list_count,
    -- Values stream
    in_val_valid, in_val_last,
    -- Output values stream
    out_val_ready,
    -- Output length stream
    out_len_ready)
  is
    variable v: reg_type;
    variable c: comb_type;
  begin
    v := r;

    -- Default outputs
    out_val_last <= '0';
    c.len_counter_ready := '0';

    -- Pass through values stream control
    c.out_val_valid := in_val_valid;
    c.in_val_ready  := out_val_ready;
    c.out_val_last  := in_val_last;

    -- Count values stream lists when it is handshaked and last.
    if in_val_valid = '1' and out_val_ready = '1' and in_val_last = '1' then
      v.val_list_count := r.val_list_count + 1;
    end if;

    -- Grab an item from the length list when the values stream has caught up
    if len_list_count_valid = '1' and unsigned(len_list_count) = v.val_list_count then
      c.len_counter_ready := '1';
      v.val_list_count := (others => '0');

      if len_list_count_last = '1' then
        out_val_last  <= c.out_val_last;
      end if;
    end if;

    -- Registered output
    d <= v;

    -- Combinatorial outputs
    out_val_valid <= c.out_val_valid;
    in_val_ready  <= c.in_val_ready;

    len_list_count_ready <= c.len_counter_ready;

  end process;

end Behavioral;
