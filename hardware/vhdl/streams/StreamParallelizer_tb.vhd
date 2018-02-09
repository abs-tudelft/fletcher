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
use work.streams.all;

entity StreamParallelizer_tb is
end StreamParallelizer_tb;

architecture Behavioral of StreamParallelizer_tb is

  signal clk                    : std_logic := '1';
  signal reset                  : std_logic;

  signal valid_a                : std_logic;
  signal ready_a                : std_logic;
  signal data_a                 : std_logic_vector(3 downto 0);
  signal last_a                 : std_logic;

  signal valid_b                : std_logic;
  signal ready_b                : std_logic;
  signal data_b                 : std_logic_vector(18 downto 0);

  signal monitor_data0_b        : std_logic_vector(3 downto 0);
  signal monitor_data1_b        : std_logic_vector(3 downto 0);
  signal monitor_data2_b        : std_logic_vector(3 downto 0);
  signal monitor_data3_b        : std_logic_vector(3 downto 0);
  signal monitor_last_b         : std_logic;
  signal monitor_count_b        : std_logic_vector(1 downto 0);

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

  prod_a: StreamTbProd
    generic map (
      DATA_WIDTH                => 4,
      SEED                      => 1
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      out_valid                 => valid_a,
      out_ready                 => ready_a,
      out_data                  => data_a
    );

  last_a_proc: process is
    variable seed1              : positive := 1;
    variable seed2              : positive := 1;
    variable rand               : real;
  begin
    loop
      for i in 1 to 100 loop
        wait until rising_edge(clk);
        if valid_a = '1' and ready_a = '1' then
          uniform(seed1, seed2, rand);
          if rand > 0.7 then
            last_a <= '1';
          else
            last_a <= '0';
          end if;
        end if;
      end loop;
      for i in 1 to 100 loop
        wait until rising_edge(clk);
        last_a <= '1';
      end loop;
    end loop;
  end process;

  uut: StreamParallelizer
    generic map (
      DATA_WIDTH                => 4,
      CTRL_WIDTH                => 1,
      FACTOR                    => 4,
      COUNT_WIDTH               => 2
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_valid                  => valid_a,
      in_ready                  => ready_a,
      in_data(4)                => last_a,
      in_data(3 downto 0)       => data_a,
      in_last                   => last_a,
      out_valid                 => valid_b,
      out_ready                 => ready_b,
      out_data                  => data_b(16 downto 0),
      out_count                 => data_b(18 downto 17)
    );

  cons_b: StreamTbCons
    generic map (
      DATA_WIDTH                => 19,
      SEED                      => 2
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_valid                  => valid_b,
      in_ready                  => ready_b,
      in_data                   => data_b,
      monitor(18 downto 17)     => monitor_count_b,
      monitor(16)               => monitor_last_b,
      monitor(15 downto 12)     => monitor_data3_b,
      monitor(11 downto 8)      => monitor_data2_b,
      monitor(7 downto 4)       => monitor_data1_b,
      monitor(3 downto 0)       => monitor_data0_b
    );

  check_b: process is
    variable data               : unsigned(3 downto 0);
  begin
    data := (others => '0');
    loop
      wait until rising_edge(clk);
      exit when reset = '1';
      next when monitor_last_b = 'Z';

      assert monitor_data0_b = std_logic_vector(data) report "Stream data integrity check failed" severity failure;
      data := data + 1;

      if monitor_count_b = "10" or monitor_count_b = "11" or monitor_count_b = "00" then
        assert monitor_data1_b = std_logic_vector(data) report "Stream data integrity check failed" severity failure;
        data := data + 1;
      end if;

      if monitor_count_b = "11" or monitor_count_b = "00" then
        assert monitor_data2_b = std_logic_vector(data) report "Stream data integrity check failed" severity failure;
        data := data + 1;
      end if;

      if monitor_count_b = "00" then
        assert monitor_data3_b = std_logic_vector(data) report "Stream data integrity check failed" severity failure;
        data := data + 1;
      end if;

    end loop;
  end process;

end Behavioral;

