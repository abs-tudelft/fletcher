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
use ieee.math_real.all;

library work;
use work.StreamSim.all;

entity StreamGearbox_tv is
  generic (
    COUNT_MAX_B                 : natural;
    COUNT_WIDTH_B               : natural;
    COUNT_MAX_C                 : natural;
    COUNT_WIDTH_C               : natural
  );
  port (
    clk                         : inout std_logic;
    reset                       : inout std_logic
  );
end StreamGearbox_tv;

architecture TestVector of StreamGearbox_tv is
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
    for i in 1 to 3 loop
      if COUNT_MAX_B < 2**COUNT_WIDTH_B and COUNT_MAX_C < 2**COUNT_WIDTH_C then
        -- Zero-length packets are supported.
        stream_tb_push_ascii("a", "The quick brown fox jumps over the lazy dog." & c128);
        stream_tb_expect_ascii("d", "The quick brown fox jumps over the lazy dog." & c128, 2 us);
        wait for 2 us;
        stream_tb_push_ascii("a", "Crazy Fredrick bought many very exquisite opal jewels." & c128, 0);
        stream_tb_expect_ascii("d", "Crazy Fredrick bought many very exquisite opal jewels." & c128, 2 us);
        wait for 2 us;
        stream_tb_push_ascii("a", "Quick zephyrs blow, vexing daft Jim." & c128, 20);
        stream_tb_expect_ascii("d", "Quick zephyrs blow, vexing daft Jim." & c128, 2 us);
        wait for 2 us;
      else
        -- Zero-length packets are not supported.
        stream_tb_push_ascii("a", "The quick brown fox jumps over the lazy dog.");
        stream_tb_expect_ascii("d", "The quick brown fox jumps over the lazy dog.", 2 us);
        wait for 2 us;
        stream_tb_push_ascii("a", "Crazy Fredrick bought many very exquisite opal jewels.", 0);
        stream_tb_expect_ascii("d", "Crazy Fredrick bought many very exquisite opal jewels.", 2 us);
        wait for 2 us;
        stream_tb_push_ascii("a", "Quick zephyrs blow, vexing daft Jim.", 20);
        stream_tb_expect_ascii("d", "Quick zephyrs blow, vexing daft Jim.", 2 us);
        wait for 2 us;
      end if;
    end loop;
    stream_tb_complete;
    wait;
  end process;

end TestVector;

