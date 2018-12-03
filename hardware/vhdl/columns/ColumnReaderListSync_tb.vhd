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
use work.StreamSim.all;
use work.Columns.all;

entity ColumnReaderListSync_tb is
end ColumnReaderListSync_tb;

architecture Behavioral of ColumnReaderListSync_tb is

  constant ELEMENT_WIDTH        : natural := 4;
  constant LENGTH_WIDTH         : natural := 3;
  constant COUNT_MAX            : natural := 4;
  constant COUNT_WIDTH          : natural := 2;
  constant DATA_IN_SLICE        : boolean := false;
  constant LEN_IN_SLICE         : boolean := false;
  constant OUT_SLICE            : boolean := true;

  signal clk                    : std_logic := '1';
  signal reset                  : std_logic;

  signal inl_valid              : std_logic;
  signal inl_ready              : std_logic;
  signal inl_length             : std_logic_vector(LENGTH_WIDTH-1 downto 0);

  signal ind_valid              : std_logic;
  signal ind_ready              : std_logic;
  signal ind_data               : std_logic_vector(COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
  signal ind_count              : std_logic_vector(COUNT_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(COUNT_MAX, COUNT_WIDTH));

  signal out_valid              : std_logic;
  signal out_ready              : std_logic;
  signal out_last               : std_logic;
  signal out_dvalid             : std_logic;
  signal out_data               : std_logic_vector(COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
  signal out_count              : std_logic_vector(COUNT_WIDTH-1 downto 0);

  signal out_last_mon           : std_logic;
  signal out_dvalid_mon         : std_logic;
  signal out_data_mon           : std_logic_vector(COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
  signal out_count_mon          : std_logic_vector(COUNT_WIDTH-1 downto 0);

begin

  clk_proc: process is
  begin
    clk <= '1';
    wait for 5 ns;
    clk <= '0';
    wait for 5 ns;
  end process;

  reset_proc: process is
  begin
    reset <= '1';
    wait for 50 ns;
    wait until rising_edge(clk);
    reset <= '0';
    wait for 100 us;
    wait until rising_edge(clk);
  end process;

  prod_handshake_inst: StreamTbProd
    generic map (
      DATA_WIDTH                => 1,
      SEED                      => 1
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      out_valid                 => ind_valid,
      out_ready                 => ind_ready
    );

  prod_data_proc: process is
    variable seed1              : positive := 1;
    variable seed2              : positive := 1;
    variable rand               : real;
    variable data               : unsigned(ELEMENT_WIDTH-1 downto 0);
    variable count              : natural;
  begin
    data := (others => '0');

    state: loop

      -- Randomize count.
      uniform(seed1, seed2, rand);
      count := integer(floor(rand * real(COUNT_MAX))) + 1;
      ind_count <= std_logic_vector(to_unsigned(count mod 2**COUNT_WIDTH, COUNT_WIDTH));

      -- Write data.
      for i in 0 to count-1 loop
        ind_data((i+1)*ELEMENT_WIDTH-1 downto i*ELEMENT_WIDTH) <= std_logic_vector(data);
        data := data + 1;
      end loop;
      for i in count to COUNT_MAX-1 loop
        ind_data((i+1)*ELEMENT_WIDTH-1 downto i*ELEMENT_WIDTH) <= (others => 'U');
      end loop;

      -- Wait for acknowledgement.
      loop
        wait until rising_edge(clk);
        exit state when reset = '1';
        next when ind_valid = '0';
        next when ind_ready = '0';
        exit;
      end loop;

    end loop;
  end process;

  -- Generate list lengths.
  prod_inl: StreamTbProd
    generic map (
      DATA_WIDTH                => LENGTH_WIDTH,
      SEED                      => 1
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      out_valid                 => inl_valid,
      out_ready                 => inl_ready,
      out_data                  => inl_length
    );

  -- Instantiate UUT.
  uut: ColumnReaderListSync
    generic map (
      ELEMENT_WIDTH             => ELEMENT_WIDTH,
      LENGTH_WIDTH              => LENGTH_WIDTH,
      COUNT_MAX                 => COUNT_MAX,
      COUNT_WIDTH               => COUNT_WIDTH,
      DATA_IN_SLICE             => DATA_IN_SLICE,
      LEN_IN_SLICE              => LEN_IN_SLICE,
      OUT_SLICE                 => OUT_SLICE
    )
    port map (
      clk                       => clk,
      reset                     => reset,

      inl_valid                 => inl_valid,
      inl_ready                 => inl_ready,
      inl_length                => inl_length,

      ind_valid                 => ind_valid,
      ind_ready                 => ind_ready,
      ind_data                  => ind_data,
      ind_count                 => ind_count,

      out_valid                 => out_valid,
      out_ready                 => out_ready,
      out_last                  => out_last,
      out_dvalid                => out_dvalid,
      out_data                  => out_data,
      out_count                 => out_count
    );

  -- Randomize output handshake.
  cons_out: StreamTbCons
    generic map (
      DATA_WIDTH                => 1,
      SEED                      => 2
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_valid                  => out_valid,
      in_ready                  => out_ready,
      in_data                   => "0"
    );

  out_last_mon    <= out_last   when out_valid = '1' and out_ready = '1' else 'Z';
  out_dvalid_mon  <= out_dvalid when out_valid = '1' and out_ready = '1' else 'Z';
  out_data_mon    <= out_data   when out_valid = '1' and out_ready = '1' else (others => 'Z');
  out_count_mon   <= out_count  when out_valid = '1' and out_ready = '1' else (others => 'Z');

  check_out: process is
    variable data               : unsigned(ELEMENT_WIDTH-1 downto 0);
    variable count              : integer;
    variable len                : unsigned(LENGTH_WIDTH-1 downto 0);
    variable remain             : integer;
  begin
    data := (others => '0');
    len := (others => '0');
    remain := 0;
    loop
      wait until rising_edge(clk);
      exit when reset = '1';
      next when out_last_mon = 'Z';

      -- Figure out the count as an integer.
      if out_dvalid = '1' then
        count := to_integer(unsigned(resize_count(out_count, COUNT_WIDTH+1)));
      else
        count := 0;
      end if;

      -- Check the data.
      for i in 0 to count-1 loop
        assert out_data((i+1)*ELEMENT_WIDTH-1 downto i*ELEMENT_WIDTH) = std_logic_vector(data)
          report "Stream data integrity check failed (data not in sequence)" severity failure;
        data := data + 1;
      end loop;

      -- Check the count. It must be COUNT_MAX if this is not the last
      -- transfer.
      assert count = COUNT_MAX or out_last = '1'
        report "Stream data integrity check failed (not enough elements returned)" severity failure;

      -- Update the list elements remaining counter.
      remain := remain - count;

      -- Update the expected list length when last is set.
      if out_last = '1' then
        assert remain = 0
          report "Stream data integrity check failed (remain = " & integer'image(remain) & ")" severity failure;
        len := len + 1;
        remain := to_integer(len);
      end if;

    end loop;
  end process;


end Behavioral;

