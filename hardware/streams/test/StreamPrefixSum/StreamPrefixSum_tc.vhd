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
use work.StreamSim.all;

--pragma simulation timeout 1 ms

entity StreamPrefixSum_tc is
end StreamPrefixSum_tc;

architecture TestCase of StreamPrefixSum_tc is
  signal clk : std_logic;
  signal reset : std_logic;
begin

  tb: entity work.StreamPrefixSum_tb
    generic map (
      DATA_WIDTH => 8,
      COUNT_MAX  => 4
    )
    port map (
      clk => clk,
      reset => reset
    );
    
  clk_proc: process is
  begin
    stream_tb_gen_clock(clk, 10 ns);
    wait;
  end process;

  stimulus: process is
  begin
    reset <= '1';
    wait for 50 ns;
    wait until rising_edge(clk);
    reset <= '0';
    wait for 10 us;
    
    stream_tb_push("a", X"00000201");
    stream_tb_push("a", X"00000403");
    stream_tb_push("a", X"00000605");
    stream_tb_push("a", X"00000807");
    stream_tb_push("a", X"00000A09");
    stream_tb_push("a", X"00000C0B");
    
    stream_tb_expect("b", X"0A060301", 10 us);
    stream_tb_expect("b", X"241C150F", 10 us);
    stream_tb_expect("b", X"4E42372D", 10 us);
   
    stream_tb_complete;
    wait;
  end process;
end TestCase;

