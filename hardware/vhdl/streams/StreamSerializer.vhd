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

-- This unit serializes a stream, performing the inverse operation of
-- StreamParallelizer.
--
--             .-----.
-- Symbol: --->| a>b |--->
--             '-----'
--
-- (a = IN_COUNT_MAX, b = OUT_COUNT_MAX)

entity StreamSerializer is
  generic (

    -- Width of the serialized part of the output stream data vector.
    DATA_WIDTH                  : natural;

    -- Width of control information present on the MSB side of the input data
    -- vector that should NOT be serialized. This control data is replicated
    -- and concatenated on the MSB side of the output stream.
    CTRL_WIDTH                  : natural := 0;

    -- Number of items per clock at the input. Must be at least 2 and must be
    -- more than OUT_COUNT_MAX. For efficiency, IN_COUNT_MAX / OUT_COUNT_MAX
    -- should be an integer, because outputted bundles of items cannot cross
    -- input bundle boundaries, but this is not required.
    IN_COUNT_MAX                : natural;

    -- The number of bits in the in_count vector. This must be at least
    -- ceil(log2(IN_COUNT_MAX)) and must be at least 1. If the factor is a
    -- power of two and this value equals log2(IN_COUNT_MAX), a zero count
    -- implies that all entries are valid (there is an implicit '1' bit in
    -- front).
    IN_COUNT_WIDTH              : natural;

    -- Number of items per clock at the output. Must be less than IN_COUNT_MAX.
    -- For efficiency, IN_COUNT_MAX / OUT_COUNT_MAX should be an integer,
    -- because outputted bundles of items cannot cross input bundle boundaries,
    -- but this is not required.
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
    in_last                     : in  std_logic := '1';

    -- Output stream.
    out_valid                   : out std_logic;
    out_ready                   : in  std_logic;
    out_data                    : out std_logic_vector(CTRL_WIDTH+OUT_COUNT_MAX*DATA_WIDTH-1 downto 0);
    out_count                   : out std_logic_vector(OUT_COUNT_WIDTH-1 downto 0);
    out_last                    : out std_logic

  );
end StreamSerializer;

architecture Behavioral of StreamSerializer is

  -- Internal "copy" of the in_ready output signal.
  signal in_ready_s             : std_logic;

  -- Asserted when we're about to shift out the last valid subword of the shift
  -- register.
  signal last_subword           : std_logic;

  -- Data holding/shift registers.
  signal data_r                 : std_logic_vector(CTRL_WIDTH+IN_COUNT_MAX*DATA_WIDTH-1 downto 0);
  signal last_r                 : std_logic;

  -- Number of valid subwords remaining in the shift register. 0 implies a
  -- '1' bit in front, i.e. all subwords are valid.
  signal count_r                : std_logic_vector(IN_COUNT_WIDTH-1 downto 0);

  -- Indicates that the current "data" in the holding register is a null
  -- packet, i.e. one of size zero. This requires a special case because
  -- count_r can't represent zero.
  signal null_r                 : std_logic;

  -- Whether the data holding/shift register is valid at all.
  signal reg_valid              : std_logic;

  -- Set default values as constants to prevent simulation truncate warning
  -- overflow.
  constant IN_COUNT_ONE_VAL     : std_logic_vector(IN_COUNT_WIDTH-1 downto 0)
    := std_logic_vector(to_unsigned(1, IN_COUNT_WIDTH));
  constant OU_COUNT_MAX_IN_VAL     : std_logic_vector(IN_COUNT_WIDTH-1 downto 0)
    := std_logic_vector(to_unsigned(OUT_COUNT_MAX, IN_COUNT_WIDTH));
  constant OUT_COUNT_MAX_VAL    : std_logic_vector(OUT_COUNT_WIDTH-1 downto 0)
    := std_logic_vector(to_unsigned(OUT_COUNT_MAX, OUT_COUNT_WIDTH));

begin

  -- The input stream is ready when the serialization register is invalid or if
  -- it's about to be.
  in_ready_s <= (out_ready and last_subword) or not reg_valid;
  in_ready <= in_ready_s;

  -- Determine whether we're about to shift out the last valid part of the
  -- shift register.
  last_subword <= '1'
             when count_r >= IN_COUNT_ONE_VAL
              and count_r <= OU_COUNT_MAX_IN_VAL
             else null_r;

  -- Generate the registers.
  reg_proc: process (clk) is
  begin
    if rising_edge(clk) then

      if in_valid = '1' and in_ready_s = '1' then

        -- Load the new word into the shift and holding registers.
        data_r <= in_data;
        last_r <= in_last;
        count_r <= in_count;
        if unsigned(in_count) = 0 and IN_COUNT_MAX < 2**IN_COUNT_WIDTH then
          null_r <= '1';
        else
          null_r <= '0';
        end if;

        -- Validate the shift register contents.
        reg_valid <= '1';

      elsif reg_valid = '1' and out_ready = '1' then

        -- Right-shift the data vector, ignoring the control data.
        data_r(IN_COUNT_MAX*DATA_WIDTH-1 - OUT_COUNT_MAX*DATA_WIDTH downto 0)
          <= data_r(IN_COUNT_MAX*DATA_WIDTH-1 downto OUT_COUNT_MAX*DATA_WIDTH);

        -- Decrement the count, or if this was the last word, invalidate the
        -- shift register.
        if last_subword = '1' then
          reg_valid <= '0';
        else
          count_r <= std_logic_vector(unsigned(count_r) - OUT_COUNT_MAX);
        end if;

      end if;

      -- Override the register valid flag low when resetting.
      if reset = '1' then
        reg_valid <= '0';
      end if;

    end if;
  end process;

  -- Select the right parts of the data shift/holding register for the output.
  -- Avoid null ranges in assignments because some tools don't like them.
  ctrl_data_gen: if CTRL_WIDTH > 0 generate
  begin
    out_data <= data_r(CTRL_WIDTH + IN_COUNT_MAX*DATA_WIDTH-1 downto IN_COUNT_MAX*DATA_WIDTH)
              & data_r(OUT_COUNT_MAX*DATA_WIDTH-1 downto 0);
  end generate;
  no_ctrl_data_gen: if CTRL_WIDTH = 0 generate
  begin
    out_data <= data_r(OUT_COUNT_MAX*DATA_WIDTH-1 downto 0);
  end generate;

  -- Set the last flag when this is the last subword AND the last flag was set
  -- by the input stream.
  out_last <= last_subword and last_r;

  -- If this is the last subword, the output count equals the current valid
  -- count register. If it is not the last subword, it is always the maximum
  -- size.
  out_count <= resize_count(count_r, OUT_COUNT_WIDTH)
          when last_subword = '1'
          else OUT_COUNT_MAX_VAL;

  -- The output stream data is valid when the serialization register is valid.
  out_valid <= reg_valid;

end Behavioral;

