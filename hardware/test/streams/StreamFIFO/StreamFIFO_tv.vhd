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

entity StreamFIFO_tv is
  generic (
    IN_CLK_PERIOD               : in  time;
    OUT_CLK_PERIOD              : in  time
  );
  port (
    in_clk                      : inout std_logic;
    in_reset                    : inout std_logic;
    out_clk                     : inout std_logic;
    out_reset                   : inout std_logic
  );
end StreamFIFO_tv;

architecture TestVector of StreamFIFO_tv is
begin

  in_clk_proc: process is
  begin
    stream_tb_gen_clock(in_clk, IN_CLK_PERIOD);
    wait;
  end process;

  out_clk_proc: process is
  begin
    stream_tb_gen_clock(out_clk, OUT_CLK_PERIOD);
    wait;
  end process;

  stimulus: process is
  begin
    in_reset <= '1';
    out_reset <= '1';
    wait for 50 ns;
    wait until rising_edge(out_clk);
    out_reset <= '0';
    wait until rising_edge(in_clk);
    in_reset <= '0';
    wait for 10 us;
    for i in 1 to 3 loop
      stream_tb_push_ascii("a", "The quick brown fox jumps over the lazy dog.");
      stream_tb_expect_ascii("b", "The quick brown fox jumps over the lazy dog.", 2 us);
      wait for 2 us;
      stream_tb_push_ascii("a", "Crazy Fredrick bought many very exquisite opal jewels.", 0);
      stream_tb_expect_ascii("b", "Crazy Fredrick bought many very exquisite opal jewels.", 2 us);
      wait for 2 us;
      stream_tb_push_ascii("a", "Quick zephyrs blow, vexing daft Jim.", 20);
      stream_tb_expect_ascii("b", "Quick zephyrs blow, vexing daft Jim.", 2 us);
      wait for 2 us;
    end loop;
    stream_tb_complete;
    wait;
  end process;

end TestVector;

