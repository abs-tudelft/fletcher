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

-- This unit instantiates a StreamParallelizer, StreamSerializer, or neither
-- based on its generic configuration.
--
--             .-----.
-- Symbol: --->| a:b |--->
--             '-----'
--
-- (a = IN_COUNT_MAX, b = OUT_COUNT_MAX)

entity StreamGearbox is
  generic (

    -- Width of the part of the input stream data vector that is to be
    -- parallelized.
    DATA_WIDTH                  : natural;

    -- Width of control information present on the MSB side of the input data
    -- vector that should NOT be parallized. This control data is taken from
    -- the last input word and is concatenated at the MSB side of the output.
    CTRL_WIDTH                  : natural := 0;

    -- Number of items per clock at the input.
    IN_COUNT_MAX                : natural := 1;

    -- The number of bits in the in_count vector. This must be at least
    -- ceil(log2(IN_COUNT_MAX)) and must be at least 1. If the factor is a
    -- power of two and this value equals log2(IN_COUNT_MAX), a zero count
    -- implies that all entries are valid (there is an implicit '1' bit in
    -- front).
    IN_COUNT_WIDTH              : natural := 1;

    -- Number of items per clock at the output.
    OUT_COUNT_MAX               : natural := 1;

    -- The number of bits in the out_count vector. This must be at least
    -- ceil(log2(OUT_COUNT_MAX)) and must be at least 1. If the factor is a
    -- power of two and this value equals log2(OUT_COUNT_MAX), a zero count
    -- implies that all entries are valid (there is an implicit '1' bit in
    -- front).
    OUT_COUNT_WIDTH             : natural := 1

  );
  port (

    -- Rising-edge sensitive clock.
    clk                         : in  std_logic;

    -- Active-high synchronous reset.
    reset                       : in  std_logic;

    -- Input stream.
    in_valid                    : in  std_logic;
    in_ready                    : out std_logic;
    in_data                     : in  std_logic_vector(CTRL_WIDTH+IN_COUNT_MAX*DATA_WIDTH-1 downto 0);
    in_count                    : in  std_logic_vector(IN_COUNT_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(IN_COUNT_MAX, IN_COUNT_WIDTH));
    in_last                     : in  std_logic := '0';

    -- Output stream.
    out_valid                   : out std_logic;
    out_ready                   : in  std_logic;
    out_data                    : out std_logic_vector(CTRL_WIDTH+OUT_COUNT_MAX*DATA_WIDTH-1 downto 0);
    out_count                   : out std_logic_vector(OUT_COUNT_WIDTH-1 downto 0);
    out_last                    : out std_logic

  );
end StreamGearbox;

architecture Behavioral of StreamGearbox is
begin

  parallelize: if IN_COUNT_MAX < OUT_COUNT_MAX generate
  begin
    inst: StreamParallelizer
      generic map (
        DATA_WIDTH              => DATA_WIDTH,
        CTRL_WIDTH              => CTRL_WIDTH,
        IN_COUNT_MAX            => IN_COUNT_MAX,
        IN_COUNT_WIDTH          => IN_COUNT_WIDTH,
        OUT_COUNT_MAX           => OUT_COUNT_MAX,
        OUT_COUNT_WIDTH         => OUT_COUNT_WIDTH
      )
      port map (
        clk                     => clk,
        reset                   => reset,
        in_valid                => in_valid,
        in_ready                => in_ready,
        in_data                 => in_data,
        in_count                => in_count,
        in_last                 => in_last,
        out_valid               => out_valid,
        out_ready               => out_ready,
        out_data                => out_data,
        out_count               => out_count,
        out_last                => out_last
      );
  end generate;

  serialize: if IN_COUNT_MAX > OUT_COUNT_MAX generate
  begin
    inst: StreamSerializer
      generic map (
        DATA_WIDTH              => DATA_WIDTH,
        CTRL_WIDTH              => CTRL_WIDTH,
        IN_COUNT_MAX            => IN_COUNT_MAX,
        IN_COUNT_WIDTH          => IN_COUNT_WIDTH,
        OUT_COUNT_MAX           => OUT_COUNT_MAX,
        OUT_COUNT_WIDTH         => OUT_COUNT_WIDTH
      )
      port map (
        clk                     => clk,
        reset                   => reset,
        in_valid                => in_valid,
        in_ready                => in_ready,
        in_data                 => in_data,
        in_count                => in_count,
        in_last                 => in_last,
        out_valid               => out_valid,
        out_ready               => out_ready,
        out_data                => out_data,
        out_count               => out_count,
        out_last                => out_last
      );
  end generate;

  nop: if IN_COUNT_MAX = OUT_COUNT_MAX generate
  begin
    out_valid <= in_valid;
    in_ready  <= out_ready;
    out_data  <= in_data;
    out_count <= resize_count(in_count, OUT_COUNT_WIDTH);
    out_last  <= in_last;
  end generate;

end Behavioral;

