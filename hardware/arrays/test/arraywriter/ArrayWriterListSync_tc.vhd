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
use ieee.math_real.all;

library work;
use work.Streams.all;
use work.Arrays.all;
use work.SimUtils.all;

--pragma simulation timeout 1 ms

entity ArrayWriterListSync_tc is
end ArrayWriterListSync_tc;

architecture Behavioral of ArrayWriterListSync_tc is

  constant LEN_SEED             : positive := 16#BEE15#;
  constant ELEM_SEED            : positive := 16#F00D#;
  constant MAX_LEN              : real     := 128.0;

  constant ELEMENT_WIDTH        : natural  := 4;
  constant LENGTH_WIDTH         : natural  := 8;
  constant COUNT_MAX            : natural  := 4;
  constant COUNT_WIDTH          : natural  := 2;

  constant GENERATE_LENGTH      : boolean  := true;
  constant NORMALIZE            : boolean  := false;
  constant ELEM_LAST_FROM_LENGTH: boolean  := true;

  constant NUM_LISTS            : natural  := 100;

  signal clk                    : std_logic;
  signal reset                  : std_logic;

  signal inl_valid              : std_logic;
  signal inl_ready              : std_logic;
  signal inl_length             : std_logic_vector(LENGTH_WIDTH-1 downto 0);
  signal inl_last               : std_logic;

  signal ine_valid              : std_logic;
  signal ine_ready              : std_logic;
  signal ine_dvalid             : std_logic := '1';
  signal ine_data               : std_logic_vector(COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
  signal ine_count              : std_logic_vector(COUNT_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(COUNT_MAX, COUNT_WIDTH));
  signal ine_last               : std_logic;

  signal outl_valid             : std_logic;
  signal outl_ready             : std_logic := '1';
  signal outl_length            : std_logic_vector(LENGTH_WIDTH-1 downto 0);
  signal outl_last              : std_logic;

  signal oute_valid             : std_logic;
  signal oute_ready             : std_logic := '1';
  signal oute_last              : std_logic;
  signal oute_dvalid            : std_logic;
  signal oute_data              : std_logic_vector(COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
  signal oute_count             : std_logic_vector(COUNT_WIDTH-1 downto 0);

  signal clock_stop             : boolean := false;
  signal len_done               : boolean := false;
begin

  clk_proc: process is
  begin
    if not clock_stop then
      clk <= '1';
      wait for 5 ns;
      clk <= '0';
      wait for 5 ns;
    else
      wait;
    end if;
  end process;

  reset_proc: process is
  begin
    reset <= '1';
    wait for 50 ns;
    wait until rising_edge(clk);
    reset <= '0';
    wait;
  end process;

  len_stream_proc: process is
    variable seed1              : positive := LEN_SEED;
    variable seed2              : positive := 1;
    variable rand               : real;

    variable list               : integer;

    variable len                : integer;
  begin

    inl_valid   <= '0';
    inl_length  <= (others => 'U');
    inl_last    <= '0';

    loop
      wait until rising_edge(clk);
      exit when reset = '0';
    end loop;

    list := 0;

    loop
      -- Randomize list length
      uniform(seed1, seed2, rand);
      len := natural(rand * MAX_LEN);

      dumpStdOut("length stream: list " & integer'image(list) & " length is " & integer'image(len));

      -- Set the length vector
      inl_length <= std_logic_vector(to_unsigned(len, LENGTH_WIDTH));

      -- Set last
      if list = NUM_LISTS-1 then
        inl_last <= '1';
      else
        inl_last <= '0';
      end if;

      -- Validate length
      inl_valid <= '1';

      -- Wait for handshake
      loop
        wait until rising_edge(clk);
        exit when inl_ready = '1';
      end loop;

      -- A list item is completed.
      list := list + 1;

      exit when list = NUM_LISTS;
    end loop;

    inl_valid   <= '0';
    inl_length  <= (others => 'U');
    inl_last    <= '0';

    len_done <= true;

    wait;
  end process;


  elem_stream_proc: process is
    variable lseed1             : positive := LEN_SEED;
    variable lseed2             : positive := 1;
    variable lrand              : real;

    variable seed1              : positive := ELEM_SEED;
    variable seed2              : positive := 1;
    variable rand               : real;

    variable data               : unsigned(ELEMENT_WIDTH-1 downto 0);
    variable count              : natural;

    variable len                : integer;
    variable orig_len           : integer;
    variable empty              : boolean;

    variable list               : integer;

    variable element            : natural := 0;
  begin

    ine_valid <= '0';

    -- Wait until no reset
    loop
      wait until rising_edge(clk);
      exit when reset = '0';
    end loop;

    list := 0;

    -- Loop over different list
    loop
      ine_valid   <= '0';
      ine_last    <= '0';
      ine_count   <= (others => 'U');
      ine_dvalid  <= '0';
      ine_data    <= (others => 'U');

      exit when list = NUM_LISTS;

      -- Randomize list length, using the same seed as the len stream process
      uniform(lseed1, lseed2, lrand);
      len := natural(lrand * MAX_LEN);
      orig_len := len;

      dumpStdOut("element stream: list " & integer'image(list) & " length is " & integer'image(len));

      if len = 0 then
        empty := true;
      else
        empty := false;
      end if;

      -- Generate some data
      loop
        -- Randomize count
        uniform(seed1, seed2, rand);
        count := 1 + work.Utils.min(3, natural(2.0*rand * real(COUNT_MAX)));

        dumpStdOut("element stream: count is " & integer'image(count));

        -- Resize count if necessary
        if len - count < 0 then
          count := len;
        end if;

        ine_count <= std_logic_vector(to_unsigned(count, COUNT_WIDTH));

        -- Determine elements
        for e in 0 to count-1 loop
          element := element + 1;
          ine_data((e+1)*ELEMENT_WIDTH-1 downto e*ELEMENT_WIDTH) <= std_logic_vector(to_unsigned(element, ELEMENT_WIDTH));
        end loop;
        for e in count to COUNT_MAX-1 loop
          ine_data((e+1)*ELEMENT_WIDTH-1 downto e*ELEMENT_WIDTH) <= (others => 'U');
        end loop;

        -- Subtract count
        len := len - count;

        -- Determine last
        if len = 0 then
          ine_last <= '1';
        end if;

        -- Determine dvalid
        if empty then
          ine_dvalid <= '0';
        else
          ine_dvalid <= '1';
        end if;

        ine_valid <= '1';

        -- Wait for acceptance
        loop
          wait until rising_edge(clk);
          exit when ine_ready = '1';
        end loop;

        if ine_last = '1' then
          list := list + 1;
        end if;

        exit when len = 0;

      end loop;

    end loop;

    -- Wait a bit for all the outputs in a nasty way
    wait for 100 ns;

    clock_stop <= true;
    wait;

  end process;

  -- Instantiate UUT.
  uut: ArrayWriterListSync
    generic map (
      ELEMENT_WIDTH             => ELEMENT_WIDTH,
      LENGTH_WIDTH              => LENGTH_WIDTH,
      COUNT_MAX                 => COUNT_MAX,
      COUNT_WIDTH               => COUNT_WIDTH,
      GENERATE_LENGTH           => GENERATE_LENGTH,
      NORMALIZE                 => NORMALIZE,
      ELEM_LAST_FROM_LENGTH     => ELEM_LAST_FROM_LENGTH,
      DATA_IN_SLICE             => false,
      LEN_IN_SLICE              => false,
      OUT_SLICE                 => true
    )
    port map (
      clk                       => clk,
      reset                     => reset,

      inl_valid                 => inl_valid,
      inl_ready                 => inl_ready,
      inl_length                => inl_length,
      inl_last                  => inl_last,

      ine_valid                 => ine_valid,
      ine_ready                 => ine_ready,
      ine_dvalid                => ine_dvalid,
      ine_data                  => ine_data,
      ine_count                 => ine_count,
      ine_last                  => ine_last,

      outl_valid                => outl_valid,
      outl_ready                => outl_ready,
      outl_length               => outl_length,
      outl_last                 => outl_last,

      oute_valid                => oute_valid,
      oute_ready                => oute_ready,
      oute_last                 => oute_last,
      oute_dvalid               => oute_dvalid,
      oute_data                 => oute_data,
      oute_count                => oute_count
    );

  check_len: process is
    variable lseed1             : positive := LEN_SEED;
    variable lseed2             : positive := 1;
    variable lrand              : real;

    variable len                : natural;
    variable list               : natural := 0;
  begin
    outl_ready <= '1';
    loop
      uniform(lseed1, lseed2, lrand);
      len := natural(lrand * MAX_LEN);

      -- Wait for a valid length output
      loop
        wait until rising_edge(clk);
        exit when outl_valid = '1';
      end loop;

      assert unsigned(outl_length) = to_unsigned(len, LENGTH_WIDTH)
        report "Length output stream: Transfer " & integer'image(list)
             & " is " & integer'image(to_integer(unsigned(outl_length)))
             & ", expected: " & integer'image(len)
        severity failure;

      list := list + 1;

      exit when list = NUM_LISTS;
    end loop;

    wait;
  end process;

  check_data: process is
    variable seed1              : positive := ELEM_SEED;
    variable seed2              : positive := 1;
    variable rand               : real;

    variable element            : natural := 0;
  begin
    oute_ready <= '1';
    loop
      -- Wait for a valid element output
      loop
        wait until rising_edge(clk);
        exit when oute_valid = '1';
      end loop;

      -- Check data if valid
      if oute_dvalid = '1' then
        for e in 0 to to_integer(unsigned(resize_count(oute_count, COUNT_WIDTH+1)))-1 loop
          element := element + 1;
          assert oute_data((e+1)*ELEMENT_WIDTH-1 downto e*ELEMENT_WIDTH) = std_logic_vector(to_unsigned(element, ELEMENT_WIDTH))
            report "Invalid data on output element stream."
            severity failure;
        end loop;
      end if;

      exit when len_done;

    end loop;

    wait;
  end process;


end Behavioral;

