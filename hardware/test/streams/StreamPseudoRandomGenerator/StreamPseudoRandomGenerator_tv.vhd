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

entity StreamPseudoRandomGenerator_tv is
  generic (
    DATA_WIDTH                  : positive
  );
  port (
    clk                         : inout std_logic;
    reset                       : inout std_logic
  );
end StreamPseudoRandomGenerator_tv;

architecture TestVector of StreamPseudoRandomGenerator_tv is
begin

  clk_proc: process is
  begin
    stream_tb_gen_clock(clk, 10 ns);
    wait;
  end process;

  stimulus: process is
    variable seen       : bit_vector(2**DATA_WIDTH-1 downto 0);
    variable data       : std_logic_vector(DATA_WIDTH-1 downto 0);
    variable data_int   : natural;
    variable uniques    : natural;
    variable ok         : boolean;
  begin
    reset <= '1';
    wait for 50 ns;
    wait until rising_edge(clk);
    reset <= '0';

    seen := (others => '0');
    loop
      stream_tb_pop("out", data, 1 us);
      data_int := to_integer(unsigned(data));
      exit when seen(data_int) = '1';
      seen(data_int) := '1';
    end loop;

    uniques := 0;
    for i in seen'range loop
      if seen(i) = '1' then
        uniques := uniques + 1;
      end if;
    end loop;

    if uniques < 2**DATA_WIDTH-2 then
      stream_tb_fail("not all LFSR values seen.");
    else
      report "Saw " & integer'image(uniques) & " different values." severity note;
    end if;

    -- Assert reset and flush the output to prevent stream_to_complete from
    -- complaining about unconsumed data.
    reset <= '1';
    wait for 100 ns;
    loop
      stream_tb_pop("out", data, ok);
      exit when not ok;
    end loop;
    stream_tb_complete;
    wait;
  end process;

end TestVector;

