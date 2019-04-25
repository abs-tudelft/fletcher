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

-- This unit parallelizes a stream. The first input ends up on the LSB of the
-- output. Optionally, a "last" flag may be provided that forces an item to be
-- transmitted to the output stream; in this case, the count output should be
-- used to determine the number of valid entries.
--
-- Example:
--
--   .------------.
--   | C0 | Data0 |
--   |----+-------|
--   | C1 | Data1 |
--   |----+-------|
--   | C2 | Data2 | last
--   |----+-------|
--   | C3 | Data3 |
--   |----+-------|
--   | C4 | Data4 |
--   |----+-------|
--   | C5 | Data5 |
--   |----+-------|
--   | C6 | Data6 |
--   |----+-------|
--   | C7 | Data7 | last
--   '------------'
--
-- gets parallelized to:
--
--   .------------------------------------.
--   | C2 |   U   | Data2 | Data1 | Data0 | count = "11" = 3
--   |----+-------+-------+-------+-------|
--   | C6 | Data6 | Data5 | Data4 | Data3 | count = [1]"00" = 4
--   |----+-------+-------+-------+-------|
--   | C7 |   U   |   U   |   U   | Data7 | count = "01" = 1
--   '------------------------------------'
--
-- The input stream may also have a count field and supply multiple items per
-- cycle. However, any input word for which not all items are present will
-- result in a word at the output, which greatly simplifies the logic and
-- parallelization register. Therefore, for efficiency, the input stream should
-- be as compressed as possible.
--
--             .-----.
-- Symbol: --->| a<b |--->
--             '-----'
--
-- (a = IN_COUNT_MAX, b = OUT_COUNT_MAX)

entity StreamParallelizer is
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

    -- Number of items per clock at the output. Should be an integer multiple
    -- of IN_COUNT_MAX, otherwise the upper item slots will never be used.
    OUT_COUNT_MAX               : natural;

    -- The number of bits in the out_count vector. This must be at least
    -- ceil(log2(OUT_COUNT_MAX)) and must be at least 1. If the factor is a
    -- power of two and this value equals log2(OUT_COUNT_MAX), a zero count
    -- implies that all entries are valid (there is an implicit '1' bit in
    -- front).
    OUT_COUNT_WIDTH             : natural

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
end StreamParallelizer;

architecture Behavioral of StreamParallelizer is

  -- Returns the number of bits needed to represent the given number. Returns
  -- 1 for the 0 special case to avoid null ranges.
  function bit_width(i: natural) return natural is
    variable x : natural;
    variable y : natural;
  begin
    x := i + 1;
    y := 0;
    while x > 1 loop
      x := (x + 1) / 2;
      y := y + 1;
    end loop;
    if y < 1 then
      y := 1;
    end if;
    return y;
  end bit_width;

  -- Internal "copies" of output signals.
  signal in_ready_s             : std_logic;
  signal out_valid_s            : std_logic;

  -- Number of complete input bundles valid counter, including the bundle
  -- currently being received from the input stream (whether it's valid or
  -- not).
  constant BUN_COUNT_MAX        : natural := OUT_COUNT_MAX / IN_COUNT_MAX;
  constant BUN_COUNT_WIDTH      : natural := bit_width(BUN_COUNT_MAX);
  signal bun_count              : std_logic_vector(BUN_COUNT_WIDTH-1 downto 0);

  -- Number of items valid counter, excluding the items in the bundle
  -- currently being received from the input stream (whether it's valid or
  -- not).
  signal item_count             : std_logic_vector(OUT_COUNT_WIDTH-1 downto 0);

  -- High when in_count is at its maximum value.
  signal in_full                : std_logic;

  -- Number of items valid in the input stream right now (undefined if the
  -- input stream is invalid) converted to the width of out_count, including
  -- the implicitly high MSB if applicable.
  signal in_count_conv          : std_logic_vector(OUT_COUNT_WIDTH-1 downto 0);

  -- Whether the counter is at the maximum value or the last flag is set in the
  -- input stream.
  signal count_max              : std_logic;

  -- Set default values as constants to prevent simulation truncate warning
  -- overflow.
  constant IN_COUNT_MAX_VAL     : std_logic_vector(IN_COUNT_WIDTH-1 downto 0)
    := std_logic_vector(to_unsigned(IN_COUNT_MAX, IN_COUNT_WIDTH));

  constant IN_COUNT_MAX_VAL_OUT : std_logic_vector(OUT_COUNT_WIDTH-1 downto 0)
    := std_logic_vector(to_unsigned(IN_COUNT_MAX, OUT_COUNT_WIDTH));

  constant BUN_COUNT_MAX_VAL    : std_logic_vector(BUN_COUNT_WIDTH-1 downto 0)
    := std_logic_vector(to_unsigned(BUN_COUNT_MAX, BUN_COUNT_WIDTH));

  constant BUN_COUNT_ONE_VAL    : std_logic_vector(BUN_COUNT_WIDTH-1 downto 0)
    := std_logic_vector(to_unsigned(1, BUN_COUNT_WIDTH));

