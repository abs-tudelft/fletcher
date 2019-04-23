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
use work.Utils.all;

--pragma simulation timeout 1 ms

entity StreamArb_FuncRoundRobin_tc is
end StreamArb_FuncRoundRobin_tc;

architecture TestCase of StreamArb_FuncRoundRobin_tc is
  signal clk      : std_logic := '1';
  signal reset    : std_logic;
begin

  clk_proc: process is
  begin
    stream_tb_gen_clock(clk, 10 ns);
    wait;
  end process;

  stimulus: process is
    variable ok                 : boolean;
    variable ctrl_prev          : std_logic_vector(2 downto 0);
    variable ctrl_cur           : std_logic_vector(2 downto 0);
    variable interrupts_a       : natural;
    variable interrupts_b       : natural;
    variable interrupts_c       : natural;
  begin
    reset <= '1';
    wait for 50 ns;
    wait until rising_edge(clk);
    reset <= '0';
    wait for 10 us;
    for i in 1 to 3 loop

      -- Send some data on each input stream. Each iteration, one of the
      -- streams is slow and the other two are fast.
      stream_tb_push_ascii("a", "The quick brown fox jumps over the lazy dog.", sel(i = 1, 20, 0));
      stream_tb_push_ascii("b", "Crazy Fredrick bought many very exquisite opal jewels.", sel(i = 2, 20, 0));
      stream_tb_push_ascii("c", "Quick zephyrs blow, vexing daft Jim.", sel(i = 3, 20, 0));

      -- Check the data passing through the arbiter after being split again by
      -- index.
      stream_tb_expect_ascii("e", "The quick brown fox jumps over the lazy dog.", 10 us);
      stream_tb_expect_ascii("f", "Crazy Fredrick bought many very exquisite opal jewels.", 10 us);
      stream_tb_expect_ascii("g", "Quick zephyrs blow, vexing daft Jim.", 10 us);

      wait for 2 us;

      -- Check the arbitration method. The index should stay fixed if last is
      -- low, each stream should be interrupted at least twice if round-robin
      -- works, and index 3 should never be seen.
      interrupts_a := 0;
      interrupts_b := 0;
      interrupts_c := 0;
      stream_tb_pop("d", ctrl_prev, ok);
      while ok loop
        if is_X(ctrl_prev) then
          stream_tb_fail("last or index is X");
        end if;
        if to_X01(ctrl_prev(1 downto 0)) = "11" then
          stream_tb_fail("stream index out of range");
        end if;
        stream_tb_pop("d", ctrl_cur, ok);
        exit when not ok;
        if to_X01(ctrl_prev(2)) = '1' then
          if to_X01(ctrl_cur(1 downto 0)) /= to_X01(ctrl_prev(1 downto 0)) then
            case to_X01(ctrl_prev(1 downto 0)) is
              when "00" => interrupts_a := interrupts_a + 1;
              when "01" => interrupts_b := interrupts_b + 1;
              when "10" => interrupts_c := interrupts_c + 1;
              when others => null;
            end case;
          end if;
        else
          if to_X01(ctrl_cur(1 downto 0)) /= to_X01(ctrl_prev(1 downto 0)) then
            stream_tb_fail("stream index changed mid-transfer");
          end if;
        end if;
        ctrl_prev := ctrl_cur;
      end loop;
      if interrupts_a < 2 then
        stream_tb_fail("stream a was not interrupted twice");
      end if;
      if interrupts_b < 2 then
        stream_tb_fail("stream b was not interrupted twice");
      end if;
      if interrupts_c < 2 then
        stream_tb_fail("stream c was not interrupted twice");
      end if;

    end loop;
    stream_tb_complete;
    wait;
  end process;

  tb: entity work.StreamArb_Func_tb
    generic map (
      ARB_METHOD  => "ROUND-ROBIN"
    )
    port map (
      clk         => clk,
      reset       => reset
    );

end TestCase;

