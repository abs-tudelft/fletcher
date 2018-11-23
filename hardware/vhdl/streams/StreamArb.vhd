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

-- This unit multiplexes the data from the input streams into a single output
-- stream using fixed priority or round-robin scheduling. The index of the
-- stream that was selected is available as an output for later demultiplexing.
--
--             .-.
--         --->|  \
-- Symbol: --->| A |--->
--         --->|  /
--             '-'

entity StreamArb is
  generic (

    -- Number of input streams.
    NUM_INPUTS                  : natural;

    -- Width of the stream index field. This should be set to
    -- ceil(log2(NUM_INPUTS)).
    INDEX_WIDTH                 : natural;

    -- Width of the stream data vectors.
    DATA_WIDTH                  : natural;

    -- Arbitration method. Must be "ROUND-ROBIN" or "FIXED". If fixed,
    -- lower-indexed streams take precedence.
    ARB_METHOD                  : string := "ROUND-ROBIN"

  );
  port (

    -- Rising-edge sensitive clock.
    clk                         : in  std_logic;

    -- Active-high synchronous reset.
    reset                       : in  std_logic;

    -- Input streams. The in_data signal consists of the stream data vectors
    -- concatenated in the same order as in_valid and in_ready. The in_last
    -- signal marks the end of a non-interruptable group of items; if it is not
    -- set for the currently selected stream, the arbiter will remain locked.
    in_valid                    : in  std_logic_vector(NUM_INPUTS-1 downto 0);
    in_ready                    : out std_logic_vector(NUM_INPUTS-1 downto 0);
    in_data                     : in  std_logic_vector(NUM_INPUTS*DATA_WIDTH-1 downto 0);
    in_last                     : in  std_logic_vector(NUM_INPUTS-1 downto 0) := (others => '1');

    -- Output stream. out_index and out_last have the same timing as out_data, so it can be
    -- considered to be part of the stream.
    out_valid                   : out std_logic;
    out_ready                   : in  std_logic;
    out_data                    : out std_logic_vector(DATA_WIDTH-1 downto 0);
    out_last                    : out std_logic;
    out_index                   : out std_logic_vector(INDEX_WIDTH-1 downto 0)

  );
end StreamArb;

architecture Behavioral of StreamArb is

  -- Combinatorially selected stream index based on priority encoder over valid
  -- signals.
  signal index_comb             : std_logic_vector(INDEX_WIDTH-1 downto 0);

  -- The currently selected stream index, taking locking into consideration.
  signal index                  : std_logic_vector(INDEX_WIDTH-1 downto 0);

  -- The previously selected stream index.
  signal index_r                : std_logic_vector(INDEX_WIDTH-1 downto 0);

  -- Whether the stream selection is currently locked.
  signal locked                 : std_logic;

  -- Internal "copies" of output signals.
  signal out_last_s             : std_logic;
  signal out_valid_s            : std_logic;

begin

  -- Priority encoder to select which stream should be active (unless the
  -- selection is locked).
  prio_enc: process (in_valid, index_r) is
  begin

    -- Default index is the lowest priority, so we don't have to check that
    -- valid bit.
    index_comb <= std_logic_vector(to_unsigned(NUM_INPUTS-1, INDEX_WIDTH));

    -- Override with lower indices if the associated stream is valid.
    for i in NUM_INPUTS-2 downto 0 loop
      if in_valid(i) = '1' then
        index_comb <= std_logic_vector(to_unsigned(i, INDEX_WIDTH));
      end if;
    end loop;

    -- Add a level of conditional higher-priority inputs based on the
    -- previously selected index for round-robin arbitration.
    if ARB_METHOD = "ROUND-ROBIN" then
      for i in NUM_INPUTS-1 downto 1 loop
        if i > to_integer(unsigned(index_r)) then
          index_comb <= std_logic_vector(to_unsigned(i, INDEX_WIDTH));
        end if;
      end loop;
    end if;

  end process;

  -- Handle locking.
  index <= index_r when locked = '1' else index_comb;

  -- Remember the currently selected index and whether the transfer should be
  -- locked for the next cycle.
  lock_proc: process (clk) is
  begin
    if rising_edge(clk) then

      index_r <= index;

      -- As soon as we validate our output, we can't change master until we do
      -- a "last" transfer.
      if out_valid_s = '1' then
        locked <= '1';
      end if;

      -- Unlock if we just acknowledged the last transfer.
      if out_valid_s = '1' and out_ready = '1' then
        locked <= not out_last_s;
      end if;

      -- Unlock when resetting.
      if reset = '1' then
        index_r <= (others => '0');
        locked <= '0';
      end if;

    end if;
  end process;

  -- Multiplex the incoming stream input signals.
  mux_proc: process (index, in_data, in_last, in_valid) is
    variable i : integer range 0 to 2**INDEX_WIDTH-1;
  begin
    i := to_integer(unsigned(index));
    if i >= NUM_INPUTS then
      i := NUM_INPUTS-1;
    end if;
    out_data <= in_data(i*DATA_WIDTH + DATA_WIDTH-1 downto i*DATA_WIDTH);
    out_last_s <= in_last(i);
    out_valid_s <= in_valid(i);
  end process;

  -- Demultiplex the output stream ready signal.
  demux_proc: process (index, out_ready) is
  begin
    for i in 0 to NUM_INPUTS-1 loop
      if i = to_integer(unsigned(index)) then
        in_ready(i) <= out_ready;
      else
        in_ready(i) <= '0';
      end if;
    end loop;
  end process;

  -- Forward internal copies of signals.
  out_last <= out_last_s;
  out_index <= index;
  out_valid <= out_valid_s;

end Behavioral;

