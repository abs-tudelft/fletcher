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
use work.Utils.all;

entity StreamElementCounter_tv is
  generic (
    IN_COUNT_WIDTH              : positive;
    IN_COUNT_MAX                : positive;
    OUT_COUNT_WIDTH             : positive;
    OUT_COUNT_MAX               : positive;
    OUT_COUNT_MAX_CLAMP         : natural
  );
  port (
    clk                         : inout std_logic;
    reset                       : inout std_logic
  );
end StreamElementCounter_tv;

architecture TestVector of StreamElementCounter_tv is
begin

  clk_proc: process is
  begin
    stream_tb_gen_clock(clk, 10 ns);
    wait;
  end process;

  stimulus: process is

    variable seed1              : positive := 42;
    variable seed2              : positive := 42;

    procedure send(count: natural; last: std_logic) is
      variable count_v          : natural;
      variable data             : std_logic_vector(IN_COUNT_WIDTH + 1 downto 0);
      variable rand             : real;
    begin
      count_v := count;
      if count_v = 0 then
        -- Mark 0 with dvalid low.
        uniform(seed1, seed2, rand);
        count_v := integer(floor(rand * real(IN_COUNT_MAX)));
        data(IN_COUNT_WIDTH) := '0';
      else
        data(IN_COUNT_WIDTH) := '1';
      end if;
      data(IN_COUNT_WIDTH - 1 downto 0) := std_logic_vector(to_unsigned(count_v, IN_COUNT_WIDTH));
      data(IN_COUNT_WIDTH + 1) := last;
      stream_tb_push("a", data);
    end procedure;

    procedure randomly_count_to(target: natural; last_count: natural) is
      variable last_count_v     : natural;
      variable remaining        : natural;
      variable count            : natural;
      variable data             : std_logic_vector(IN_COUNT_WIDTH + 1 downto 0);
      variable rand             : real;
    begin
      last_count_v := last_count;
      if last_count_v > IN_COUNT_MAX then
        last_count_v := IN_COUNT_MAX;
      end if;
      remaining := target - last_count_v;
      while remaining > 0 loop
        uniform(seed1, seed2, rand);
        count := integer(floor(rand * real(IN_COUNT_MAX + 1)));
        if count > remaining then
          count := remaining;
        end if;
        send(count, '0');
        remaining := remaining - count;
      end loop;
      send(last_count_v, '1');
    end procedure;

    procedure expect_count(target: natural) is
      variable remaining        : natural;
      variable count            : natural;
      variable data             : std_logic_vector(OUT_COUNT_WIDTH downto 0);
    begin
      remaining := target;
      loop
        count := remaining;
        if count > OUT_COUNT_MAX_CLAMP then
          count := OUT_COUNT_MAX_CLAMP;
          data(OUT_COUNT_WIDTH) := '0';
        else
          data(OUT_COUNT_WIDTH) := '1';
        end if;
        data(OUT_COUNT_WIDTH - 1 downto 0) := std_logic_vector(to_unsigned(count, OUT_COUNT_WIDTH));
        stream_tb_expect("b", data, 100 us);
        remaining := remaining - count;
        exit when remaining = 0;
      end loop;
    end procedure;

  begin
    reset <= '1';
    wait for 50 ns;
    wait until rising_edge(clk);
    reset <= '0';
    wait for 10 us;
    for i in 1 to 3 loop
      randomly_count_to(OUT_COUNT_MAX_CLAMP / 2, IN_COUNT_MAX / 2 + 1);
      randomly_count_to(OUT_COUNT_MAX_CLAMP * 2 + IN_COUNT_MAX / 3, IN_COUNT_MAX / 2 + 1);
      randomly_count_to(0, 0);
      expect_count(OUT_COUNT_MAX_CLAMP / 2);
      expect_count(OUT_COUNT_MAX_CLAMP * 2 + IN_COUNT_MAX / 3);
      expect_count(0);
      wait for 1 us;
    end loop;
    stream_tb_complete;
    wait;
  end process;

end TestVector;

