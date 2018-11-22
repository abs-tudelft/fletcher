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
use work.SimUtils.all;

entity StreamPseudoRandomGenerator_tb is
end StreamPseudoRandomGenerator_tb;

architecture Behavioral of StreamPseudoRandomGenerator_tb is
  constant DATA_WIDTH           : natural := 8;
  signal clk                    : std_logic;
  signal reset                  : std_logic;
  signal seed                   : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
  signal out_valid              : std_logic;
  signal out_ready              : std_logic;
  signal out_data               : std_logic_vector(DATA_WIDTH-1 downto 0);
begin
  -- Clock
  clk_proc: process is
  begin
    clk                   <= '1';
    wait for 2 ns;
    clk                   <= '0';
    wait for 2 ns;
  end process;

  -- Reset
  reset_proc: process is
  begin
    reset                   <= '1';
    wait for 8 ns;
    wait until rising_edge(clk);
    reset                   <= '0';
    wait;
  end process;
  
  out_ready <= '1';
  
  uut : StreamPseudoRandomGenerator
    generic map (
      DATA_WIDTH => DATA_WIDTH
    )
    port map (
      clk       => clk       ,
      reset     => reset     ,
      seed      => seed      ,
      out_valid => out_valid ,
      out_ready => out_ready ,
      out_data  => out_data  
    );
    
  print_proc: process 
  begin
  
    loop
      wait until rising_edge(clk);
      exit when out_valid = '1' and out_ready = '1';
    end loop;
    
    dumpStdOut(ii(unsigned(out_data)));
    
  end process;
  
  
end Behavioral;

