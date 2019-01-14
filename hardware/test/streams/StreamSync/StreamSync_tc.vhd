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

entity StreamSync_tc is
end StreamSync_tc;

architecture TestCase of StreamSync_tc is

  signal clk                    : std_logic;
  signal reset                  : std_logic;

begin

  clk_proc: process is
  begin
    stream_tb_gen_clock(clk, 10 ns);
    wait;
  end process;

  stimulus: process is
  begin
    for i in 1 to 5 loop
      reset <= '1';
      wait for 50 ns;
      wait until rising_edge(clk);
      reset <= '0';
      wait for 50 us;
      wait until rising_edge(clk);
    end loop;
    stream_tb_complete;
  end process;

  tb: entity work.StreamSync_tb
    port map (
      clk                       => clk,
      reset                     => reset
    );

end TestCase;

