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

entity StreamFIFO_tb is
end StreamFIFO_tb;

architecture Behavioral of StreamFIFO_tb is

  constant DATA_WIDTH           : natural := 4;

  signal in_clk                 : std_logic := '1';
  signal in_reset               : std_logic := '1';

  signal valid_a                : std_logic;
  signal ready_a                : std_logic;
  signal data_a                 : std_logic_vector(DATA_WIDTH-1 downto 0);

  signal out_clk                : std_logic := '1';
  signal out_reset              : std_logic := '1';

  signal valid_b                : std_logic;
  signal ready_b                : std_logic;
  signal data_b                 : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal monitor_b              : std_logic_vector(DATA_WIDTH-1 downto 0);

begin

  in_clk_proc: process is
  begin
    in_clk <= '1';
    wait for 5 ns;
    in_clk <= '0';
    wait for 5 ns;
  end process;

  out_clk_proc: process is
  begin
    out_clk <= '1';
    wait for 5 ns;
    out_clk <= '0';
    wait for 5 ns;
  end process;

  reset_proc: process is
  begin
    in_reset <= '1';
    out_reset <= '1';
    wait for 50 ns;
    wait until rising_edge(out_clk);
    out_reset <= '0';
    wait until rising_edge(in_clk);
    in_reset <= '0';
    wait for 10 us;
    wait until rising_edge(out_clk);
    out_reset <= '1';
    wait until rising_edge(in_clk);
    in_reset <= '1';
  end process;

  prod_a: StreamTbProd
    generic map (
      DATA_WIDTH                => 4,
      SEED                      => 1
    )
    port map (
      clk                       => in_clk,
      reset                     => in_reset,
      out_valid                 => valid_a,
      out_ready                 => ready_a,
      out_data                  => data_a
    );

  uut: StreamFIFO
    generic map (
      DATA_WIDTH                => DATA_WIDTH,
      DEPTH_LOG2                => 4,
      XCLK_STAGES               => 2
    )
    port map (
      in_clk                    => in_clk,
      in_reset                  => in_reset,
      in_valid                  => valid_a,
      in_ready                  => ready_a,
      in_data                   => data_a,
      out_clk                   => out_clk,
      out_reset                 => out_reset,
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
      clk                       => out_clk,
      reset                     => out_reset,
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
      wait until rising_edge(out_clk);
      exit when out_reset = '1';
      next when monitor_b(0) = 'Z';

      assert monitor_b = std_logic_vector(data) report "Stream data integrity check failed" severity failure;
      data := data + 1;

    end loop;
  end process;

end Behavioral;

