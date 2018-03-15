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

entity StreamBarrelShifter_tb is
end StreamBarrelShifter_tb;

architecture Behavioral of StreamBarrelShifter_tb is
  signal clk                    : std_logic := '1';
  signal reset                  : std_logic := '1';

  signal in_ready               : std_logic;
  signal in_valid               : std_logic := '0';
  signal in_data                : std_logic_vector(31 downto 0);
  signal in_shamt               : std_logic_vector(1 downto 0);
  
  signal out_ready              : std_logic := '0';
  signal out_valid              : std_logic;
  signal out_data               : std_logic_vector(31 downto 0);
  
  signal test_done              : std_logic := '0';
begin

  uut: StreamBarrelShifter
    generic map (
      CTRL_WIDTH                => 0,
      ELEMENT_WIDTH             => 8,
      ELEMENT_COUNT             => 4,
      SHAMT_WIDTH               => 2,
      SHIFT_DIRECTION           => "left"
    )
    port map (
      clk                       => clk,
      reset                     => reset,

      in_valid                  => in_valid,
      in_ready                  => in_ready,
      in_data                   => in_data,
      in_shamt                  => in_shamt,

      out_valid                 => out_valid,
      out_ready                 => out_ready,
      out_data                  => out_data
    );
    
  clk_proc: process is
  begin
    if test_done /= '1' then
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
  
  stimuli_proc: process is
  begin
    out_ready                   <= '1';

    in_data                     <= X"00112233";
    in_shamt                    <= "00";
    in_valid                    <= '1';
    wait until rising_edge(clk) and (in_ready = '1');
    in_data                     <= X"44556677";
    in_shamt                    <= "01";
    in_valid                    <= '1';
    out_ready                   <= '0';
    wait for 20 ns;
    out_ready                   <= '1';
    wait until rising_edge(clk) and (in_ready = '1');
    in_data                     <= X"8899AABB";
    in_shamt                    <= "10";
    in_valid                    <= '1';
    wait until rising_edge(clk) and (in_ready = '1');
    in_data                     <= X"CCDDEEFF";
    in_shamt                    <= "11";
    in_valid                    <= '1';
    wait until rising_edge(clk) and (in_ready = '1');
    in_valid                    <= '0';
    wait;    
  end process;
  
  check_proc: process is
  begin
    wait until rising_edge(clk) and (out_valid = '1') and (out_ready = '1');
    assert out_data = X"00112233" report "Expected 00112233 ERROR" severity failure;
    wait until rising_edge(clk) and (out_valid = '1') and (out_ready = '1');
    assert out_data = X"55667744" report "Expected 55667744 ERROR" severity failure;
    wait until rising_edge(clk) and (out_valid = '1') and (out_ready = '1');
    assert out_data = X"AABB8899" report "Expected AABB8899 ERROR" severity failure;
    wait until rising_edge(clk) and (out_valid = '1') and (out_ready = '1');
    assert out_data = X"FFCCDDEE" report "Expected FFCCDDEE ERROR" severity failure;
    test_done <= '1';
    wait;
  end process;

end Behavioral;