begin

  -- Determine whether all the items in the input are valid.
  in_full <= '1'
        when in_count = IN_COUNT_MAX_VAL
        else '0';

  -- Determine whether we've reached capacity, the last flag is set, or the
  -- input does not contain the maximum amount of items. In these cases we
  -- either need to wait for the output stream to be ready or are outputting
  -- the parallelized word right now.
  count_max <= '1'
          when bun_count = BUN_COUNT_MAX_VAL
            or in_full = '0'
          else in_last;

  -- Upscale the input valid count to the output valid count width, taking the
  -- implicitly high MSB bit into consideration.
  in_count_conv <= std_logic_vector(resize(unsigned(in_count), OUT_COUNT_WIDTH))
              when in_full = '0'
              else IN_COUNT_MAX_VAL_OUT;

  -- We are ready when the output register contents will no longer be needed in
  -- the next cycle.
  in_ready_s <= out_ready or not out_valid_s;

  -- Generate the data, counter, and valid registers.
  reg_proc: process (clk) is
  begin
    if rising_edge(clk) then

      -- Invalidate the valid bit if the output stream is ready.
      if out_ready = '1' then
        out_valid_s <= '0';
      end if;

      -- Handle new input data.
      if in_valid = '1' and in_ready_s = '1' then

        -- In simulation, reset the data registers to undefined just before we
        -- write the first subword into them.
        -- pragma translate_off
        if bun_count = BUN_COUNT_ONE_VAL then
          out_data <= (others => 'U');
        end if;
        -- pragma translate_on

        -- "Shift" in data. Note that we can't use an actual shift register
        -- because the data should be LSB-first and LSB-aligned (shifting would
        -- give LSB-first MSB-aligned or vice versa).
        for i in 0 to BUN_COUNT_MAX-1 loop
          if bun_count = std_logic_vector(to_unsigned(i+1, BUN_COUNT_WIDTH)) then
            out_data((i+1)*IN_COUNT_MAX*DATA_WIDTH-1 downto i*IN_COUNT_MAX*DATA_WIDTH)
              <= in_data(IN_COUNT_MAX*DATA_WIDTH-1 downto 0);
          end if;
        end loop;

        -- Always register the control part of the stream data.
        out_data(CTRL_WIDTH+OUT_COUNT_MAX*DATA_WIDTH-1 downto OUT_COUNT_MAX*DATA_WIDTH-1)
          <= in_data(CTRL_WIDTH+IN_COUNT_MAX*DATA_WIDTH-1 downto IN_COUNT_MAX*DATA_WIDTH-1);
        out_count <= std_logic_vector(unsigned(item_count) + unsigned(in_count_conv));
        out_last <= in_last;

        -- Reset the valid counter to 1 if this is the last entry or increment
        -- it.
        if count_max = '1' then
          bun_count <= std_logic_vector(to_unsigned(1, BUN_COUNT_WIDTH));
          item_count <= (others => '0');
        else
          bun_count <= std_logic_vector(unsigned(bun_count) + 1);
          item_count <= std_logic_vector(unsigned(item_count) + IN_COUNT_MAX);
        end if;

        -- Generate the valid flag.
        if count_max = '1' then
          out_valid_s <= '1';
        end if;

      end if;

      -- Override the counter value to 1 and the valid flag to 0 at reset.
      if reset = '1' then
        bun_count <= std_logic_vector(to_unsigned(1, BUN_COUNT_WIDTH));
        item_count <= (others => '0');
        out_valid_s <= '0';
        -- pragma translate_off
        out_data <= (others => 'U');
        -- pragma translate_on
      end if;

    end if;
  end process;

  -- Forward internal copies of output signals.
  in_ready <= in_ready_s;
  out_valid <= out_valid_s;

end Behavioral;

