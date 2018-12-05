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

--pragma simulation timeout 1 ms

entity StreamReshaper_Example_tc is
end StreamReshaper_Example_tc;

architecture TestCase of StreamReshaper_Example_tc is

  constant IN_COUNT_MAX         : natural := 4;
  constant OUT_COUNT_MAX        : natural := 5;
  constant SHIFTS_PER_STAGE     : natural := 3;

  signal clk                    : std_logic;
  signal reset                  : std_logic;
  signal error_strobe           : std_logic;
  signal error_strobe_count     : natural := 0;

begin

  clk_proc: process is
  begin
    stream_tb_gen_clock(clk, 10 ns);
  end process;

  stimulus: process is
  begin
    reset <= '1';
    wait for 50 ns;
    wait until rising_edge(clk);
    reset <= '0';
    wait for 50 us;
    wait until rising_edge(clk);

    -- This test case mimics the example in the comments describing the
    -- StreamReshaper.

    stream_tb_push("din", "0" & "1" & X"03_02_01_00" & X"04");
    stream_tb_push("din", "0" & "1" & X"FF_FF_05_04" & X"02");
    stream_tb_push("din", "0" & "1" & X"FF_08_07_06" & X"03");
    stream_tb_push("din", "0" & "0" & X"FF_FF_FF_FF" & X"FF");
    stream_tb_push("din", "0" & "1" & X"FF_0B_0A_09" & X"03");
    stream_tb_push("din", "1" & "0" & X"FF_FF_FF_FF" & X"FF");

    stream_tb_push("cin", "0" & "1" & X"80" & X"05");
    stream_tb_push("cin", "0" & "1" & X"81" & X"05");
    stream_tb_push("cin", "1" & "1" & X"82" & X"02");

    stream_tb_expect("out", "0" & "1" & X"04_03_02_01_00" & X"80" & X"05",
                            "1" & "1" & X"FF_FF_FF_FF_FF" & X"FF" & X"FF", 10 us);

    stream_tb_expect("out", "0" & "1" & X"09_08_07_06_05" & X"81" & X"05",
                            "1" & "1" & X"FF_FF_FF_FF_FF" & X"FF" & X"FF", 10 us);

    stream_tb_expect("out", "1" & "1" & X"00_00_00_0B_0A" & X"82" & X"02",
                            "1" & "1" & X"00_00_00_FF_FF" & X"FF" & X"FF", 10 us);

    wait for 10 us;

    stream_tb_complete;
  end process;

  counter: process (clk) is
  begin
    if rising_edge(clk) then
      if reset /= '1' and error_strobe /= '0' then
        error_strobe_count <= error_strobe_count + 1;
      end if;
    end if;
  end process;

  tb: entity work.StreamReshaper_tb
    generic map (
      IN_COUNT_MAX              => IN_COUNT_MAX,
      OUT_COUNT_MAX             => OUT_COUNT_MAX,
      SHIFTS_PER_STAGE          => SHIFTS_PER_STAGE
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      error_strobe              => error_strobe
    );

end TestCase;

