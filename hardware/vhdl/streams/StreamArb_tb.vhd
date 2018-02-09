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

entity StreamArb_tb is
end StreamArb_tb;

architecture Behavioral of StreamArb_tb is

  signal clk                    : std_logic := '1';
  signal reset                  : std_logic;

  signal valid_a                : std_logic;
  signal ready_a                : std_logic;
  signal data_a                 : std_logic_vector(3 downto 0);
  signal last_a                 : std_logic;

  signal valid_b                : std_logic;
  signal ready_b                : std_logic;
  signal data_b                 : std_logic_vector(3 downto 0);
  signal last_b                 : std_logic;

  signal valid_c                : std_logic;
  signal ready_c                : std_logic;
  signal data_c                 : std_logic_vector(3 downto 0);
  signal last_c                 : std_logic;

  signal valid_d                : std_logic;
  signal ready_d                : std_logic;
  signal data_d                 : std_logic_vector(3 downto 0);
  signal last_d                 : std_logic;
  signal index_d                : std_logic_vector(1 downto 0);
  signal monitor_data_d         : std_logic_vector(3 downto 0);
  signal monitor_last_d         : std_logic;
  signal monitor_index_d        : std_logic_vector(1 downto 0);

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

  last_a <= data_a(1);

  prod_b: StreamTbProd
    generic map (
      DATA_WIDTH                => 4,
      SEED                      => 2
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      out_valid                 => valid_b,
      out_ready                 => ready_b,
      out_data                  => data_b
    );

  last_b <= data_b(2);

  prod_c: StreamTbProd
    generic map (
      DATA_WIDTH                => 4,
      SEED                      => 3
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      out_valid                 => valid_c,
      out_ready                 => ready_c,
      out_data                  => data_c
    );

  last_c <= data_c(3);

  uut: StreamArb
    generic map (
      NUM_INPUTS                => 3,
      INDEX_WIDTH               => 2,
      DATA_WIDTH                => 4,
      ARB_METHOD                => "ROUND-ROBIN"
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_valid(2)               => valid_a,
      in_valid(1)               => valid_b,
      in_valid(0)               => valid_c,
      in_ready(2)               => ready_a,
      in_ready(1)               => ready_b,
      in_ready(0)               => ready_c,
      in_data(11 downto 8)      => data_a,
      in_data(7 downto 4)       => data_b,
      in_data(3 downto 0)       => data_c,
      in_last(2)                => last_a,
      in_last(1)                => last_b,
      in_last(0)                => last_c,
      out_valid                 => valid_d,
      out_ready                 => ready_d,
      out_data                  => data_d,
      out_last                  => last_d,
      out_index                 => index_d
    );

  cons_d: StreamTbCons
    generic map (
      DATA_WIDTH                => 7,
      SEED                      => 4
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_valid                  => valid_d,
      in_ready                  => ready_d,
      in_data(6)                => last_d,
      in_data(5 downto 4)       => index_d,
      in_data(3 downto 0)       => data_d,
      monitor(6)                => monitor_last_d,
      monitor(5 downto 4)       => monitor_index_d,
      monitor(3 downto 0)       => monitor_data_d
    );

end Behavioral;

