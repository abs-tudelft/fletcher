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
use work.streams.all;

-- This unit optionally breaks all combinatorial paths from the input stream to
-- the output stream using slices and FIFOs.
--
--             .---.
-- Symbol: --->|buf|--->
--             '---'

entity StreamBuffer is
  generic (

    -- Minimum depth. This is rounded up to:
    --   0: no slices or FIFOs inserted
    --   2: a single slice is inserted
    --   4: two slices are inserted
    --   4 + power-of-2, minimum 8: FIFO with a slice before and after
    MIN_DEPTH                   : natural;

    -- Width of the stream data vector.
    DATA_WIDTH                  : natural;

    -- RAM configuration. This is passed directly to the Ram1R1W instance used
    -- for the FIFO, if a FIFO is inserted.
    RAM_CONFIG                  : string := ""

  );
  port (

    -- Rising-edge sensitive clock.
    clk                         : in  std_logic;

    -- Active-high synchronous reset.
    reset                       : in  std_logic;

    -- Input stream.
    in_valid                    : in  std_logic;
    in_ready                    : out std_logic;
    in_data                     : in  std_logic_vector(DATA_WIDTH-1 downto 0);

    -- Output stream.
    out_valid                   : out std_logic;
    out_ready                   : in  std_logic;
    out_data                    : out std_logic_vector(DATA_WIDTH-1 downto 0)

  );
end StreamBuffer;

architecture Behavioral of StreamBuffer is

  -- Optionally reg-sliced input stream.
  signal inS_valid              : std_logic;
  signal inS_ready              : std_logic;
  signal inS_data               : std_logic_vector(DATA_WIDTH-1 downto 0);

  -- Onput stream before an optional reg-slice.
  signal outS_valid             : std_logic;
  signal outS_ready             : std_logic;
  signal outS_data              : std_logic_vector(DATA_WIDTH-1 downto 0);

begin

  -- Optional input slice.
  input_slice_gen: if MIN_DEPTH > 0 generate
  begin
    slice_inst: StreamSlice
      generic map (
        DATA_WIDTH              => DATA_WIDTH
      )
      port map (
        clk                     => clk,
        reset                   => reset,
        in_valid                => in_valid,
        in_ready                => in_ready,
        in_data                 => in_data,
        out_valid               => inS_valid,
        out_ready               => inS_ready,
        out_data                => inS_data
      );
  end generate;
  no_input_slice_gen: if MIN_DEPTH <= 0 generate
  begin
    inS_valid <= in_valid;
    in_ready  <= inS_ready;
    inS_data  <= in_data;
  end generate;

  -- Optional FIFO.
  fifo_gen: if MIN_DEPTH > 4 generate

    -- Returns max(2, ceil(log2(depth - 4)))
    function depth_log2(depth: natural) return natural is
      variable x : natural;
      variable y : natural;
    begin
      x := depth - 4;
      y := 0;
      while x > 1 loop
        x := (x + 1) / 2;
        y := y + 1;
      end loop;
      if y < 2 then
        y := 2;
      end if;
      return y;
    end depth_log2;

  begin
    slice_inst: StreamFIFO
      generic map (
        DEPTH_LOG2              => depth_log2(MIN_DEPTH),
        DATA_WIDTH              => DATA_WIDTH,
        RAM_CONFIG              => RAM_CONFIG
      )
      port map (
        in_clk                  => clk,
        in_reset                => reset,
        in_valid                => inS_valid,
        in_ready                => inS_ready,
        in_data                 => inS_data,

        out_clk                 => clk,
        out_reset               => reset,
        out_valid               => outS_valid,
        out_ready               => outS_ready,
        out_data                => outS_data
      );
  end generate;
  no_fifo_gen: if MIN_DEPTH <= 4 generate
  begin
    outS_valid <= inS_valid;
    inS_ready  <= outS_ready;
    outS_data  <= inS_data;
  end generate;

  -- Optional output slice.
  output_slice_gen: if MIN_DEPTH > 2 generate
  begin
    slice_inst: StreamSlice
      generic map (
        DATA_WIDTH              => DATA_WIDTH
      )
      port map (
        clk                     => clk,
        reset                   => reset,
        in_valid                => outS_valid,
        in_ready                => outS_ready,
        in_data                 => outS_data,
        out_valid               => out_valid,
        out_ready               => out_ready,
        out_data                => out_data
      );
  end generate;
  no_output_slice_gen: if MIN_DEPTH <= 2 generate
  begin
    out_valid  <= outS_valid;
    outS_ready <= out_ready;
    out_data   <= outS_data;
  end generate;

end Behavioral;

