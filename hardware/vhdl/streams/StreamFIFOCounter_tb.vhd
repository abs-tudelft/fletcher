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

entity StreamFIFOCounter_tb is
end StreamFIFOCounter_tb;

architecture Behavioral of StreamFIFOCounter_tb is

  constant DEPTH_LOG2           : natural := 3;

  signal a_clk                  : std_logic := '1';
  signal a_reset                : std_logic := '1';
  signal a_increment            : std_logic;
  signal a_counter              : std_logic_vector(DEPTH_LOG2 downto 0);
  signal b_clk                  : std_logic := '1';
  signal b_reset                : std_logic := '1';
  signal b_counter              : std_logic_vector(DEPTH_LOG2 downto 0);

begin

  a_clk_proc: process is
  begin
    a_clk <= '1';
    wait for 5 ns;
    a_clk <= '0';
    wait for 5 ns;
  end process;

  a_reset_proc: process is
  begin
    a_reset <= '1';
    wait for 50 ns;
    wait until rising_edge(a_clk);
    a_reset <= '0';
    wait for 1 us;
    wait until rising_edge(a_clk);
  end process;

  a_increment_proc: process is
  begin
    a_increment <= '1';
    wait for 500 ns;
    wait until rising_edge(a_clk);
    a_increment <= '0';
    wait for 500 ns;
    wait until rising_edge(a_clk);
  end process;

  b_clk_proc: process is
  begin
    b_clk <= '1';
    wait for 4 ns;
    b_clk <= '0';
    wait for 4 ns;
  end process;

  b_reset_proc: process is
  begin
    b_reset <= '1';
    wait for 50 ns;
    wait until rising_edge(b_clk);
    b_reset <= '0';
    wait for 0.7 us;
    wait until rising_edge(b_clk);
  end process;

  uut: StreamFIFOCounter
    generic map (
      DEPTH_LOG2                => DEPTH_LOG2,
      XCLK_STAGES               => 2
    )
    port map (
      a_clk                     => a_clk,
      a_reset                   => a_reset,
      a_increment               => a_increment,
      a_counter                 => a_counter,
      b_clk                     => b_clk,
      b_reset                   => b_reset,
      b_counter                 => b_counter
    );

end Behavioral;

