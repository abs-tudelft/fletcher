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

entity StreamAccumulator_tc is
end StreamAccumulator_tc;

architecture TestCase of StreamAccumulator_tc is

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
    reset <= '1';
    wait for 50 ns;
    wait until rising_edge(clk);
    reset <= '0';
    wait for 10 us;

    stream_tb_push("a", X"3e");
    stream_tb_push("a", X"1f");
    stream_tb_push("a", X"54"); -- skip
    stream_tb_push("a", X"03");
    stream_tb_push("a", X"2a");
    stream_tb_push("a", X"9b"); -- clear
    stream_tb_push("a", X"1f");
    stream_tb_push("a", X"33");
    stream_tb_push("a", X"cf"); -- skip + clear
    stream_tb_push("a", X"22");
    stream_tb_push("a", X"11");

    stream_tb_expect("b", X"3e", 10 us);
    stream_tb_expect("b", X"1d", 10 us);
    stream_tb_expect("b", X"5d", 10 us); -- skip
    stream_tb_expect("b", X"20", 10 us);
    stream_tb_expect("b", X"0a", 10 us);
    stream_tb_expect("b", X"9b", 10 us); -- clear
    stream_tb_expect("b", X"3a", 10 us);
    stream_tb_expect("b", X"2d", 10 us);
    stream_tb_expect("b", X"c0", 10 us); -- skip + clear
    stream_tb_expect("b", X"22", 10 us);
    stream_tb_expect("b", X"33", 10 us);

    stream_tb_complete;
    wait;
  end process;

  tb: entity work.StreamAccumulator_tb
    port map (
      clk                       => clk,
      reset                     => reset
    );

end TestCase;

