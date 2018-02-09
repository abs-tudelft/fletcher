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

entity StreamSlice_tb is
end StreamSlice_tb;

architecture Behavioral of StreamSlice_tb is

  constant DATA_WIDTH           : natural := 4;

  signal clk                    : std_logic := '1';
  signal reset                  : std_logic;

  signal valid_a                : std_logic;
  signal ready_a                : std_logic;
  signal data_a                 : std_logic_vector(DATA_WIDTH-1 downto 0);

  signal valid_b                : std_logic;
  signal ready_b                : std_logic;
  signal data_b                 : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal monitor_b              : std_logic_vector(DATA_WIDTH-1 downto 0);

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

  uut: StreamSlice
    generic map (
      DATA_WIDTH                => DATA_WIDTH
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_valid                  => valid_a,
      in_ready                  => ready_a,
      in_data                   => data_a,
      out_valid                 => valid_b,
      out_ready                 => ready_b,
      out_data                  => data_b
    );

  cons_b: StreamTbCons
    generic map (
      DATA_WIDTH                => DATA_WIDTH,
      SEED                      => 2
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_valid                  => valid_b,
      in_ready                  => ready_b,
      in_data                   => data_b,
      monitor                   => monitor_b
    );

  check_b: process is
    variable data               : unsigned(DATA_WIDTH-1 downto 0);
  begin
    data := (others => '0');
    loop
      wait until rising_edge(clk);
      exit when reset = '1';
      next when monitor_b(0) = 'Z';

      assert monitor_b = std_logic_vector(data) report "Stream data integrity check failed" severity failure;
      data := data + 1;

    end loop;
  end process;

end Behavioral;

